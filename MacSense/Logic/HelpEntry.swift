import Foundation

/// One glossary entry parsed from a single markdown file under
/// `Resources/Help/`. The id is the file name (sans `.md`); the rest
/// is derived by `parse(from:id:)` so the bundle drives both the
/// popover summary and the drawer detail.
struct HelpEntry: Identifiable, Equatable {
    let id: String
    let title: String
    /// Short paragraph rendered inside the inline popover. Pulled
    /// from the first non-empty paragraph after the title heading.
    let summary: String
    /// Full markdown source. The drawer renders this with
    /// `AttributedString(markdown:)`.
    let body: String

    /// Returns nil when the file is empty or has no `# Title` line.
    static func parse(from markdown: String, id: String) -> HelpEntry? {
        let lines = markdown.split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline })
            .map(String.init)
        guard let titleLineIndex = lines.firstIndex(where: { $0.hasPrefix("# ") }) else {
            return nil
        }
        let title = String(lines[titleLineIndex].dropFirst(2)).trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return nil }

        // First paragraph after the title — collapse contiguous lines
        // until we hit a blank line, the next heading, or end of file.
        var summaryLines: [String] = []
        var idx = titleLineIndex + 1
        // Skip leading blanks.
        while idx < lines.count, lines[idx].trimmingCharacters(in: .whitespaces).isEmpty {
            idx += 1
        }
        while idx < lines.count {
            let line = lines[idx]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { break }
            if trimmed.hasPrefix("#") { break }
            summaryLines.append(trimmed)
            idx += 1
        }
        let summary = summaryLines.joined(separator: " ")
        return HelpEntry(id: id, title: title, summary: summary, body: markdown)
    }
}
