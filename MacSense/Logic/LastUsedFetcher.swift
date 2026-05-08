import Foundation
import CoreServices

/// Reads `kMDItemLastUsedDate` from Spotlight for an app bundle.
/// Centralized here so the rest of the codebase doesn't need to
/// import `CoreServices` directly.
///
/// `MDItemCreate` is fast (microsecond range) and cache-backed by
/// the Spotlight daemon, so calling it once per app bundle during
/// the install-list build adds no noticeable cost.
enum LastUsedFetcher {
    static func lastUsedDate(forAppAt url: URL) -> Date? {
        guard let item = MDItemCreate(nil, url.path as CFString) else { return nil }
        let value = MDItemCopyAttribute(item, kMDItemLastUsedDate)
        return value as? Date
    }
}
