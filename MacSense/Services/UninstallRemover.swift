import AppKit
import Foundation

/// Executes a removal that has already been validated and confirmed.
///
/// Split out of `UninstallViewModel` so the view model stays about state and
/// this stays about doing the work: re-validate, delete, escalate when the
/// user's own permissions aren't enough, and record the result.
enum UninstallRemover {

    /// One item cleared for deletion. `original` is what the UI listed;
    /// `canonical` is what actually gets deleted — they differ whenever the
    /// discovered path went through a symlink.
    struct ValidatedRemoval: Sendable {
        let original: URL
        let canonical: URL
    }

    struct Request: Sendable {
        let items: [ValidatedRemoval]
        let mode: DeletionMode
        /// Per-URL sizes captured before the delete, used for the reclaimed
        /// total in the log — the files are gone by the time it is written.
        let sizes: [URL: Int64]
        let context: LogContext
    }

    struct Result: Sendable {
        let removed: [URL]
        let permissionFailures: [URL]
        let otherFailures: [(URL, Error)]
    }

    /// Performs a validated removal off the main actor and returns what
    /// happened. Writes the uninstall log before returning, so the record
    /// exists even if the caller has gone away by then.
    static func perform(_ request: Request) async -> Result {
        let items = request.items
        let mode = request.mode
        let context = request.context
        let sizes = request.sizes

        return await Task.detached(priority: .userInitiated) { () -> Result in
            let fm = FileManager.default
            var removed: [URL] = []
            var permFails: [URL] = []
            var otherFails: [(URL, Error)] = []
            var needAuthRetry: [ValidatedRemoval] = []
            var skipped: [UninstallLogEntry.PathOutcome] = context.planTimeSkips
            var deletedPaths: [String] = []

            for item in items {
                // Re-validate immediately before the destructive call. The scan
                // and the click are seconds apart; a symlink swapped in that
                // window would otherwise be followed with the old verdict.
                guard case .success(let target) = UninstallPathValidator.validate(item.original) else {
                    Logger.shared.log("Skipped \(item.original.path) — failed re-validation at delete time",
                                      level: .warning)
                    skipped.append(UninstallLogEntry.PathOutcome(
                        path: item.original.path, reason: "failed re-validation at delete time"))
                    continue
                }
                do {
                    switch mode {
                    case .trash:
                        try fm.trashItem(at: target, resultingItemURL: nil)
                    case .permanent:
                        try fm.removeItem(at: target)
                    }
                    removed.append(item.original)
                    deletedPaths.append(target.path)
                } catch let err as NSError {
                    if isPermissionError(err) {
                        // Escalated removals always go to the Trash, even in
                        // permanent mode: nothing is deleted outright as root.
                        needAuthRetry.append(ValidatedRemoval(original: item.original, canonical: target))
                    } else {
                        otherFails.append((item.original, err))
                    }
                    Logger.shared.log("trashItem failed for \(target.path): \(err)", level: .info)
                }
            }
            if !needAuthRetry.isEmpty {
                let outcome = await recycleWithAuth(items: needAuthRetry)
                removed.append(contentsOf: outcome.removed)
                permFails.append(contentsOf: outcome.failed)
                deletedPaths.append(contentsOf: outcome.removed.map(\.path))
            }

            await writeLog(context: context,
                           deletedPaths: deletedPaths,
                           removed: removed,
                           permFails: permFails,
                           otherFails: otherFails,
                           skipped: skipped,
                           sizes: sizes)

            return Result(removed: removed, permissionFailures: permFails, otherFailures: otherFails)
        }.value
    }

    // MARK: - Logging

    /// Everything the log entry needs that lives on the main actor, captured
    /// once before the removal task starts.
    struct LogContext: Sendable {
        let appName: String
        let bundleIdentifier: String
        let appPath: String
        let mode: DeletionMode
        let safetyLevel: String
        let excludedCount: Int
        let quitProcesses: [String]
        let bootedOutJobs: [String]
        let btmResidual: [String]
        let planTimeSkips: [UninstallLogEntry.PathOutcome]

