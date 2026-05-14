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

    /// Help glossary entry id for the inline `?` popover. Matches a
    /// markdown file under `Resources/Help/`.
    var helpEntryID: String {
        switch self {
        case .systemJunk:       return "system-junk"
        case .userCache:        return "user-cache"
        case .trashBins:        return "trash-bins"
        case .purgeableSpace:   return "purgeable-space"
        case .developerCaches:  return "developer-caches"
        }
    }

    /// Localization key for the category's display name. Use
    /// `loc.t(cat.titleKey)` from views — `rawValue` stays as the
    /// stable internal id (used for persistence).
    var titleKey: LocalizationKey {
        switch self {
        case .systemJunk:       return .categorySystemJunk
        case .userCache:        return .categoryUserCache
        case .trashBins:        return .categoryTrashBins
        case .purgeableSpace:   return .categoryPurgeable
        case .developerCaches:  return .categoryDevCaches
        }
    }

    var subtitleKey: LocalizationKey {
        switch self {
        case .systemJunk:       return .categorySystemJunkSubtitle
        case .userCache:        return .categoryUserCacheSubtitle
        case .trashBins:        return .categoryTrashBinsSubtitle
        case .purgeableSpace:   return .categoryPurgeableSubtitle
        case .developerCaches:  return .categoryDevCachesSubtitle
        }
    }
}
