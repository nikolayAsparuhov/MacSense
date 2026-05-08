import SwiftUI

struct MainWindow: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        // Wrap in a child view that observes the help controller
        // directly so its `isDrawerOpen` flips trigger a re-render
        // here. AppState owns the controller as a `let`, so its
        // own `objectWillChange` doesn't fire on those updates.
        MainWindowContent(help: appState.help)
    }
}

private struct MainWindowContent: View {
    @ObservedObject var help: HelpController
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                Sidebar()
                    .frame(width: 220)

                Divider()
                    .ignoresSafeArea()

                detailPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if help.isDrawerOpen {
                HelpDrawer(controller: help)
                    .zIndex(100)
            }
        }
        .frame(minWidth: 980, minHeight: 640)
        .animation(.spring(response: 0.4, dampingFraction: 0.86), value: help.isDrawerOpen)
    }

    @ViewBuilder
    private var detailPane: some View {
        ZStack {
            // Section-tinted radial backdrop fills the whole window. The
            // backdrop itself crossfades when the user switches sections,
            // giving the CleanMyMac signature "the room glows in the
            // section's color" effect.
            SectionBackdrop(section: appState.selectedSection)
                .id("bg-\(appState.selectedSection.rawValue)")
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.45), value: appState.selectedSection)

            ZStack {
                Group {
                    switch appState.selectedSection {
                    case .cleanup:      CleanupView()
                    case .performance:  PerformanceView()
                    case .applications: ApplicationsView()
                    case .storage:      StorageView()
                    }
                }
                .id(appState.selectedSection)
                .transition(.sectionSwap)
            }
            .clipped()
            .animation(AppAnimation.sectionTransition, value: appState.selectedSection)
            // Enable text selection across all detail panes so the
            // user can copy IPs, file paths, app names, sizes, etc.
            // The bubble map disables it locally on top of this.
            // Sidebar is outside this branch so it remains untouched.
            .textSelection(.enabled)
        }
    }
}
