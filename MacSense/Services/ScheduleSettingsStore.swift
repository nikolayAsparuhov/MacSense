import Foundation

enum ScheduleCadence: String, CaseIterable, Identifiable, Codable {
    case daily, weekly, monthly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .daily:   return "Daily"
        case .weekly:  return "Weekly"
        case .monthly: return "Monthly"
        }
    }

    var labelKey: LocalizationKey {
        switch self {
        case .daily:   return .cadenceDaily
        case .weekly:  return .cadenceWeekly
        case .monthly: return .cadenceMonthly
        }
    }

    /// Earliest-begin offset passed to `BGTaskScheduler`. macOS treats
    /// this as a hint, not a guarantee — see spec for the constraint.
    var interval: TimeInterval {
        switch self {
        case .daily:   return 24 * 60 * 60
        case .weekly:  return 7 * 24 * 60 * 60
        case .monthly: return 30 * 24 * 60 * 60
        }
    }
}

/// `UserDefaults`-backed persistence for the schedule subsection.
/// Kept deliberately small — none of the values are sensitive, none
/// need migration, and the schedule view model owns the in-memory
/// copy that the UI binds to.
struct ScheduleSettingsStore {
    private enum Key {
        static let enabled              = "MacSense.Schedule.Enabled"
        static let cadence              = "MacSense.Schedule.Cadence"
        static let categories           = "MacSense.Schedule.Categories"
        static let lastRun              = "MacSense.Schedule.LastRun"
        static let lastTotalRecoverable = "MacSense.Schedule.LastTotalRecoverable"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isEnabled: Bool {
        get { defaults.bool(forKey: Key.enabled) }
        nonmutating set { defaults.set(newValue, forKey: Key.enabled) }
    }

    var cadence: ScheduleCadence {
        get {
            guard let raw = defaults.string(forKey: Key.cadence),
                  let value = ScheduleCadence(rawValue: raw) else { return .weekly }
            return value
        }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Key.cadence) }
    }

    /// Selected cleanup categories. Default = all categories so users
    /// who flip the switch with no further input get a sensible scan.
    var categories: Set<CleaningCategory> {
        get {
            guard let raw = defaults.array(forKey: Key.categories) as? [String] else {
                return Set(CleaningCategory.allCases)
            }
            return Set(raw.compactMap { CleaningCategory(rawValue: $0) })
        }
        nonmutating set {
            defaults.set(newValue.map(\.rawValue), forKey: Key.categories)
        }
    }

    var lastRun: Date? {
        get {
            let value = defaults.double(forKey: Key.lastRun)
            return value > 0 ? Date(timeIntervalSince1970: value) : nil
        }
        nonmutating set {
            defaults.set(newValue?.timeIntervalSince1970 ?? 0, forKey: Key.lastRun)
        }
    }

    var lastTotalRecoverable: Int64 {
        get { Int64(defaults.integer(forKey: Key.lastTotalRecoverable)) }
        nonmutating set { defaults.set(Int(newValue), forKey: Key.lastTotalRecoverable) }
    }
}
