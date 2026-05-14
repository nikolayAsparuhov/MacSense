import SwiftUI
import Combine

/// Root observable for MacSense.
@MainActor
final class AppState: ObservableObject {
    // Navigation
    @Published var selectedSection: AppSection = .cleanup {
        didSet {
            if selectedSection == .performance { hasVisitedPerformance = true }
            // Closing-on-navigate: any open inline modal dismisses
            // on ANY sidebar tap.
            openedCategory = nil
            selectedApp = nil

            // Free heavy in-memory state when the user leaves a
            // section so idle RAM stays bounded. The on-disk snapshot
            // / scan results stay; re-entry re-hydrates from there.
            if oldValue != selectedSection {
                releaseSectionMemory(leaving: oldValue)
                hydrateSectionMemory(entering: selectedSection)
            }
        }
    }

    /// Drop the bulky data structures owned by `section` whenever the
    /// user navigates away. Triggered from `selectedSection.didSet`.
    /// Aggressive — the user's expected to opt back in (re-scan or
    /// re-open the modal) if they want the data again. Cleanup
    /// category results stay because the Cleanup hero needs them
    /// to render the "X recoverable" pill.
    private func releaseSectionMemory(leaving section: AppSection) {
        switch section {
        case .storage:
            // Drop the bulky tree AND the in-memory snapshot copy.
            // The snapshot still lives on disk, so re-entry hydrates
            // from `StorageSnapshotStore.load()` async — keeps idle
            // RAM bounded even after a deep scan. The lightweight
            // summary (`storageReport`) and explicit-scan flag stay
            // so the section header still renders without bouncing
            // the user back to the hero.
            storageGraph = nil
            cachedSnapshot = nil
            sizeNavStack = []
            sizeNavSelection.removeAll()
            trashedSizeNodeIDs.removeAll()
            storageSelectedFiles.removeAll()
            sizeNavPendingDelete = nil
        case .applications:
            // Keep the lightweight list (name, bundle, icon, size)
            // but drop the heavy per-URL maps. Re-opening an app
            // modal re-runs the path finder.
            for i in installedApps.indices {
                installedApps[i].fileSizes = nil
                installedApps[i].discoveredURLs = nil
            }
            discoveredFiles = []
            selectedFiles = []
            appFileSizes = [:]
        case .cleanup, .performance:
            break
        }
    }

