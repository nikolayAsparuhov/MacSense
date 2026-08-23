import AppKit
import Foundation

/// Everything that has to happen *before* an app's files are deleted.
///
/// Deleting a running app's bundle leaves the live process writing into paths
/// that no longer exist, and deleting a launch agent's plist without booting
/// the job out first leaves the agent running until the next reboot — with its
/// plist gone, nothing can stop it cleanly. Both are corrected here, in order:
/// quit the processes, tear down the launchd jobs, then let the caller delete.
enum UninstallPreflight {

    struct Outcome {
        /// Processes that exited (bundle identifiers).
        var quit: [String] = []
        /// Processes that refused to exit even after `forceTerminate`.
        var stillRunning: [String] = []
        /// launchd labels booted out and disabled.
        var bootedOut: [String] = []
        /// launchd labels that could not be torn down.
        var failedJobs: [String] = []
        /// Labels registered through `SMAppService`. These are booted out and
        /// disabled like any other job, but their entry lives in macOS's
        /// background-task database, which no third-party app can write to.
        /// System Settings may keep listing them until macOS prunes the entry.
        var btmResidual: [String] = []

        var isBlocked: Bool { !stillRunning.isEmpty }
    }

    /// Quits the app (and its helpers), then tears down its launchd jobs.
    /// `plannedPaths` are the files about to be deleted — a launchd plist
    /// among them belongs to this app even if its label says otherwise.
    static func run(for app: InstalledApp, plannedPaths: [URL]) async -> Outcome {
        var outcome = Outcome()
        let quitResult = await quitProcesses(for: app)
        outcome.quit = quitResult.quit
        outcome.stillRunning = quitResult.stillRunning

        // A process that won't die will keep recreating what we remove. Stop
        // before touching launchd or the file system.
        guard outcome.stillRunning.isEmpty else { return outcome }

        let jobs = await tearDownLaunchdJobs(for: app, plannedPaths: plannedPaths)
        outcome.bootedOut = jobs.bootedOut
        outcome.failedJobs = jobs.failed
        outcome.btmResidual = jobs.btmResidual
        return outcome
    }

    /// True when the app or one of its helpers is running right now.
    @MainActor
    static func isRunning(_ app: InstalledApp) -> Bool {
        !matchingProcesses(for: app).isEmpty
    }

    // MARK: - Processes

    @MainActor
    private static func matchingProcesses(for app: InstalledApp) -> [NSRunningApplication] {
        let bundleID = app.bundleIdentifier
        let appPath = app.path.standardizedFileURL.path
        return NSWorkspace.shared.runningApplications.filter { running in
            if running.processIdentifier == ProcessInfo.processInfo.processIdentifier { return false }
            if let id = running.bundleIdentifier {
                // Anchored on a dot so `com.acme.app` never claims
                // `com.acme.appstore`.
                if id == bundleID || id.hasPrefix(bundleID + ".") { return true }
            }
            // Helpers and XPC services live inside the bundle and often carry
            // an unrelated identifier.
            if let url = running.bundleURL?.standardizedFileURL,
               url.path == appPath || url.path.hasPrefix(appPath + "/") {
                return true
            }
            return false
        }
    }

    @MainActor
    private static func quitProcesses(
        for app: InstalledApp
    ) async -> (quit: [String], stillRunning: [String]) {
        let targets = matchingProcesses(for: app)
        guard !targets.isEmpty else { return ([], []) }

        for process in targets { process.terminate() }
        var alive = await waitForExit(targets, timeout: 5)

        if !alive.isEmpty {
            // A normal quit can be refused by an unsaved-changes dialog or a
            // wedged main thread; the user already asked for the app to go.
            for process in alive { process.forceTerminate() }
            alive = await waitForExit(alive, timeout: 2)
        }

        let aliveIDs = Set(alive.map { $0.bundleIdentifier ?? $0.localizedName ?? "unknown" })
        let quit = targets
            .map { $0.bundleIdentifier ?? $0.localizedName ?? "unknown" }
            .filter { !aliveIDs.contains($0) }
        Logger.shared.log("Preflight quit \(quit.count) process(es) for \(app.appName), \(aliveIDs.count) still running",
                          level: .info)
        return (Array(Set(quit)), Array(aliveIDs))
    }

    @MainActor
    private static func waitForExit(
        _ processes: [NSRunningApplication],
        timeout: TimeInterval
    ) async -> [NSRunningApplication] {
        let deadline = Date().addingTimeInterval(timeout)
        var remaining = processes.filter { !$0.isTerminated }
        while !remaining.isEmpty, Date() < deadline {
            try? await Task.sleep(nanoseconds: 200_000_000)
            remaining = remaining.filter { !$0.isTerminated }
        }
        return remaining
    }

    // MARK: - launchd

    private static func tearDownLaunchdJobs(
        for app: InstalledApp,
        plannedPaths: [URL]
    ) async -> (bootedOut: [String], failed: [String], btmResidual: [String]) {
        let plannedSet = Set(plannedPaths.map { $0.standardizedFileURL.path })
        let appPath = app.path.standardizedFileURL.path
        let bundleID = app.bundleIdentifier

        let jobs = LoginItemScanner.shared.scan().filter { item in
            if let id = item.bundleIdentifier, id == bundleID || id.hasPrefix(bundleID + ".") { return true }
            if item.label == bundleID || item.label.hasPrefix(bundleID + ".") { return true }
            if plannedSet.contains(item.plistURL.standardizedFileURL.path) { return true }
            if let program = item.program ?? item.programArguments.first,
               program == appPath || program.hasPrefix(appPath + "/") {
                return true
            }
            return false
        }
        guard !jobs.isEmpty else { return ([], [], []) }

        var bootedOut: [String] = []
        var failed: [String] = []
        var residual: [String] = []
        for job in jobs {
            // `delete` boots the job out, writes the sticky disable override,
            // and removes the plist unless it lives inside the app bundle —
            // in which case it goes away with the bundle itself.
            if await LoginItemScanner.shared.delete(job) {
                bootedOut.append(job.label)
                if job.isEmbedded { residual.append(job.label) }
            } else {
                failed.append(job.label)
            }
        }
        Logger.shared.log("Preflight tore down \(bootedOut.count) launchd job(s) for \(app.appName)",
                          level: .info)
        return (bootedOut, failed, residual)
    }
}
