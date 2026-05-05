import Foundation

/// One file or directory the cleaner can act on. `subCategory` lets the
/// developer-cache rollup display per-tool labels (e.g. "Xcode" vs "Brew")
/// when the user expands the row.
struct CleanableItem: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let path: String
    let size: Int64
    let category: CleaningCategory
    /// Optional finer label used by Developer Caches (e.g. "Xcode",
    /// "Homebrew", "npm"). Nil for everything else.
    var subCategory: String? = nil
    /// Plain-language explanation of what this item is and what
    /// happens when the user removes it. Shown under the row name as
    /// secondary text. Used for purgeable-space items where "name"
    /// alone isn't enough to convey the meaning.
    var explanation: String? = nil
    var isSelected: Bool
    let lastModified: Date?

    init(name: String, path: String, size: Int64,
         category: CleaningCategory, subCategory: String? = nil,
         explanation: String? = nil,
         isSelected: Bool, lastModified: Date?) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.size = size
        self.category = category
        self.subCategory = subCategory
        self.explanation = explanation
        self.isSelected = isSelected
        self.lastModified = lastModified
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: CleanableItem, rhs: CleanableItem) -> Bool { lhs.id == rhs.id }
}

struct CategoryResult: Identifiable {
    let id = UUID()
    let category: CleaningCategory
    var items: [CleanableItem]
    var totalSize: Int64

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    var itemCount: Int { items.count }
}

/// Coarse state of a category card.
enum CategoryState: Equatable {
    case idle                 // never scanned this session
    case scanning             // scan in progress
    case scanned              // scan finished, results in `categoryResults`
    case cleaning(progress: Double)
    case cleaned(freed: Int64)
    case cleanedWithErrors(freed: Int64, message: String)
}
