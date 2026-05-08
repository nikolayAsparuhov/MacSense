import Foundation
import UserNotifications
import AppKit

/// Thin actor-style wrapper around `UNUserNotificationCenter`. Owns the
/// one-time authorization prompt and posts cleanup-scan summary
/// notifications. The deep-link payload (`section: cleanup`) is read
/// back by `NotificationDelegate` when the user taps the banner.
enum NotificationsService {
    static let cleanupCategoryIdentifier = "MacSense.Cleanup.Schedule"
    static let cleanupSectionPayloadKey = "section"

    /// Asks the system for alert + sound permission once. Subsequent
    /// calls are cheap — the system caches the answer. We don't gate
    /// scheduling on the result; if denied, the Schedule UI shows a
    /// banner with a System Settings shortcut instead of a re-prompt.
    static func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            Logger.shared.log("Notification auth failed: \(error.localizedDescription)", level: .warning)
        }
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Post the post-scan summary. Caller already ran the scan and
    /// computed the recoverable bytes — this only formats + delivers.
    static func postCleanupSummary(totalRecoverable: Int64, categoryCount: Int) async {
        let formatted = ByteCountFormatter.string(fromByteCount: totalRecoverable, countStyle: .file)
        let content = UNMutableNotificationContent()
        content.title = "MacSense scheduled scan"
        if totalRecoverable > 0 {
            content.body = "Found \(formatted) recoverable across \(categoryCount) \(categoryCount == 1 ? "category" : "categories"). Open MacSense to review."
        } else {
            content.body = "No recoverable space found across \(categoryCount) \(categoryCount == 1 ? "category" : "categories")."
        }
        content.sound = .default
        content.userInfo = [cleanupSectionPayloadKey: "cleanup"]

        let req = UNNotificationRequest(
            identifier: "MacSense.Cleanup.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        do {
            try await UNUserNotificationCenter.current().add(req)
        } catch {
            Logger.shared.log("Notification post failed: \(error.localizedDescription)", level: .warning)
        }
    }

    /// Open the macOS notification preferences pane. Used by the
    /// "Notifications are off" banner inside the Schedule section.
    static func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// `UNUserNotificationCenterDelegate` hook so a tap on a posted
/// notification routes the user back into the Cleanup section. We
/// deliberately keep the delegate stateless — it only reads the
/// payload and forwards to a static handler that the app injects on
/// launch.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    /// Invoked when a notification is tapped. The host app sets this
    /// once during bootstrap; we keep it `@MainActor` so writes to
    /// `AppState` don't hop threads on every tap.
    @MainActor static var onCleanupTap: (() -> Void)?

    /// Show banners even when the app is foreground — without this,
    /// the schedule's success-summary silently drops if the user has
    /// MacSense open.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let section = userInfo[NotificationsService.cleanupSectionPayloadKey] as? String
        if section == "cleanup" {
            Task { @MainActor in
                NotificationDelegate.onCleanupTap?()
            }
        }
        completionHandler()
    }
}