        init(app: InstalledApp?, mode: DeletionMode, safetyLevel: String, excludedCount: Int,
             preflight: UninstallPreflight.Outcome?, planTimeSkips: [UninstallLogEntry.PathOutcome]) {
            appName = app?.appName ?? "unknown"
            bundleIdentifier = app?.bundleIdentifier ?? "unknown"
            appPath = app?.path.path ?? ""
            self.mode = mode
            self.safetyLevel = safetyLevel
            self.excludedCount = excludedCount
            quitProcesses = preflight?.quit ?? []
            bootedOutJobs = preflight?.bootedOut ?? []
            btmResidual = preflight?.btmResidual ?? []
            self.planTimeSkips = planTimeSkips
        }
    }

    private static func writeLog(
        context: LogContext,
        deletedPaths: [String],
        removed: [URL],
        permFails: [URL],
        otherFails: [(URL, Error)],
        skipped: [UninstallLogEntry.PathOutcome],
        sizes: [URL: Int64]
    ) async {
        var failed = permFails.map {
            UninstallLogEntry.PathOutcome(path: $0.path, reason: "administrator authorization cancelled or denied")
        }
        failed += otherFails.map {
            UninstallLogEntry.PathOutcome(path: $0.0.path, reason: $0.1.localizedDescription)
        }
        let reclaimed = removed.reduce(Int64(0)) { $0 + (sizes[$1] ?? 0) }

        await UninstallLog.shared.record(UninstallLogEntry(
            timestamp: Date(),
            appName: context.appName,
            bundleIdentifier: context.bundleIdentifier,
            appPath: context.appPath,
            mode: context.mode.rawValue,
            safetyLevel: context.safetyLevel,
            deleted: deletedPaths,
            skipped: skipped,
            failed: failed,
            excludedCount: context.excludedCount,
            reclaimedBytes: reclaimed,
            quitProcesses: context.quitProcesses,
            bootedOutJobs: context.bootedOutJobs,
            btmResidual: context.btmResidual,
            success: failed.isEmpty
        ))
    }

    // MARK: - Privilege escalation

    static func isPermissionError(_ err: NSError) -> Bool {
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

    /// Retries permission-denied removals as an administrator. Every path is
    /// re-validated once more here — the escalated command runs as root, so it
    /// is built exclusively from paths the validator just approved, never from
    /// raw scan output.
    ///
    /// Returns removals keyed by their *original* URL so the caller's list
    /// bookkeeping keeps working.
    private static func recycleWithAuth(
        items: [ValidatedRemoval]
    ) async -> (removed: [URL], failed: [URL]) {
        var approved: [ValidatedRemoval] = []
        var failed: [URL] = []
        for item in items {
            switch UninstallPathValidator.validate(item.original) {
            case .success(let target):
                approved.append(ValidatedRemoval(original: item.original, canonical: target))
            case .failure(let rejection):
                Logger.shared.log("Refused admin removal of \(item.original.path): \(rejection.reason.debugLabel)",
                                  level: .warning)
                failed.append(item.original)
            }
        }
        guard !approved.isEmpty else { return ([], failed) }

        let trashRoot = NSHomeDirectory() + "/.Trash"
        let qTrash = shellSingleQuote(trashRoot)
        let cmds = approved.map { item -> String in
            let src = shellSingleQuote(item.canonical.path)
            let name = shellSingleQuote(item.canonical.lastPathComponent)
            return "/bin/mv -f \(src) \(qTrash)/\(name) 2>/dev/null || /bin/mv -f \(src) \(qTrash)/$(/bin/date +%s)_\(name)"
        }
        // Root-owned items land in the user's Trash still owned by root, which
        // makes emptying the Trash prompt again. Hand them back to the user.
        let chown = "/usr/sbin/chown -R $(/usr/bin/id -u):$(/usr/bin/id -g) \(qTrash) 2>/dev/null || true"
        let asEscaped = (cmds + [chown]).joined(separator: "; ")
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
                let removed = approved.filter { !fm.fileExists(atPath: $0.canonical.path) }.map(\.original)
                let stillThere = approved.filter { fm.fileExists(atPath: $0.canonical.path) }.map(\.original)
                continuation.resume(returning: (removed, failed + stillThere))
            }
        }
    }

    private static func shellSingleQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
