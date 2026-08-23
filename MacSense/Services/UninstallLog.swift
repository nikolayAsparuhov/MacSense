import Foundation

/// One uninstall, recorded path by path.
///
/// The point is answerability: after the fact, the user (or a support thread)
/// can see exactly what left the machine, what was skipped and why, and what
/// failed — instead of a single "uninstalled X" line in the app log.
struct UninstallLogEntry: Codable {
    struct PathOutcome: Codable {
        let path: String
        /// Never localized — this file is read long after the UI language is
        /// forgotten, and by people who didn't run the uninstall.
        let reason: String
    }

    let timestamp: Date
    let appName: String
    let bundleIdentifier: String
    let appPath: String
    /// "trash" or "permanent" — what the user asked for.
    let mode: String
    let safetyLevel: String
    let deleted: [String]
    let skipped: [PathOutcome]
    let failed: [PathOutcome]
    let excludedCount: Int
    let reclaimedBytes: Int64
    let quitProcesses: [String]
    let bootedOutJobs: [String]
    /// Login items macOS may keep listing until it prunes its own database.
    let btmResidual: [String]
    let success: Bool
}

/// Append-only JSON log of every uninstall, kept in Application Support.
///
/// An `actor` because it is written from the background task that performs the
/// deletion. Capped so it can't grow without bound on a long-lived install.
actor UninstallLog {
    static let shared = UninstallLog()

    private let maxEntries = 500

    nonisolated var fileURL: URL? {
        let fm = FileManager.default
        guard let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let bundleID = Bundle.main.bundleIdentifier ?? "tech.veraio.macsense"
        let dir = base.appendingPathComponent(bundleID, isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("uninstall-log.json")
    }

    func record(_ entry: UninstallLogEntry) {
        guard let url = fileURL else { return }
        var entries = load()
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(entries)
            try data.write(to: url, options: [.atomic])
        } catch {
            Logger.shared.log("UninstallLog write failed: \(error.localizedDescription)", level: .warning)
        }
    }

    func entries() -> [UninstallLogEntry] {
        load().sorted { $0.timestamp > $1.timestamp }
    }

    func clear() {
        guard let url = fileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private func load() -> [UninstallLogEntry] {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([UninstallLogEntry].self, from: data)) ?? []
    }
}
