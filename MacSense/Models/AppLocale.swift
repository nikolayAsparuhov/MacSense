import Foundation

/// Supported in-app languages. Codes follow the BCP-47 conventions
/// SwiftUI / Apple frameworks already use (`zh-Hans` for Simplified
/// Chinese, two-letter ISO codes elsewhere). The display name on
/// the picker is rendered in the locale's own script — that's the
/// convention every cross-cultural language picker follows so each
/// user can recognize their own language regardless of current UI.
enum AppLocale: String, CaseIterable, Identifiable, Codable {
    case en
    case zhHans = "zh-Hans"
    case hi
    case es
    case fr
    case bn
    case pt
    case ru
    case de

    var id: String { rawValue }

    /// Native name in the locale's own writing system.
    var displayName: String {
        switch self {
        case .en:     return "English"
        case .zhHans: return "中文"
        case .hi:     return "हिन्दी"
        case .es:     return "Español"
        case .fr:     return "Français"
        case .bn:     return "বাংলা"
        case .pt:     return "Português"
        case .ru:     return "Русский"
        case .de:     return "Deutsch"
        }
    }

    /// Resolves to a supported locale based on the user's macOS
    /// preferred languages list, falling back to English when no
    /// match exists. Used the first time the app launches before
    /// the user has explicitly picked a language.
    static var systemPreferred: AppLocale {
        let preferred = Locale.preferredLanguages
        for code in preferred {
            // Locale.preferredLanguages looks like ["en-US", "bg-BG"].
            // Match the language portion against our raw values plus
            // the special-case `zh-Hans` prefix.
            if code.hasPrefix("zh") {
                return .zhHans
            }
            let lang = code.split(separator: "-").first.map(String.init) ?? code
            if let match = AppLocale(rawValue: lang) {
                return match
            }
        }
        return .en
    }
}
