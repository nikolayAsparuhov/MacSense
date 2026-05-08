import Foundation

/// Day-count buckets used by the Unused Apps tab. Stored as raw days
/// in `UserDefaults` so a future "custom value" iteration can drop in
/// without a migration — the integer is the source of truth.
enum UnusedThreshold: Int, CaseIterable, Identifiable, Codable {
    case d30 = 30
    case d60 = 60
    case d90 = 90
    case d180 = 180

    var id: Int { rawValue }

    var label: String { "\(rawValue) days" }

    var seconds: TimeInterval { Double(rawValue) * 86_400 }

    private static let defaultsKey = "MacSense.UnusedApps.ThresholdDays"

    static var current: UnusedThreshold {
        get {
            let raw = UserDefaults.standard.integer(forKey: defaultsKey)
            return UnusedThreshold(rawValue: raw) ?? .d90
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
        }
    }
}
