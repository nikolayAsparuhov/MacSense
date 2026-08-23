import AppKit
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    /// Set by `MacSenseApp` once the SwiftUI scene is alive. The
    /// `BGTaskScheduler` launch handler closes over `self` and reads
    /// this on demand, so the (rare) case where macOS fires the task
    /// before SwiftUI mounts simply falls through to a no-op + re-queue.
    weak var appState: AppState?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false

        #if DEBUG
        UninstallPathValidator.selfCheck()
        #endif

        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared

        // Apple guidance: register every permitted task identifier
        // before launch finishes. The handler reads `appState` at
        // fire time so it doesn't pin a capture to an instance that
        // hasn't been built yet.
        BackgroundScheduler.register { [weak self] task in
            Task { @MainActor in
                guard let app = self?.appState else {
                    task.complete(success: false)
                    return
                }
                await app.runScheduledCleanupScan(task: task)
            }
        }
    }
}

@main
struct MacSenseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @AppStorage("MacSense.OnboardingComplete") private var onboardingComplete: Bool = false

    var body: some Scene {
        WindowGroup {
            Group {
                if onboardingComplete {
                    MainWindow()
                        .environmentObject(appState)
                        .environmentObject(appState.uninstall)
                        .transition(.opacity)
                } else {
                    OnboardingView(isComplete: $onboardingComplete)
                        .transition(.opacity)
                }
            }
            .preferredColorScheme(.dark)
            .animation(.easeInOut(duration: 0.35), value: onboardingComplete)
            .alert(
                Localization.shared.t(.fdaPromptTitle),
                isPresented: $appState.showFDAPrompt
            ) {
                Button(Localization.shared.t(.fdaPromptOpenSettings)) {
                    FullDiskAccessManager.shared.openFullDiskAccessSettings()
                }
                Button(Localization.shared.t(.fdaPromptLater), role: .cancel) {}
            } message: {
                Text(Localization.shared.t(.fdaPromptBody))
            }
            .task {
                appDelegate.appState = appState
                NotificationDelegate.onCleanupTap = { [weak appState] in
                    appState?.selectedSection = .cleanup
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1180, height: 780)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
