import Foundation

struct DiskInfo {
    var totalSpace: Int64 = 0
    var freeSpace: Int64 = 0
    var usedSpace: Int64 = 0
    var purgeableSpace: Int64 = 0

    var usedPercentage: Double {
        guard totalSpace > 0 else { return 0 }
        return Double(usedSpace) / Double(totalSpace)
    }
    var freePercentage: Double {
        guard totalSpace > 0 else { return 0 }
        return Double(freeSpace) / Double(totalSpace)
    }
    var formattedTotal:     String { ByteCountFormatter.string(fromByteCount: totalSpace,     countStyle: .file) }
    var formattedFree:      String { ByteCountFormatter.string(fromByteCount: freeSpace,      countStyle: .file) }
    var formattedUsed:      String { ByteCountFormatter.string(fromByteCount: usedSpace,      countStyle: .file) }
    var formattedPurgeable: String { ByteCountFormatter.string(fromByteCount: purgeableSpace, countStyle: .file) }
}
