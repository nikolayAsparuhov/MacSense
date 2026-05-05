import SwiftUI

/// Coarse media classification used by the Storage breakdown.
enum MediaType: String, CaseIterable, Identifiable {
    case videos
    case photos
    case audio
    case archives
    case documents
    case code
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .videos:    return "Videos"
        case .photos:    return "Photos"
        case .audio:     return "Audio"
        case .archives:  return "Archives"
        case .documents: return "Documents"
        case .code:      return "Code"
        case .other:     return "Other"
        }
    }

    var icon: String {
        switch self {
        case .videos:    return "film"
        case .photos:    return "photo"
        case .audio:     return "music.note"
        case .archives:  return "doc.zipper"
        case .documents: return "doc.text"
        case .code:      return "chevron.left.forwardslash.chevron.right"
        case .other:     return "doc"
        }
    }

    var color: Color {
        switch self {
        case .videos:    return Theme.Palette.coral
        case .photos:    return Theme.Palette.amber
        case .audio:     return Theme.Palette.violet
        case .archives:  return Theme.Palette.indigo
        case .documents: return Theme.Palette.sky
        case .code:      return Theme.Palette.mint
        case .other:     return .gray
        }
    }

    static let extensions: [MediaType: Set<String>] = [
        .videos:    ["mp4","mov","mkv","avi","webm","m4v","flv","wmv","mpeg","mpg","3gp","ts"],
        .photos:    ["jpg","jpeg","png","heic","heif","gif","bmp","tiff","tif","webp","raw","cr2","cr3","nef","dng","arw","orf"],
        .audio:     ["mp3","flac","wav","m4a","aac","ogg","opus","aiff","alac","wma","aif"],
        .archives:  ["zip","tar","gz","tgz","bz2","xz","7z","rar","dmg","iso","pkg","jar","war","deb","rpm"],
        .documents: ["pdf","docx","doc","pages","rtf","txt","md","odt","xlsx","xls","numbers","pptx","ppt","key","keynote","epub","mobi","csv"],
        .code:      ["swift","tsx","ts","jsx","js","mjs","py","rb","go","rs","java","kt","cs","c","cpp","cc","h","hpp","sh","bash","zsh","html","css","scss","sass","less","sql","yaml","yml","json","xml","toml","graphql","proto","r","scala","php"],
        .other:     []
    ]

    static func classify(extension ext: String) -> MediaType {
        let lower = ext.lowercased()
        for (type, exts) in extensions where exts.contains(lower) { return type }
        return .other
    }
}

struct MediaBreakdown: Identifiable {
    let id = UUID()
    let type: MediaType
    var totalSize: Int64
    var fileCount: Int
}

struct StorageReport {
    let totalScanned: Int64
    let breakdowns: [MediaBreakdown]
    let largeFiles: [CleanableItem]
    /// Top files per media type, biggest first. Used by the Type tab to
    /// show a per-category preview ("top 5") plus the full list when the
    /// user opens the Details sheet.
    let filesByType: [MediaType: [CleanableItem]]
    let scannedAt: Date
}
