import Foundation

/// Loads `.md` files from `Resources/Help/<locale>/` (locale-specific
/// translations) and falls back to `Resources/Help/` (English source
/// of truth) when an entry is missing for the active locale. Cached
/// per-locale so repeated lookups don't re-walk the bundle.
@MainActor
enum HelpRegistry {
    private static let helpSubdirectory = "Help"

    /// Active locale at the most recent build. The cache stores the
    /// merged English-fallback entries for that locale; switching
    /// locales rebuilds it on next access.
    private static var cachedLocale: AppLocale?
    private static var cachedEntries: [HelpEntry] = []

    private static func entries(for locale: AppLocale) -> [HelpEntry] {
        if cachedLocale == locale { return cachedEntries }

        var byID: [String: HelpEntry] = [:]

        // English baseline first.
        for url in Bundle.main.urls(forResourcesWithExtension: "md", subdirectory: helpSubdirectory) ?? [] {
            guard let raw = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let id = url.deletingPathExtension().lastPathComponent
            if let entry = HelpEntry.parse(from: raw, id: id) {
                byID[id] = entry
            }
        }

        // Locale-specific overrides (skip when locale is English —
        // already loaded above).
        if locale != .en {
            let localeSubdir = "\(helpSubdirectory)/\(locale.rawValue)"
            for url in Bundle.main.urls(forResourcesWithExtension: "md", subdirectory: localeSubdir) ?? [] {
                guard let raw = try? String(contentsOf: url, encoding: .utf8) else { continue }
                let id = url.deletingPathExtension().lastPathComponent
                if let entry = HelpEntry.parse(from: raw, id: id) {
                    byID[id] = entry
                }
            }
        }

        let merged = Array(byID.values)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        cachedLocale = locale
        cachedEntries = merged
        return merged
    }

    /// All entries sorted alphabetically by title in the current locale.
    static var entries: [HelpEntry] { entries(for: Localization.shared.locale) }

    static func entry(id: String) -> HelpEntry? {
        entries.first(where: { $0.id == id })
    }

    /// Substring search across title + body. Empty query returns
    /// the full alphabetical list unchanged.
    static func search(_ query: String) -> [HelpEntry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let all = entries
        guard !q.isEmpty else { return all }
        return all.filter {
            $0.title.localizedCaseInsensitiveContains(q) ||
            $0.body.localizedCaseInsensitiveContains(q)
        }
    }
}