    /// Counterpart to `releaseSectionMemory` — re-hydrate the heavy
    /// state when the user re-enters a section. For Storage, this
    /// rebuilds the graph from the cached snapshot (in-memory first,
    /// disk fallback) so the bubble map renders immediately on
    /// return without forcing a re-scan.
    private func hydrateSectionMemory(entering section: AppSection) {
        switch section {
        case .storage:
            guard userRequestedStorageScan, storageGraph == nil else { return }
            if let snapshot = cachedSnapshot {
                storageGraph = snapshot.graph
                if storageReport == nil { storageReport = snapshot.toReport() }
                if sizeNavStack.isEmpty { sizeNavStack = [snapshot.graph] }
                return
            }
            // Snapshot was already dropped from memory but the report
            // summary survived — pull the graph back from disk.
            Task.detached(priority: .userInitiated) { [weak self] in
                guard let snapshot = StorageSnapshotStore.load() else { return }
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    guard self.userRequestedStorageScan, self.storageGraph == nil else { return }
                    self.cachedSnapshot = snapshot
                    self.storageGraph = snapshot.graph
                    if self.storageReport == nil { self.storageReport = snapshot.toReport() }
                    if self.sizeNavStack.isEmpty { self.sizeNavStack = [snapshot.graph] }
                }
            }
        case .applications, .cleanup, .performance:
            break
        }
    }

    @Published var isSidebarCollapsed: Bool = false
    /// True once the user has opened the Performance section at least
    /// once. Sidebar uses this to suppress the health dot until the
    /// user has actually engaged with the section — avoids a colored
    /// dot appearing on first launch with no prior context.
    @Published var hasVisitedPerformance: Bool = false

    // Cleanup
    @Published var diskInfo = DiskInfo()
    @Published var categoryResults: [CleaningCategory: CategoryResult] = [:]
    @Published var categoryStates: [CleaningCategory: CategoryState] = [:]
    @Published var deselectedItems: Set<UUID> = []
    /// Category whose detail sheet is currently open (nil = none).
    @Published var openedCategory: CleaningCategory? = nil
    /// Smart Scan progress (0.0 - 1.0). Active when > 0 and < 1.
    @Published var smartScanProgress: Double = 0
    @Published var isSmartScanRunning: Bool = false

    // Applications
    @Published var installedApps: [InstalledApp] = []
    @Published var isLoadingApps: Bool = false
    /// Becomes true once every installed app's related-file size has been
    /// computed. While false, the list keeps a stable bundle-size sort
    /// order so the rows don't reshuffle as sizes stream in. Flipping to
    /// true triggers a single final sort by total size.
    @Published var appsSizingComplete: Bool = false
    @Published var selectedApp: InstalledApp? = nil
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
    /// Generation token for the auto-dismiss timer of
    /// `fileDeletionNotice`. Stops a stale dismiss from clearing a newer
    /// notice when partial deletes happen back-to-back.
    private var fileDeletionToken: UUID?
    /// Per-URL allocated size, populated in the background after the
    /// uninstall sheet opens. Reading this map is O(1); recomputing
    /// `recursiveAllocatedSize` on every render froze the modal because
    /// SwiftUI re-evaluated the selected-size sum hundreds of times
    /// during interaction.
    @Published var appFileSizes: [URL: Int64] = [:]

    // Login items
    @Published var loginItems: [LoginItem] = []
    @Published var isLoadingLoginItems: Bool = false
    /// Surfaced when toggling or deleting a login item fails — alert
    /// shown by `LoginItemsList`. Cleared by the user dismissing.
    @Published var loginItemError: String? = nil

    // Full Disk Access prompt. Surfaced by scan entry points when the
    // probe in `FullDiskAccessManager` reports the permission is
    // missing, so the user gets a clear nudge instead of silently
    // partial scan results.
    @Published var showFDAPrompt: Bool = false

    /// Re-check FDA before kicking off a scan. Returns true when the
    /// permission is granted; otherwise raises the modal prompt and
    /// returns false so the caller can abort.
    @discardableResult
    func ensureFullDiskAccess() -> Bool {
        if FullDiskAccessManager.shared.hasFullDiskAccess { return true }
        showFDAPrompt = true
        return false
    }

    // Storage
    @Published var storageReport: StorageReport? = nil
    @Published var isScanningStorage: Bool = false
    @Published var storageSelectedFiles: Set<UUID> = []
    /// Flips true the first time the user clicks Scan / Re-scan in this
    /// session. Until then, the Storage section shows its hero even when
    /// a cached snapshot exists — explicit opt-in for an expensive scan.
    @Published var userRequestedStorageScan: Bool = false

    /// Full storage graph rooted at `/`. Built once per scan; drill-down
    /// is a pure pointer dereference into this tree, no I/O.
    @Published var storageGraph: StorageNode? = nil
    /// Drill-down stack for the Size tab. Always non-empty when the user
    /// has entered the tab — `last` is the folder whose children are
    /// rendered as bubbles. Pop to go up.
    @Published var sizeNavStack: [StorageNode] = []
    /// IDs of children in the CURRENT folder that the user has marked
    /// for deletion. Cleared on navigation or after a delete.
    @Published var sizeNavSelection: Set<UUID> = []
    /// IDs of nodes already moved to Trash this session — filtered out
    /// of all bubble + sidebar renders so the UI doesn't show ghosts.
    /// Re-scan rebuilds the graph and clears this set.
    @Published var trashedSizeNodeIDs: Set<UUID> = []
    /// Pending delete confirmation payload — when non-nil the
    /// SizeTabView shows the confirm dialog.
    @Published var sizeNavPendingDelete: [StorageNode]? = nil

    private let scanEngine = ScanEngine()
    private let cleaningEngine = CleaningEngine()
    private let storageGraphScanner = StorageGraphScanner()

    /// Backing model for the Schedule subsection inside Cleanup.
    /// Owned here so a single instance survives the SwiftUI view
    /// lifecycle and the BGTask handler can update it after a
    /// scheduled scan finishes.
    let scheduleVM = ScheduleViewModel()

    /// Drawer state for the Help glossary. Any view can call
    /// `appState.help.open(at: "purgeable-space")` to surface the
    /// drawer scrolled to the relevant entry.
    let help = HelpController()

    /// Live localization service. Views read `appState.loc.t(.key)`
    /// from `body`; switching `loc.locale` flips every `t(...)`
    /// lookup and SwiftUI re-renders the affected subtree.
    let loc = Localization.shared

    /// Cached snapshot from a prior scan, loaded silently on launch.
    /// Held privately so the sidebar dot and Storage page hero don't
    /// react to it — only revealed via `storageGraph` / `storageReport`
    /// after the user clicks Scan and a short reveal delay elapses.
    private var cachedSnapshot: StorageSnapshot?
    /// Monotonic ID per scan invocation. Used to cancel a cache-reveal
    /// timer if the real scan completes before the timer fires.
    private var currentScanEpoch: UUID?

    /// Shared monitor — always running so the sidebar health dot
    /// reflects live CPU/Memory/temperature pressure even when the
    /// user isn't on the Performance tab.
    let performanceMonitor = PerformanceMonitor()

    /// Cached public IP from `api.ipify.org`. Fetched once at app
    /// startup so the Performance tab and Wi-Fi info modal both
    /// surface it instantly without each view doing its own request.
    /// Nil while the request is in flight or after a permanent
    /// failure (offline, captive portal).
    @Published var publicIP: String? = nil
    @Published var isFetchingPublicIP: Bool = false

    private var monitorCancellables = Set<AnyCancellable>()

    init() {
        Task { await loadDiskInfo() }
        performanceMonitor.start()
        // Re-publish monitor changes through this AppState so any view
        // already observing AppState (sidebar, PerformanceView) sees
        // the rolling sample/healthStatus updates without holding its
        // own @ObservedObject reference to the monitor.
        performanceMonitor.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &monitorCancellables)
        // Load cached snapshot off the main thread into a PRIVATE field.
        // Not exposed via @Published — sidebar dot + Storage hero stay
        // clear until the user clicks Scan. Used by `scanStorage()` to
        // give an instant-feeling reveal after a 5-10s delay while the
        // real scan continues in the background.
        Task.detached(priority: .background) { [weak self] in
            guard let snapshot = StorageSnapshotStore.load() else { return }
            await MainActor.run { [weak self] in
                self?.cachedSnapshot = snapshot
            }
        }
        // Kick off public-IP lookup once at startup. Fire-and-forget;
        // result lands on @Published so views render it when ready.
        Task { [weak self] in
            await self?.refreshPublicIP()
        }
        // Ask for notification permission once on first launch so
        // scheduled-scan summaries can reach the user later. We don't
        // gate scheduling on the result — the Schedule UI surfaces a
        // banner with a System Settings shortcut when denied.
        Task {
            await NotificationsService.requestAuthorizationIfNeeded()
        }
        // If the user previously turned the schedule on, resume the
        // recurring activity now. NSBackgroundActivityScheduler does
        // not persist across app quits.
        if scheduleVM.isEnabled {
            BackgroundScheduler.submit(cadence: scheduleVM.cadence)
        }
    }

    /// Fetch the public IP via api.ipify.org. Tries multiple endpoints
    /// in order so a single blocked endpoint doesn't permanently leave
    /// the field empty. Logs failures so we can diagnose when the row
    /// stays "—".
    func refreshPublicIP() async {
        if isFetchingPublicIP { return }
        isFetchingPublicIP = true
        defer { isFetchingPublicIP = false }
        let endpoints = [
            "https://api.ipify.org",
            "https://ifconfig.me/ip",
            "https://icanhazip.com",
            "https://ipv4.icanhazip.com",
        ]
        for endpoint in endpoints {
            guard let url = URL(string: endpoint) else { continue }
            var req = URLRequest(url: url)
            req.timeoutInterval = 5
            req.setValue("MacSense", forHTTPHeaderField: "User-Agent")
            do {
                let (data, _) = try await URLSession.shared.data(for: req)
                let text = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !text.isEmpty {
                    self.publicIP = text
                    return
                }
            } catch {
                Logger.shared.log("public IP fetch \(endpoint) failed: \(error.localizedDescription)", level: .info)
            }
        }
    }

    // MARK: - Disk Info

    func loadDiskInfo() async {
        let info = await scanEngine.getDiskInfo()
        diskInfo = info
    }

    // MARK: - Smart Scan (all categories)

    func runSmartScan() {
        guard !isSmartScanRunning else { return }
        guard ensureFullDiskAccess() else { return }
        isSmartScanRunning = true
        smartScanProgress = 0
        for cat in CleaningCategory.allCases { categoryStates[cat] = .scanning }

        Task {
            let cats = CleaningCategory.allCases
            for (idx, cat) in cats.enumerated() {
                let result = await scanEngine.scanCategory(cat)
                categoryResults[cat] = result
                categoryStates[cat] = .scanned
                smartScanProgress = Double(idx + 1) / Double(cats.count)
            }
            await loadDiskInfo()
            isSmartScanRunning = false
        }
    }

    // MARK: - Scheduled scan

    /// Worker invoked from the `BGTaskScheduler` launch handler. Runs
    /// the user-selected cleanup categories sequentially, posts a
    /// summary notification, persists the result on the schedule view
    /// model, then re-submits the next request so the cadence keeps
    /// going. Skips silently if a foreground Smart Scan is already
    /// running — we don't want to thrash the same engine in parallel.
    func runScheduledCleanupScan(task: BGTaskShim) async {
        let vm = scheduleVM
        guard vm.isEnabled, !vm.categories.isEmpty else {
            task.complete(success: true)
            return
        }
        // Don't run a parallel scan; the foreground Smart Scan already
        // covers the same categories and writing into `categoryResults`
        // from two paths at once would race the published state.
        guard !isSmartScanRunning else {
            task.complete(success: true)
            return
        }

        let cats = Array(vm.categories)
        var total: Int64 = 0
        for cat in cats {
            let result = await scanEngine.scanCategory(cat)
            categoryResults[cat] = result
            categoryStates[cat] = .scanned
            total += result.totalSize
        }

        await NotificationsService.postCleanupSummary(
            totalRecoverable: total,
            categoryCount: cats.count
        )
        vm.recordRun(totalRecoverable: total)
        task.complete(success: true)
    }

    // MARK: - Single category scan

    func scanCategory(_ category: CleaningCategory) {
        if case .scanning = categoryStates[category] { return }
        guard ensureFullDiskAccess() else { return }
        categoryStates[category] = .scanning
        Task {
            let result = await scanEngine.scanCategory(category)
            categoryResults[category] = result
            categoryStates[category] = .scanned
        }
    }

    // MARK: - Selection

    func isItemSelected(_ item: CleanableItem) -> Bool {
        !deselectedItems.contains(item.id)
    }

    func toggleItem(_ item: CleanableItem) {
        if deselectedItems.contains(item.id) {
            deselectedItems.remove(item.id)
        } else {
            deselectedItems.insert(item.id)
        }
    }

    func selectAll(in category: CleaningCategory) {
        guard let result = categoryResults[category] else { return }
        for item in result.items { deselectedItems.remove(item.id) }
    }

    func deselectAll(in category: CleaningCategory) {
        guard let result = categoryResults[category] else { return }
        for item in result.items { deselectedItems.insert(item.id) }
    }

    func selectedSize(in category: CleaningCategory) -> Int64 {
        guard let result = categoryResults[category] else { return 0 }
        return result.items.filter { isItemSelected($0) }.reduce(0) { $0 + $1.size }
    }

    func selectedCount(in category: CleaningCategory) -> Int {
        guard let result = categoryResults[category] else { return 0 }
        return result.items.filter { isItemSelected($0) }.count
    }

    // MARK: - Clean

    // MARK: - Installed Apps

    /// Two-phase discovery: fetch the .app bundle list fast, render
    /// immediately so the user can see + interact, then stream
    /// related-file sizes in the background. The list keeps a stable
    /// bundle-size sort order while sizes stream in (no shuffle), and
    /// re-sorts once after every app is fully sized.
    func loadInstalledApps() {
        guard ensureFullDiskAccess() else { return }
        isLoadingApps = true
        appsSizingComplete = false
        installedApps = []
        Task.detached(priority: .userInitiated) { [weak self] in
            let raw = AppInfoFetcher.shared.fetchInstalledApps()
            let initial = raw.sorted { $0.bundleSize > $1.bundleSize }
            await MainActor.run { [weak self] in
                self?.installedApps = initial
                self?.isLoadingApps = false
            }
            await self?.streamRelatedSizes(for: initial)
        }
    }

    /// Walks each app's related URLs in parallel, capturing both the
    /// total and a per-URL size map. Per-URL sizes flow back to
    /// `InstalledApp.fileSizes` so the uninstall modal can show row
    /// values that always sum to the modal header.
    private func streamRelatedSizes(for apps: [InstalledApp]) async {
        await withTaskGroup(of: (UUID, Int64, [URL], [URL: Int64]).self) { group in
            let maxConcurrent = 12
            var iterator = apps.makeIterator()
            var inFlight = 0
            func enqueueNext() {
                guard let app = iterator.next() else { return }
                let bundleSize = app.bundleSize
                let appPath = app.path
                group.addTask {
                    let urls = await Self.findRelatedURLs(for: app)
                    var perURL: [URL: Int64] = [:]
                    perURL.reserveCapacity(urls.count)
                    var related: Int64 = 0
                    for url in urls {
                        if url == appPath {
                            // Reuse the cached bundle size — saves one
                            // full re-walk of the .app per app.
                            perURL[url] = bundleSize
                            continue
                        }
                        let s = url.recursiveAllocatedSize()
                        perURL[url] = s
                        related += s
                    }
                    return (app.id, related, urls.sorted { $0.path < $1.path }, perURL)
                }
                inFlight += 1
            }
            for _ in 0..<maxConcurrent { enqueueNext() }
            while inFlight > 0 {
                if let (id, size, urls, perURL) = await group.next() {
                    inFlight -= 1
                    await MainActor.run { [weak self] in
                        self?.applySizingResult(appID: id, related: size, urls: urls, fileSizes: perURL)
                    }
                    enqueueNext()
                }
            }
        }
        await MainActor.run { [weak self] in
            self?.appsSizingComplete = true
        }
    }

    private func applySizingResult(appID: UUID, related: Int64, urls: [URL], fileSizes: [URL: Int64]) {
        guard let idx = installedApps.firstIndex(where: { $0.id == appID }) else { return }
        installedApps[idx].relatedSize = related
        installedApps[idx].discoveredURLs = urls
        installedApps[idx].fileSizes = fileSizes
        if selectedApp?.id == appID {
            selectedApp?.relatedSize = related
            selectedApp?.discoveredURLs = urls
            selectedApp?.fileSizes = fileSizes
        }
    }

    /// Opens the uninstall sheet for an app. Reuses the URL set captured
    /// during discovery so the modal total always equals the list total.
    /// Re-running the heuristic finder mid-session can return a slightly
    /// different set (race-y aggregation across location threads), which
    /// made list and modal disagree — e.g. SketchUp 5.9 GB list vs 3.44 GB
    /// modal. Falls back to a fresh scan only if discovery hasn't run.
    /// Opens the uninstall sheet for an app. Reuses the URL set captured
    /// during discovery so the modal total always equals the list total.
    /// Per-URL sizes are populated in the background — the sheet appears
    /// instantly and stays interactive (close button, scrolling) while
    /// sizes stream in.
    func scanForAppFiles(_ app: InstalledApp) {
        guard ensureFullDiskAccess() else { return }
        discoveredFiles = []
        selectedFiles = []
        appFileSizes = [:]

        // Cached fast-path: per-URL sizes were captured during streaming
        // discovery. Sum-of-rows == relatedSize == modal header. No disk
        // walk on the main thread, no recompute.
        if let cached = app.discoveredURLs, !cached.isEmpty {
            isScanningAppFiles = false
            self.discoveredFiles = cached
            self.selectedFiles = Set(cached)
            self.appFileSizes = app.fileSizes ?? [:]
            return
        }

        // Fall-back: discovery hasn't finished sizing this app yet, or
        // the user opened the modal before streaming completed for this
        // row. Run the heuristic finder + sizer on a background task.
        isScanningAppFiles = true
        Task.detached(priority: .userInitiated) { [weak self] in
            let finder = Self.makeFinder(for: app)
            let urls = await withCheckedContinuation { (cont: CheckedContinuation<Set<URL>, Never>) in
                finder.findPathsAsync { result in cont.resume(returning: result) }
            }
            let sorted = urls.sorted { $0.path < $1.path }
            var perURL: [URL: Int64] = [:]
            perURL.reserveCapacity(urls.count)
            var related: Int64 = 0
            for url in urls {
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
                self.discoveredFiles = sorted
                self.selectedFiles = urls
                self.isScanningAppFiles = false
                self.appFileSizes = finalPerURL
                self.applySizingResult(appID: app.id, related: finalRelated, urls: sorted, fileSizes: finalPerURL)
            }
        }
    }

    nonisolated private static func makeFinder(for app: InstalledApp) -> AppPathFinder {
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

    private static func findRelatedURLs(for app: InstalledApp) async -> Set<URL> {
        let finder = makeFinder(for: app)
        return await withCheckedContinuation { continuation in
            finder.findPathsAsync { urls in
                continuation.resume(returning: urls)
            }
        }
    }

    func removeSelectedFiles() {
        let allURLs = Array(selectedFiles)
        let (urls, blocked): ([URL], [URL]) = allURLs.reduce(into: ([], [])) { acc, url in
            let resolved = url.resolvingSymlinksInPath().path
            let isBlocked = highRiskHomeDotPaths.contains { root in
                resolved == root || resolved.hasPrefix(root + "/")
            }
            if isBlocked { acc.1.append(url) } else { acc.0.append(url) }
        }
        removalError = nil
        if !blocked.isEmpty {
            Logger.shared.log("Refused \(blocked.count) high-risk dotpath(s)", level: .warning)
            selectedFiles.subtract(blocked)
        }
        guard !urls.isEmpty else {
            if !blocked.isEmpty {
                removalError = Localization.shared.t(.removalRefusedFormat, blocked.count)
            }
            return
        }
        trashItems(urls: urls)
    }

    private func trashItems(urls: [URL]) {
        Task.detached(priority: .userInitiated) { [weak self] in
            let fm = FileManager.default
            var removed: [URL] = []
            var permFails: [URL] = []
            var otherFails: [(URL, Error)] = []
            var needAuthRetry: [URL] = []
            for url in urls {
                do {
                    try fm.trashItem(at: url, resultingItemURL: nil)
                    removed.append(url)
                } catch let err as NSError {
                    if Self.isPermissionError(err) { needAuthRetry.append(url) }
                    else { otherFails.append((url, err)) }
                    Logger.shared.log("trashItem failed for \(url.path): \(err)", level: .info)
                }
            }
            if !needAuthRetry.isEmpty {
                let outcome = await Self.recycleWithAuth(urls: needAuthRetry)
                removed.append(contentsOf: outcome.removed)
                permFails.append(contentsOf: outcome.failed)
            }
            await MainActor.run { [weak self, removed, permFails, otherFails] in
                guard let self else { return }
                if !removed.isEmpty {
                    self.discoveredFiles.removeAll { removed.contains($0) }
                    self.selectedFiles.subtract(removed)
                }
                if !permFails.isEmpty {
                    let n = permFails.count
                    self.removalError = Localization.shared.t(.removalAuthCancelledFormat, n)
                } else if !otherFails.isEmpty {
                    let n = otherFails.count
                    let detail = otherFails.prefix(3)
                        .map { "\($0.0.lastPathComponent): \($0.1.localizedDescription)" }
                        .joined(separator: "; ")
                    self.removalError = Localization.shared.t(.removalNotRemovedFormat, n, detail)
                }
                if let selected = self.selectedApp {
                    let appGone = !FileManager.default.fileExists(atPath: selected.path.path)
                    if appGone {
                        // Full uninstall: the .app bundle is in Trash.
                        // Signal success to the expanded card BEFORE
                        // clearing the selected app — overlay observes
                        // this id, animates a checkmark, then triggers
                        // onClose itself. List mutates in-place; no
                        // reload of `installedApps` triggered.
                        self.deletionSucceededFor = selected.id
                        self.installedApps.removeAll { $0.id == selected.id }
                        Logger.shared.log("Uninstalled \(selected.appName)", level: .info)
                    } else if !removed.isEmpty,
                              let idx = self.installedApps.firstIndex(where: { $0.id == selected.id }) {
                        // Partial delete: app survives, only related
                        // files removed. Update the cached
                        // discoveredURLs / fileSizes / relatedSize so
                        // reopening the modal shows the trimmed set
                        // instead of resurrecting the deleted rows.
                        let removedSet = Set(removed)
                        var app = self.installedApps[idx]
                        if var urls = app.discoveredURLs {
                            urls.removeAll { removedSet.contains($0) }
                            app.discoveredURLs = urls
                        }
                        if var sizes = app.fileSizes {
                            for url in removed { sizes.removeValue(forKey: url) }
                            app.fileSizes = sizes
                            // Recompute relatedSize from the trimmed map
                            // (excluding the .app bundle itself).
                            let related = sizes
                                .filter { $0.key != app.path }
                                .values.reduce(0, +)
                            app.relatedSize = related
                        }
                        self.installedApps[idx] = app
                        self.selectedApp = app
                        // Show transient notice — auto-clears after 2s.
                        let n = removed.count
                        self.fileDeletionNotice = "Deleted \(n) file\(n == 1 ? "" : "s")"
                        let token = UUID()
                        self.fileDeletionToken = token
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                            guard let self else { return }
                            if self.fileDeletionToken == token {
                                self.fileDeletionNotice = nil
                            }
                        }
                        Logger.shared.log("Deleted \(n) file(s) from \(selected.appName)", level: .info)
                    }
                }
            }
        }
    }

    nonisolated private static func isPermissionError(_ err: NSError) -> Bool {
        if err.domain == NSCocoaErrorDomain,
           err.code == NSFileReadNoPermissionError || err.code == NSFileWriteNoPermissionError {
            return true
        }
        if let underlying = err.userInfo[NSUnderlyingErrorKey] as? NSError,
           underlying.domain == NSPOSIXErrorDomain,
           underlying.code == Int(EPERM) || underlying.code == Int(EACCES) {
            return true
        }
        return false
    }

    nonisolated private static func recycleWithAuth(urls: [URL]) async -> (removed: [URL], failed: [URL]) {
        guard !urls.isEmpty else { return ([], []) }
        let trashRoot = NSHomeDirectory() + "/.Trash"
        let qTrash = shellSingleQuote(trashRoot)
        let cmds = urls.map { url -> String in
            let src = shellSingleQuote(url.path)
            let name = shellSingleQuote(url.lastPathComponent)
            return "/bin/mv -f \(src) \(qTrash)/\(name) 2>/dev/null || /bin/mv -f \(src) \(qTrash)/$(/bin/date +%s)_\(name)"
        }
        let asEscaped = cmds.joined(separator: "; ")
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(asEscaped)\" with administrator privileges"
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                var errorInfo: NSDictionary?
                let script = NSAppleScript(source: source)
                _ = script?.executeAndReturnError(&errorInfo)
                if let errorInfo {
                    let code = (errorInfo[NSAppleScript.errorNumber] as? Int) ?? 0
                    if code != -128 {
                        let msg = (errorInfo[NSAppleScript.errorMessage] as? String) ?? "\(errorInfo)"
                        Logger.shared.log("admin trash failed (\(code)): \(msg)", level: .warning)
                    }
                }
                let fm = FileManager.default
                let removed = urls.filter { !fm.fileExists(atPath: $0.path) }
                let failed = urls.filter { fm.fileExists(atPath: $0.path) }
                continuation.resume(returning: (removed, failed))
            }
        }
    }

    nonisolated private static func shellSingleQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    // MARK: - Login Items

    func loadLoginItems() {
        guard ensureFullDiskAccess() else { return }
        isLoadingLoginItems = true
        Task.detached(priority: .userInitiated) { [weak self] in
            let items = LoginItemScanner.shared.scan()
            await MainActor.run { [weak self] in
                self?.loginItems = items
                self?.isLoadingLoginItems = false
            }
        }
    }

    func toggleLoginItem(_ item: LoginItem, enable: Bool) {
        // Optimistic UI: flip the toggle locally so the user gets
        // immediate feedback. If the underlying launchctl call fails,
        // revert and surface a notice.
        guard let idx = loginItems.firstIndex(where: { $0.id == item.id }) else { return }
        loginItems[idx] = LoginItem(
            id: item.id, label: item.label, plistURL: item.plistURL,
            program: item.program, programArguments: item.programArguments,
            bundleIdentifier: item.bundleIdentifier,
            appDisplayName: item.appDisplayName, iconSourcePath: item.iconSourcePath,
            signerName: item.signerName,
            isEmbedded: item.isEmbedded, scope: item.scope,
            isEnabled: enable, plistSize: item.plistSize, programSize: item.programSize,
            lastModified: item.lastModified, runAtLoad: item.runAtLoad, keepAlive: item.keepAlive
        )

        Task { [weak self] in
            let success = await LoginItemScanner.shared.setEnabled(enable, for: item)
            await MainActor.run { [weak self] in
                guard let self else { return }
                if !success, let revertIdx = self.loginItems.firstIndex(where: { $0.id == item.id }) {
                    self.loginItems[revertIdx] = LoginItem(
                        id: item.id, label: item.label, plistURL: item.plistURL,
                        program: item.program, programArguments: item.programArguments,
                        bundleIdentifier: item.bundleIdentifier,
                        appDisplayName: item.appDisplayName, iconSourcePath: item.iconSourcePath,
                        signerName: item.signerName,
                        isEmbedded: item.isEmbedded, scope: item.scope,
                        isEnabled: !enable, plistSize: item.plistSize, programSize: item.programSize,
                        lastModified: item.lastModified, runAtLoad: item.runAtLoad, keepAlive: item.keepAlive
                    )
                    let loc = Localization.shared
                    let action = loc.t(enable ? .loginItemEnableAction : .loginItemDisableAction)
                    let admin = item.scope.requiresAdmin ? loc.t(.loginItemAdminSuffix) : ""
                    self.loginItemError = loc.t(.loginItemActionFailedFormat, action, item.appDisplayName ?? item.label, admin)
                }
            }
        }
    }

    func deleteLoginItem(_ item: LoginItem) {
        Task {
            let success = await LoginItemScanner.shared.delete(item)
            if success {
                loginItems.removeAll { $0.id == item.id }
            }
        }
    }

    // MARK: - Storage

    func scanStorage() {
        guard !isScanningStorage else { return }
        guard ensureFullDiskAccess() else { return }
        let callers = Thread.callStackSymbols.dropFirst().prefix(4).joined(separator: " <- ")
        Logger.shared.log("scanStorage triggered by: \(callers)", level: .info)
        userRequestedStorageScan = true
        isScanningStorage = true
        // Wipe any prior data so a stale graph from a previous scan
        // doesn't render until either the cache reveal fires or the
        // real scan finishes.
        storageGraph = nil
        storageReport = nil
        sizeNavStack = []
        sizeNavSelection.removeAll()
        trashedSizeNodeIDs.removeAll()
        storageSelectedFiles.removeAll()

        let epoch = UUID()
        currentScanEpoch = epoch

        // If we have a cached snapshot from a prior session, schedule a
        // delayed reveal so the user sees data shortly without waiting
        // the full ~30s of the real scan. Random 5-10s delay so the
        // app doesn't feel mechanically deterministic. The real scan
        // continues in the background and replaces the snapshot when
        // it completes.
        if let snapshot = cachedSnapshot {
            let delay = Double.random(in: 5.0 ... 10.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                // Cancelled if a new scan started or the real scan
                // already completed first.
                guard self.currentScanEpoch == epoch else { return }
                guard self.storageGraph == nil else { return }
                self.storageGraph = snapshot.graph
                self.storageReport = snapshot.toReport()
                if self.sizeNavStack.isEmpty {
                    self.sizeNavStack = [snapshot.graph]
                }
            }
        }

        Task { [weak self] in
            guard let self else { return }
            let (graph, report) = await self.storageGraphScanner.build()

            // Drop the result if a newer scan superseded this one.
            guard self.currentScanEpoch == epoch else { return }

            self.storageReport = report
            self.storageGraph = graph

            // Re-anchor breadcrumb so the Size tab shows the fresh root.
            self.sizeNavStack = [graph]
            self.isScanningStorage = false
            self.currentScanEpoch = nil

            // Replace the cached snapshot with fresh data. Kept in
            // memory (instead of nil-ing) so re-entering Storage
            // after navigating away can rehydrate the graph
            // instantly without a disk read.
            let snapshot = StorageSnapshot.from(graph: graph, report: report)
            self.cachedSnapshot = snapshot
            Task.detached(priority: .background) {
                StorageSnapshotStore.save(snapshot)
            }
        }
    }


    func toggleStorageItem(_ id: UUID) {
        if storageSelectedFiles.contains(id) { storageSelectedFiles.remove(id) }
        else { storageSelectedFiles.insert(id) }
    }

    func selectAllStorage() {
        guard let report = storageReport else { return }
        storageSelectedFiles = Set(report.largeFiles.map(\.id))
    }

    func deselectAllStorage() { storageSelectedFiles.removeAll() }

    func storageSelectedSize() -> Int64 {
        guard let report = storageReport else { return 0 }
        return report.largeFiles
            .filter { storageSelectedFiles.contains($0.id) }
            .reduce(0) { $0 + $1.size }
    }

    // MARK: - Size-tab navigation

    /// Reset the breadcrumb to the graph root. The graph itself is
    /// built by `scanStorage()` — this only re-anchors navigation.
    func enterSizeRoot() {
        guard let graph = storageGraph else {
            sizeNavStack = []
            return
        }
        sizeNavStack = [graph]
    }

    /// Drill into a node. Pure pointer push; the children are already
    /// in memory from the initial graph build.
    func enterSizeFolder(_ node: StorageNode) {
        guard node.isDirectory, !node.isAggregateOther else { return }
        sizeNavStack.append(node)
        sizeNavSelection.removeAll()
    }

    /// Pop one level up (back button on the breadcrumb).
    func popSizeFolder() {
        guard sizeNavStack.count > 1 else { return }
        sizeNavStack.removeLast()
        sizeNavSelection.removeAll()
    }

    /// Jump to a specific point in the breadcrumb stack.
    func popSizeTo(index: Int) {
        guard index < sizeNavStack.count else { return }
        sizeNavStack = Array(sizeNavStack.prefix(index + 1))
        sizeNavSelection.removeAll()
    }

    func toggleSizeNodeSelection(_ node: StorageNode) {
        guard !node.isAggregateOther else { return }
        if sizeNavSelection.contains(node.id) {
            sizeNavSelection.remove(node.id)
        } else {
            sizeNavSelection.insert(node.id)
        }
    }

    func clearSizeNavSelection() {
        sizeNavSelection.removeAll()
    }

    /// Total bytes of currently selected children of the visible folder.
    func sizeNavSelectedBytes() -> Int64 {
        guard let current = sizeNavStack.last else { return 0 }
        return current.children
            .filter { sizeNavSelection.contains($0.id) }
            .reduce(0) { $0 + $1.size }
    }

    /// Open the confirm dialog for selected nodes — never trashes
    /// directly. Caller (view) presents the alert; on confirm it calls
    /// `confirmTrashSelectedSizeNodes`.
    func requestTrashSelectedSizeNodes() {
        guard let current = sizeNavStack.last else { return }
        let nodes = current.children.filter { sizeNavSelection.contains($0.id) }
        guard !nodes.isEmpty else { return }
        sizeNavPendingDelete = nodes
    }

    func confirmTrashSelectedSizeNodes() {
        guard let nodes = sizeNavPendingDelete else { return }
        sizeNavPendingDelete = nil
        let urls = nodes.map { (id: $0.id, url: URL(fileURLWithPath: $0.path)) }
        Task.detached(priority: .userInitiated) { [weak self] in
            let fm = FileManager.default
            var trashedIDs: Set<UUID> = []
            for entry in urls {
                do {
                    try fm.trashItem(at: entry.url, resultingItemURL: nil)
                    trashedIDs.insert(entry.id)
                } catch {
                    Logger.shared.log("trashItem failed for \(entry.url.path): \(error.localizedDescription)", level: .info)
                }
            }
            let finalTrashed = trashedIDs
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.trashedSizeNodeIDs.formUnion(finalTrashed)
                self.sizeNavSelection.subtract(finalTrashed)
                Task { await self.loadDiskInfo() }
            }
        }
    }

    func cancelTrashSelectedSizeNodes() {
        sizeNavPendingDelete = nil
    }

    // MARK: - Performance actions

    /// Flush macOS DNS cache (`dscacheutil -flushcache; killall -HUP
    /// mDNSResponder`). Requires admin — pops the auth sheet.
    func flushDNSCache() async -> Bool {
        await runAdminShell("/usr/bin/dscacheutil -flushcache && /usr/bin/killall -HUP mDNSResponder")
    }

    private nonisolated func runAdminShell(_ command: String) async -> Bool {
        let asEscaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(asEscaped)\" with administrator privileges"
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                var errorInfo: NSDictionary?
                let script = NSAppleScript(source: source)
                _ = script?.executeAndReturnError(&errorInfo)
                if let errorInfo {
                    let code = (errorInfo[NSAppleScript.errorNumber] as? Int) ?? 0
                    if code != -128 {
                        Logger.shared.log("admin shell failed (\(code))", level: .warning)
                    }
                    continuation.resume(returning: false)
                } else {
                    continuation.resume(returning: true)
                }
            }
        }
    }

    /// Trash currently-selected large files. Files live in user content
    /// directories (Downloads / Documents / Desktop / Movies / Music /
    /// Pictures) and are user-owned, so a plain `FileManager.trashItem`
    /// suffices — no admin escalation needed.
    /// Trash an explicit set of files by path. Used by the Type-tab
    /// detail sheet, which selects from `filesByType` rather than the
    /// `largeFiles` subset that `trashStorageSelection` operates on.
    func trashStorageItems(_ items: [CleanableItem]) {
        guard !items.isEmpty else { return }
        Task {
            let fm = FileManager.default
            var removedIDs: Set<UUID> = []
            for item in items {
                let url = URL(fileURLWithPath: item.path)
                do {
                    try fm.trashItem(at: url, resultingItemURL: nil)
                    removedIDs.insert(item.id)
                } catch {
                    Logger.shared.log("trashItem failed for \(item.path): \(error.localizedDescription)", level: .warning)
                }
            }
            // Refresh disk capacity (cheap diskutil call) without
            // triggering another full storage graph scan — the user
            // opted in to the previous scan explicitly and shouldn't get
            // a fresh one as a side effect of deleting files. If they
            // want updated breakdowns they can press Re-scan.
            if !removedIDs.isEmpty, let report = storageReport {
                let filtered = report.largeFiles.filter { !removedIDs.contains($0.id) }
                self.storageReport = StorageReport(
                    totalScanned: report.totalScanned,
                    breakdowns: report.breakdowns,
                    largeFiles: filtered,
                    filesByType: report.filesByType,
                    scannedAt: report.scannedAt
                )
                self.storageSelectedFiles.subtract(removedIDs)
            }
            await loadDiskInfo()
        }
    }

    func trashStorageSelection() {
        guard let report = storageReport else { return }
        let targets = report.largeFiles.filter { storageSelectedFiles.contains($0.id) }
        guard !targets.isEmpty else { return }

        Task {
            let fm = FileManager.default
            var removedIDs: Set<UUID> = []
            for item in targets {
                let url = URL(fileURLWithPath: item.path)
                do {
                    try fm.trashItem(at: url, resultingItemURL: nil)
                    removedIDs.insert(item.id)
                } catch {
                    Logger.shared.log("trashItem failed for \(item.path): \(error.localizedDescription)", level: .warning)
                }
            }
            // Filter the report in place so the UI updates.
            let filtered = report.largeFiles.filter { !removedIDs.contains($0.id) }
            // Recompute media-type aggregation from remaining largeFiles is
            // wrong (largeFiles is a subset). Easier: re-scan in background
            // so totals reflect reality.
            self.storageReport = StorageReport(
                totalScanned: report.totalScanned,
                breakdowns: report.breakdowns,
                largeFiles: filtered,
                filesByType: report.filesByType,
                scannedAt: report.scannedAt
            )
            self.storageSelectedFiles.subtract(removedIDs)
            // Refresh disk capacity only — never re-trigger a full
            // graph scan as a side effect. User opts in via Re-scan.
            await loadDiskInfo()
        }
    }

    // MARK: - Cleanup

    func clean(_ category: CleaningCategory) {
        guard let result = categoryResults[category] else { return }
        let items = result.items.filter { isItemSelected($0) }
        guard !items.isEmpty else { return }

        categoryStates[category] = .cleaning(progress: 0)

        Task {
            let outcome = await cleaningEngine.cleanItems(items) { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.categoryStates[category] = .cleaning(progress: progress)
                }
            }
            if outcome.errors.isEmpty {
                categoryStates[category] = .cleaned(freed: outcome.freedSpace)
            } else {
                let summary = outcome.errors.first ?? Localization.shared.t(.cleanupSomeItemsFailed)
                categoryStates[category] = .cleanedWithErrors(
                    freed: outcome.freedSpace,
                    message: summary
                )
                Logger.shared.log("Cleanup errors for \(category.rawValue): \(outcome.errors.joined(separator: " | "))", level: .warning)
            }
            categoryResults.removeValue(forKey: category)
            await loadDiskInfo()

            // Reset to idle after a beat so the user sees the "freed X"
            // confirmation, then the card recovers to the scan-prompt state.
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            categoryStates[category] = .idle
        }
    }
}
