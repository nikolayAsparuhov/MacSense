import SwiftUI

/// Top-level cleanup buckets. Five categories — `developerCaches` rolls up
/// what PureMac split into Xcode/Brew/Node/Docker because MacSense surfaces
/// them as a single "developer cache" tile and expands on click.
enum CleaningCategory: String, CaseIterable, Identifiable, Codable {
    case systemJunk        = "System Junk"
    case userCache         = "User Cache"
    case trashBins         = "Trash Bins"
    case purgeableSpace    = "Purgeable Space"
    case developerCaches   = "Developer Caches"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .systemJunk:       return "trash.slash"
        case .userCache:        return "internaldrive"
        case .trashBins:        return "trash"
        case .purgeableSpace:   return "arrow.3.trianglepath"
        case .developerCaches:  return "hammer"
        }
    }

    var subtitle: String {
        switch self {
        case .systemJunk:       return "Logs and temp files outside your home"
        case .userCache:        return "App caches under ~/Library/Caches"
        case .trashBins:        return "Files in your Trash"
        case .purgeableSpace:   return "TM snapshots + macOS evictable bytes"
        case .developerCaches:  return "Xcode, Homebrew, npm/yarn/pnpm, Docker, Go, Cargo"
        }
    }
}
