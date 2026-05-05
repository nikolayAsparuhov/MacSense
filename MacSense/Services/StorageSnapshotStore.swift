import Foundation

/// Persists the storage scan snapshot to disk so the next launch can
/// hydrate the Size + Type tabs instantly while a fresh scan runs in
/// the background. GrandPerspective uses the same pattern — show
/// stale-but-readable data immediately, refresh in place.
///
/// Storage location: `~/Library/Caches/<bundle id>/storage-graph.plist`
/// Binary plist keeps the file compact (~5-50 MB on a typical Mac
/// versus 5× that for JSON) and decodes faster.
enum StorageSnapshotStore {
    private static let filename = "storage-graph.plist"

    private static var fileURL: URL? {
        let fm = FileManager.default
        guard let cacheDir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let bundleID = Bundle.main.bundleIdentifier ?? "tech.veraio.macsense"
        let dir = cacheDir.appendingPathComponent(bundleID, isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(filename)
    }

    static func save(_ snapshot: StorageSnapshot) {
        guard let url = fileURL else { return }
        do {
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .binary
            let data = try encoder.encode(snapshot)
            try data.write(to: url, options: [.atomic])
        } catch {
            Logger.shared.log("StorageSnapshotStore.save failed: \(error.localizedDescription)", level: .warning)
        }
    }

    static func load() -> StorageSnapshot? {
        guard let url = fileURL,
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let snapshot = try PropertyListDecoder().decode(StorageSnapshot.self, from: data)
            return snapshot
        } catch {
            Logger.shared.log("StorageSnapshotStore.load failed: \(error.localizedDescription)", level: .warning)
            return nil
        }
    }

    static func clear() {
        guard let url = fileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
