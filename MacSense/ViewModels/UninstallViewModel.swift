import SwiftUI
import Combine

/// Owns everything scoped to a single app-uninstall interaction: the
/// discovered file set, the user's selection, per-URL sizes, and the
/// removal itself.
///
/// Split out of `AppState` so the uninstall flow can grow (path
/// validation, match reasons, safety scoring) without pushing the root
/// observable further past the file-size cap. `AppState` still owns the
/// installed-app *list*; this view model reaches back through `owner`
/// only to reflect a completed removal into that list.
@MainActor
final class UninstallViewModel: ObservableObject {

    /// Set once by `AppState` at construction. Weak so the two objects
    /// don't retain each other.
    weak var owner: AppState?

    @Published var discoveredFiles: [URL] = []
    @Published var selectedFiles: Set<URL> = []
    @Published var isScanningAppFiles: Bool = false
    @Published var removalError: String? = nil
    /// Set when an app's full removal completes successfully — drives the
    /// success-checkmark overlay in `ExpandedAppCard`. Carries the
    /// removed app's `id` so the overlay knows which card to celebrate
    /// over before auto-closing.
    @Published var deletionSucceededFor: InstalledApp.ID? = nil
    /// Transient banner message shown inside the expanded app card when
    /// the user deletes only some of the app's files (not the .app
    /// itself). Auto-clears after a short delay.
    @Published var fileDeletionNotice: String? = nil
    /// Per-URL allocated size, populated in the background after the
    /// uninstall sheet opens. Reading this map is O(1); recomputing
    /// `recursiveAllocatedSize` on every render froze the modal because
    /// SwiftUI re-evaluated the selected-size sum hundreds of times
    /// during interaction.
    @Published var appFileSizes: [URL: Int64] = [:]
    /// Why each discovered file was attributed to this app — rendered under
    /// every row so the user can judge a path instead of trusting it.
    @Published var matchReasons: [URL: MatchReason] = [:]
    /// Files the scanner matched and then refused — finder vetoes plus
    /// anything the path validator rejected at plan time. Shown in a
    /// disclosure under the list so an absence has a visible reason.
    @Published var excludedItems: [ExcludedItem] = []
    /// Pre-delete verdict over the current selection. Recomputed whenever the
    /// discovered set changes.
    @Published var safety: SafetyAssessment?
    /// Non-nil while the confirmation step is on screen.
    @Published var pendingConfirmation: SafetyAssessment?
    /// True while the preflight is quitting processes and tearing down launchd
    /// jobs, before the first file is touched.
    @Published var isPreparingRemoval: Bool = false
    /// Trash (default) or permanent. Persisted across launches; permanent
    /// always routes through the confirmation step.
    @Published var deletionMode: DeletionMode = .stored {
        didSet { DeletionMode.store(deletionMode) }
    }

    /// Generation token for the auto-dismiss timer of
    /// `fileDeletionNotice`. Stops a stale dismiss from clearing a newer
    /// notice when partial deletes happen back-to-back.
    private var fileDeletionToken: UUID?

    /// Drops the per-interaction state when the user navigates away from
    /// the Applications section. Called by `AppState`.
    func releaseMemory() {
        discoveredFiles = []
        selectedFiles = []
        appFileSizes = [:]
        matchReasons = [:]
        excludedItems = []
        safety = nil
    }

    /// Clears the modal state before a new card expands.
    func reset() {
        discoveredFiles = []
        selectedFiles = []
        excludedItems = []
        safety = nil
        pendingConfirmation = nil
        deletionSucceededFor = nil
    }

    // MARK: - Discovery

