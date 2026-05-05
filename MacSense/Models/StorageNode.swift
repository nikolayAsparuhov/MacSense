import Foundation

/// Node in the storage graph. One per directory or per surfaced file.
/// Reference type because the graph is shared across the navigation
/// stack and copying multi-million-node trees would be wasteful.
final class StorageNode: Identifiable {
    let id = UUID()
    let path: String
    let name: String
    let size: Int64
    let isDirectory: Bool
    /// Count of immediate entries (files + folders) inside this dir.
    /// For files this is 0.
    let childCount: Int
    /// Sub-directories + a bounded set of largest immediate files. The
    /// long tail of small files is rolled into a single synthetic
    /// "Other files" node so the bubble canvas stays readable.
    let children: [StorageNode]

    /// True when this node is the synthetic catch-all created by the
    /// scanner to bucket the long tail of small files.
    let isAggregateOther: Bool

    init(path: String, name: String, size: Int64, isDirectory: Bool,
         childCount: Int, children: [StorageNode], isAggregateOther: Bool = false) {
        self.path = path
        self.name = name
        self.size = size
        self.isDirectory = isDirectory
        self.childCount = childCount
        self.children = children
        self.isAggregateOther = isAggregateOther
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

extension StorageNode: Hashable {
    static func == (lhs: StorageNode, rhs: StorageNode) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Persistence

/// Codable-friendly snapshot. The runtime `id` (UUID) is regenerated
/// on load — saving it would balloon the file with no value, since
/// the graph is identified by path during navigation.
extension StorageNode: Codable {
    private enum CodingKeys: String, CodingKey {
        case path, name, size, isDirectory, childCount, children, isAggregateOther
    }

    convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            path: try c.decode(String.self, forKey: .path),
            name: try c.decode(String.self, forKey: .name),
            size: try c.decode(Int64.self, forKey: .size),
            isDirectory: try c.decode(Bool.self, forKey: .isDirectory),
            childCount: try c.decode(Int.self, forKey: .childCount),
            children: try c.decode([StorageNode].self, forKey: .children),
            isAggregateOther: try c.decode(Bool.self, forKey: .isAggregateOther)
        )
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(path, forKey: .path)
        try c.encode(name, forKey: .name)
        try c.encode(size, forKey: .size)
        try c.encode(isDirectory, forKey: .isDirectory)
        try c.encode(childCount, forKey: .childCount)
        try c.encode(children, forKey: .children)
        try c.encode(isAggregateOther, forKey: .isAggregateOther)
    }
}

// MARK: - Cached snapshot wrapper

/// Top-level wrapper persisted to disk. Carries timestamp so the UI
/// can surface "scanned 3 hours ago" + the graph + the report.
struct StorageSnapshot: Codable {
    let scannedAt: Date
    let graph: StorageNode
    let totalScanned: Int64
    let breakdowns: [StorageSnapshot.Breakdown]
    let largeFiles: [CleanableItem]
    let filesByType: [String: [CleanableItem]]

    struct Breakdown: Codable {
        let typeRaw: String
        let totalSize: Int64
        let fileCount: Int
    }

    static func from(graph: StorageNode, report: StorageReport) -> StorageSnapshot {
        StorageSnapshot(
            scannedAt: report.scannedAt,
            graph: graph,
            totalScanned: report.totalScanned,
            breakdowns: report.breakdowns.map {
                Breakdown(typeRaw: $0.type.rawValue, totalSize: $0.totalSize, fileCount: $0.fileCount)
            },
            largeFiles: report.largeFiles,
            filesByType: Dictionary(uniqueKeysWithValues: report.filesByType.map { ($0.key.rawValue, $0.value) })
        )
    }

    func toReport() -> StorageReport {
        let bds = breakdowns.compactMap { b -> MediaBreakdown? in
            guard let t = MediaType(rawValue: b.typeRaw) else { return nil }
            return MediaBreakdown(type: t, totalSize: b.totalSize, fileCount: b.fileCount)
        }
        let byType = Dictionary(uniqueKeysWithValues: filesByType.compactMap { (k, v) -> (MediaType, [CleanableItem])? in
            guard let t = MediaType(rawValue: k) else { return nil }
            return (t, v)
        })
        return StorageReport(
            totalScanned: totalScanned,
            breakdowns: bds,
            largeFiles: largeFiles,
            filesByType: byType,
            scannedAt: scannedAt
        )
    }
}
