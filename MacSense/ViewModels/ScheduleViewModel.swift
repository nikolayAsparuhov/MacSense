import Foundation
import SwiftUI
import UserNotifications

/// Owns the published state for the Schedule subsection. Keeps the
/// settings store as the source of truth so a fresh launch lands on
/// the same configuration the user last saved without any extra
/// hydration step in `AppState.init`.
@MainActor
final class ScheduleViewModel: ObservableObject {
    @Published var isEnabled: Bool
    @Published var cadence: ScheduleCadence
    @Published var categories: Set<CleaningCategory>
    @Published var lastRun: Date?
    @Published var lastTotalRecoverable: Int64
    @Published var authStatus: UNAuthorizationStatus = .notDetermined

    private let settings: ScheduleSettingsStore

    init(settings: ScheduleSettingsStore = ScheduleSettingsStore()) {
        self.settings = settings
        self.isEnabled = settings.isEnabled
        self.cadence = settings.cadence
        self.categories = settings.categories
        self.lastRun = settings.lastRun
        self.lastTotalRecoverable = settings.lastTotalRecoverable
        Task { [weak self] in
            await self?.refreshAuthStatus()
        }
    }

    /// Toggle the schedule on/off. Off → cancel any pending request.
    /// On → submit a fresh request at the current cadence.
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        settings.isEnabled = enabled
        if enabled {
            BackgroundScheduler.submit(cadence: cadence)
        } else {
            BackgroundScheduler.cancel()
        }
    }

    func setCadence(_ value: ScheduleCadence) {
        cadence = value
        settings.cadence = value
        if isEnabled {
            BackgroundScheduler.submit(cadence: value)
        }
    }

    func toggleCategory(_ category: CleaningCategory) {
        if categories.contains(category) {
            categories.remove(category)
        } else {
            categories.insert(category)
        }
        settings.categories = categories
    }

    /// Called by `AppState.runScheduledCleanupScan` after the worker
    /// finishes a successful scheduled scan. Persists the summary so
    /// the UI can render a "Last scan" hint on next foreground.
    func recordRun(totalRecoverable: Int64, at date: Date = Date()) {
        settings.lastRun = date
        settings.lastTotalRecoverable = totalRecoverable
        lastRun = date
        lastTotalRecoverable = totalRecoverable
    }

    func refreshAuthStatus() async {
        authStatus = await NotificationsService.authorizationStatus()
    }

    /// Format the next-run hint as a relative duration. We don't try
    /// to compute the exact next fire timestamp because BGTask doesn't
    /// expose it — this label echoes the cadence so the user sees
    /// confirmation that the schedule is active.
    var summaryLine: String {
        let cats = categories.count
        let unit = cats == 1 ? "category" : "categories"
        return "\(cadence.label) · \(cats) \(unit)"
    }
}
