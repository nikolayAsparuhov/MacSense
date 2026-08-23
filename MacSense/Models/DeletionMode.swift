import Foundation

/// How an uninstall disposes of the files it removes.
///
/// `permanent` applies to items in the user's own domain only. Anything that
/// needs an administrator password is still moved to the Trash through the
/// escalated path — MacSense never runs `rm` as root, so a mistake made under
/// escalation stays recoverable.
enum DeletionMode: String, CaseIterable, Identifiable {
    case trash
    case permanent

    var id: String { rawValue }

    var titleKey: LocalizationKey {
        switch self {
        case .trash:     return .deletionModeTrash
        case .permanent: return .deletionModePermanent
        }
    }

    var systemImage: String {
        switch self {
        case .trash:     return "trash"
        case .permanent: return "trash.slash"
        }
    }

    /// Permanent deletion is never a default and never silent.
    var alwaysRequiresConfirmation: Bool { self == .permanent }

    private static let defaultsKey = "MacSense.DeletionMode"

    static var stored: DeletionMode {
        DeletionMode(rawValue: UserDefaults.standard.string(forKey: defaultsKey) ?? "") ?? .trash
    }

    static func store(_ mode: DeletionMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: defaultsKey)
    }
}
