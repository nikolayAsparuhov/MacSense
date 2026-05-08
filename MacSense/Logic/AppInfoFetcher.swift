import Foundation
import AppKit

struct InstalledApp: Identifiable, Hashable {
    let id: UUID
    let appName: String
    let bundleIdentifier: String
    let path: URL
    /// Computed lazily on access via `NSWorkspace.icon(forFile:)` so
    /// hundreds of installed apps don't sit on hundreds of NSImage
    /// bitmap reps in idle memory. NSWorkspace caches resolution
    /// internally for repeated paths, so re-renders stay fast.
    var icon: NSImage { NSWorkspace.shared.icon(forFile: path.path) }
    /// Recursive size of the .app bundle itself.
    let bundleSize: Int64
    /// Sum of related files (caches, prefs, containers, ...) once a scan has
    /// run. `nil` means "not yet computed". Mutable so the table can update
    /// progressively as the background sizer finishes each app.
    var relatedSize: Int64?
    /// URLs returned by the path finder during discovery. Cached so the
    /// uninstall sheet shows the same set + total as the list — re-running
    /// `findPathsAsync` later can return a different set due to ordering
    /// in the heuristic walker, which made the modal total disagree with
    /// the list total (e.g. SketchUp 5.9 GB list vs 3.44 GB modal).
    var discoveredURLs: [URL]?
    /// Per-URL allocated sizes captured during the related-size walk.
    /// Lets the uninstall modal display row sizes that always sum to the
    /// modal header (and match the list cell). Without this, recomputing
    /// per-row size in the modal could disagree with the precomputed
    /// `relatedSize` (folders that happened to be empty during the modal
    /// re-walk would render as 0 KB despite contributing to the total).
    var fileSizes: [URL: Int64]?
    /// Last-used timestamp from Spotlight (`kMDItemLastUsedDate`).
    /// `nil` means the app has either never been launched or its
    /// Spotlight metadata isn't available — the Unused tab shows
    /// these in a separate "Never opened" group.
    var lastUsedDate: Date?

    /// Total size. When per-URL sizes have been captured, derive the
    /// total directly from them — that way the list cell, the modal
    /// header, and the sum of visible rows are guaranteed to agree.
    /// Falls back to `bundleSize + relatedSize` while sizing streams in.
    var size: Int64 {
        if let fs = fileSizes, !fs.isEmpty {
            return fs.values.reduce(0, +)
        }
        return bundleSize + (relatedSize ?? 0)
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var isSizeFullyKnown: Bool { relatedSize != nil }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: InstalledApp, rhs: InstalledApp) -> Bool {
        lhs.id == rhs.id
    }
}

final class AppInfoFetcher {
    static let shared = AppInfoFetcher()
    private let fileManager = FileManager.default

    private static let protectedBundleIDs: Set<String> = [
        "com.apple.Safari", "com.apple.finder", "com.apple.AppStore",
        "com.apple.systempreferences", "com.apple.Terminal",
        "com.apple.ActivityMonitor", "com.apple.dt.Xcode",
        "com.apple.mail", "com.apple.iCal", "com.apple.AddressBook",
        "com.apple.Preview", "com.apple.TextEdit", "com.apple.calculator",
        "com.apple.MobileSMS", "com.apple.FaceTime", "com.apple.Music",
        "com.apple.TV", "com.apple.Podcasts", "com.apple.News",
        "com.apple.Maps", "com.apple.Photos", "com.apple.Notes",
        "com.apple.reminders", "com.apple.Stocks", "com.apple.Home",
        "com.apple.weather", "com.apple.clock", "com.apple.Passwords",
    ]

    private init() {}

    func fetchInstalledApps() -> [InstalledApp] {
        var apps: [InstalledApp] = []
        var seenBundleIDs: Set<String> = []

        let searchPaths = [
            "/Applications",
            "\(home)/Applications",
            "/System/Applications",
        ]

        for searchPath in searchPaths {
            guard let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: searchPath),
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let url as URL in enumerator {
                guard url.pathExtension == "app" else { continue }

                // Skip subdirectories inside .app bundles
                enumerator.skipDescendants()

                // Skip system/protected apps
                if url.path.hasPrefix("/System") { continue }

                guard let app = loadAppInfo(from: url),
                      !seenBundleIDs.contains(app.bundleIdentifier),
                      !Self.protectedBundleIDs.contains(app.bundleIdentifier) else { continue }

                seenBundleIDs.insert(app.bundleIdentifier)
                apps.append(app)
            }
        }

        return apps.sorted { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }
    }

    private func loadAppInfo(from url: URL) -> InstalledApp? {
        guard let bundle = Bundle(url: url) else { return nil }

        let fileName = url.deletingPathExtension().lastPathComponent
        let bundleID = bundle.bundleIdentifier?.nonEmpty ?? fileName
        // Some apps ship CFBundleDisplayName / CFBundleName as empty strings
        // in localized Info.plist entries (notably HitPaw, some App Store
        // apps). Plain nil-coalescing falls through to the filename only on
        // nil — empty strings would render as a blank row. Treat empty as
        // missing so the filename fallback kicks in.
        let displayName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)?.nonEmpty
        let bundleName = (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)?.nonEmpty
        let appName = displayName ?? bundleName ?? fileName

        // Icon is now computed lazily on InstalledApp access — don't
        // load + retain an NSImage at scan time for every app on disk.

        // Recursive walk — `totalFileAllocatedSizeKey` on a directory returns
        // only the directory entry's own block, not its contents. Calling it
        // directly on a .app bundle silently under-reports by 100x+.
        let bundleSize = url.recursiveAllocatedSize()

        return InstalledApp(
            id: UUID(),
            appName: appName,
            bundleIdentifier: bundleID,
            path: url,
            bundleSize: bundleSize,
            relatedSize: nil,
            lastUsedDate: LastUsedFetcher.lastUsedDate(forAppAt: url)
        )
    }
}