    /// Opens the uninstall sheet for an app. Reuses the URL set captured
    /// during discovery so the modal total always equals the list total.
    /// Re-running the heuristic finder mid-session can return a slightly
    /// different set (race-y aggregation across location threads), which
    /// made list and modal disagree — e.g. SketchUp 5.9 GB list vs 3.44 GB
    /// modal. Per-URL sizes are populated in the background — the sheet
    /// appears instantly and stays interactive (close button, scrolling)
    /// while sizes stream in.
    func scanForAppFiles(_ app: InstalledApp) {
        guard owner?.ensureFullDiskAccess() ?? false else { return }
        discoveredFiles = []
        selectedFiles = []
        appFileSizes = [:]
        matchReasons = [:]
        excludedItems = []
        safety = nil
        pendingConfirmation = nil

        // Cached fast-path: per-URL sizes were captured during streaming
        // discovery. Sum-of-rows == relatedSize == modal header. No disk
        // walk on the main thread, no recompute.
        if let cached = app.discoveredURLs, !cached.isEmpty {
            isScanningAppFiles = false
            self.appFileSizes = app.fileSizes ?? [:]
            self.matchReasons = app.matchReasons ?? [:]
            self.present(FinderResult(matches: app.matchReasons ?? [:],
                                      excluded: app.excludedItems ?? []),
                         order: cached)
            return
        }

        // Fall-back: discovery hasn't finished sizing this app yet, or
        // the user opened the modal before streaming completed for this
        // row. Run the heuristic finder + sizer on a background task.
        isScanningAppFiles = true
        Task.detached(priority: .userInitiated) { [weak self] in
            let finder = Self.makeFinder(for: app)
            let found = await withCheckedContinuation { (cont: CheckedContinuation<FinderResult, Never>) in
                finder.findPathsAsync { result in cont.resume(returning: result) }
            }
            let sorted = found.matches.keys.sorted { $0.path < $1.path }
            var perURL: [URL: Int64] = [:]
            perURL.reserveCapacity(found.matches.count)
            var related: Int64 = 0
            for url in found.matches.keys {
                if url == app.path {
                    perURL[url] = app.bundleSize
                    continue
                }
                let s = url.recursiveAllocatedSize()
                perURL[url] = s
                related += s
            }
            let finalPerURL = perURL
            let finalRelated = related
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isScanningAppFiles = false
                self.appFileSizes = finalPerURL
                self.matchReasons = found.matches
                self.present(found, order: sorted)
                self.owner?.applySizingResult(appID: app.id, related: finalRelated, urls: sorted,
                                              fileSizes: finalPerURL, found: found)
            }
        }
    }

    nonisolated static func makeFinder(for app: InstalledApp) -> AppPathFinder {
        let locations = Locations()
        let appInfo = AppPathFinder.AppInfo(
            appName: app.appName,
            bundleIdentifier: app.bundleIdentifier,
            path: app.path,
            entitlements: nil,
            teamIdentifier: nil
        )
        return AppPathFinder(appInfo: appInfo, locations: locations)
    }

    nonisolated static func findRelatedURLs(for app: InstalledApp) async -> FinderResult {
        let finder = makeFinder(for: app)
        return await withCheckedContinuation { continuation in
            finder.findPathsAsync { found in
                continuation.resume(returning: found)
            }
        }
    }

    /// Splits a finder result into what can actually be deleted and what
    /// cannot, then scores it.
    ///
    /// Validation runs here rather than only at delete time so the list never
    /// offers, pre-selected, an item the validator will refuse seconds later.
    /// A path that fails validation moves into the excluded section with its
    /// reason attached.
    private func present(_ found: FinderResult, order: [URL]) {
        var deletable: [URL] = []
        var refused = found.excluded

        for url in order {
            switch UninstallPathValidator.validate(url) {
            case .success:
                deletable.append(url)
            case .failure(let rejection):
                refused.append(ExcludedItem(url: url, rule: .validator(rejection.reason)))
            }
        }

        discoveredFiles = deletable
        selectedFiles = Set(deletable)
        excludedItems = refused
        safety = SafetyAssessment(urls: deletable, reasons: found.matches, excluded: refused,
                                  appIsRunning: appIsRunning)
    }

    /// Whether the app being uninstalled is live right now. Read fresh each
    /// time — the user may quit it while the card is open.
    private var appIsRunning: Bool {
        guard let app = owner?.selectedApp else { return false }
        return UninstallPreflight.isRunning(app)
    }

    /// Re-scores after the user changes the selection, so the verdict always
    /// describes what the button is about to do.
    func refreshSafety() {
        let selected = discoveredFiles.filter { selectedFiles.contains($0) }
        safety = SafetyAssessment(urls: selected, reasons: matchReasons, excluded: excludedItems,
                                  appIsRunning: appIsRunning)
    }

    // MARK: - Removal

    /// Entry point from the delete button. Anything the safety assessment
    /// flags gets a confirmation step; a clean verdict deletes straight away.
    func requestRemoval() {
        refreshSafety()
        guard let safety else { return }
        guard safety.requiresConfirmation || deletionMode.alwaysRequiresConfirmation else {
            removeSelectedFiles()
            return
        }
        pendingConfirmation = safety
    }

    /// Opens the path-level uninstall log in Finder. The log is the record of
    /// what actually left the machine; it is no use if nobody can find it.
    func revealLog() {
        guard let url = UninstallLog.shared.fileURL else { return }
        if !FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func cancelConfirmation() {
        pendingConfirmation = nil
    }

    func confirmRemoval() {
        pendingConfirmation = nil
        removeSelectedFiles()
    }

    private func removeSelectedFiles() {
        guard let app = owner?.selectedApp else { return }
        isPreparingRemoval = true
        Task { [weak self] in
            let outcome = await UninstallPreflight.run(for: app, plannedPaths: Array(self?.selectedFiles ?? []))
            guard let self else { return }
            self.isPreparingRemoval = false
            guard !outcome.isBlocked else {
                // Deleting under a live process would leave it writing into
                // paths that no longer exist — refuse rather than half-do it.
                self.removalError = Localization.shared.t(.removalAppStillRunningFormat,
                                                          outcome.stillRunning.joined(separator: ", "))
                return
            }
            self.preflightOutcome = outcome
            self.deleteValidatedSelection()
        }
    }

    /// Result of the last preflight, kept for the removal that follows it.
    private var preflightOutcome: UninstallPreflight.Outcome?
    /// Paths the validator refused when the user clicked delete, held for the
    /// log entry written once the removal finishes.
    private var planTimeSkips: [UninstallLogEntry.PathOutcome] = []

    private func deleteValidatedSelection() {
        var validated: [UninstallRemover.ValidatedRemoval] = []
        var refused: [URL] = []
        var alreadyGone: [URL] = []

        for url in selectedFiles {
            switch UninstallPathValidator.validate(url) {
            case .success(let canonical):
                validated.append(UninstallRemover.ValidatedRemoval(original: url, canonical: canonical))
            case .failure(let rejection):
                // A path that vanished between scan and click isn't a refusal —
                // it's already in the state the user asked for.
                if rejection.reason == .missing {
                    alreadyGone.append(url)
                } else {
                    refused.append(url)
                    Logger.shared.log("Refused \(url.path): \(rejection.reason.debugLabel)", level: .warning)
                }
            }
        }

        removalError = nil
        if !refused.isEmpty || !alreadyGone.isEmpty {
            let dropped = Set(refused + alreadyGone)
            selectedFiles.subtract(dropped)
            discoveredFiles.removeAll { alreadyGone.contains($0) }
        }
        planTimeSkips = refused.map {
            UninstallLogEntry.PathOutcome(path: $0.path, reason: "refused by path validator")
        }
        guard !validated.isEmpty else {
            if !refused.isEmpty {
                removalError = Localization.shared.t(.removalRefusedFormat, refused.count)
            }
            return
        }
        let request = UninstallRemover.Request(
            items: validated,
            mode: deletionMode,
            sizes: appFileSizes,
            context: UninstallRemover.LogContext(
                app: owner?.selectedApp,
                mode: deletionMode,
                safetyLevel: safety.map(Self.levelLabel) ?? "unknown",
                excludedCount: excludedItems.count,
                preflight: preflightOutcome,
                planTimeSkips: planTimeSkips
            )
        )
        Task { [weak self] in
            let outcome = await UninstallRemover.perform(request)
            self?.applyRemovalOutcome(removed: outcome.removed,
                                      permFails: outcome.permissionFailures,
                                      otherFails: outcome.otherFailures)
        }
    }

    private static func levelLabel(_ safety: SafetyAssessment) -> String {
        switch safety.level {
        case .safe:     return "safe"
        case .review:   return "review"
        case .highRisk: return "high-risk"
        }
    }

    private func applyRemovalOutcome(removed: [URL], permFails: [URL], otherFails: [(URL, Error)]) {
        if !removed.isEmpty {
            discoveredFiles.removeAll { removed.contains($0) }
            selectedFiles.subtract(removed)
            refreshSafety()
        }
        if !permFails.isEmpty {
            removalError = Localization.shared.t(.removalAuthCancelledFormat, permFails.count)
        } else if !otherFails.isEmpty {
            let detail = otherFails.prefix(3)
                .map { "\($0.0.lastPathComponent): \($0.1.localizedDescription)" }
                .joined(separator: "; ")
            removalError = Localization.shared.t(.removalNotRemovedFormat, otherFails.count, detail)
        }

        guard let owner, let selected = owner.selectedApp else { return }

        if !FileManager.default.fileExists(atPath: selected.path.path) {
            // Full uninstall: the .app bundle is in Trash. Signal success
            // to the expanded card BEFORE clearing the selected app — the
            // overlay observes this id, animates a checkmark, then
            // triggers onClose itself. List mutates in-place; no reload of
            // `installedApps` triggered.
            deletionSucceededFor = selected.id
            owner.installedApps.removeAll { $0.id == selected.id }
            Logger.shared.log("Uninstalled \(selected.appName)", level: .info)
            return
        }

        // Partial delete: app survives, only related files removed. Update
        // the cached discoveredURLs / fileSizes / relatedSize so reopening
        // the modal shows the trimmed set instead of resurrecting the
        // deleted rows.
        guard !removed.isEmpty,
              let idx = owner.installedApps.firstIndex(where: { $0.id == selected.id }) else { return }
        let removedSet = Set(removed)
        var app = owner.installedApps[idx]
        if var urls = app.discoveredURLs {
            urls.removeAll { removedSet.contains($0) }
            app.discoveredURLs = urls
        }
        if var reasons = app.matchReasons {
            for url in removed { reasons.removeValue(forKey: url) }
            app.matchReasons = reasons
        }
        if var sizes = app.fileSizes {
            for url in removed { sizes.removeValue(forKey: url) }
            app.fileSizes = sizes
            // Recompute relatedSize from the trimmed map (excluding the
            // .app bundle itself).
            app.relatedSize = sizes.filter { $0.key != app.path }.values.reduce(0, +)
        }
        owner.installedApps[idx] = app
        owner.selectedApp = app

        let n = removed.count
        fileDeletionNotice = Localization.shared.t(.uninstallDeletedFilesFormat, n)
        let token = UUID()
        fileDeletionToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self, self.fileDeletionToken == token else { return }
            self.fileDeletionNotice = nil
        }
        Logger.shared.log("Deleted \(n) file(s) from \(selected.appName)", level: .info)
    }
}
