import Foundation

/// Loads every `.md` file under `Resources/Help` from the app bundle
/// and exposes them as `HelpEntry` lookups. Resolved lazily on first
/// access so a fresh launch doesn't pay the parse cost up front.
enum HelpRegistry {
    private static let helpSubdirectory = "Help"

    private static let allEntries: [HelpEntry] = {
        let urls = Bundle.main.urls(forResourcesWithExtension: "md", subdirectory: helpSubdirectory) ?? []
        let parsed: [HelpEntry] = urls.compactMap { url in
            guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            let id = url.deletingPathExtension().lastPathComponent
            return HelpEntry.parse(from: raw, id: id)
        }
        return parsed.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }()

    /// All entries sorted alphabetically by title.
    static var entries: [HelpEntry] { allEntries }

    static func entry(id: String) -> HelpEntry? {
        allEntries.first(where: { $0.id == id })
    }

    /// Substring search across title + body. Empty query returns
    /// the full alphabetical list unchanged.
    static func search(_ query: String) -> [HelpEntry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return allEntries }
        return allEntries.filter {
            $0.title.localizedCaseInsensitiveContains(q) ||
            $0.body.localizedCaseInsensitiveContains(q)
        }
    }
}
