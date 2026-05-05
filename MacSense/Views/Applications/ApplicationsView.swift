import SwiftUI

struct ApplicationsView: View {
    @EnvironmentObject var appState: AppState
    @State private var subTab: SubTab = .installed

    enum SubTab: String, CaseIterable, Identifiable {
        case installed  = "Installed Apps"
        case loginItems = "Login Items"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
            segmentedControl
                .padding(.horizontal, 28)
                .padding(.top, 22)

            ZStack {
                switch subTab {
                case .installed:
                    InstalledAppsList()
                        .transition(.contentLift)
                case .loginItems:
                    LoginItemsList()
                        .transition(.contentLift)
                }
            }
            .clipped()
            .animation(AppAnimation.sectionTransition, value: subTab)
        }
    }

    private var segmentedControl: some View {
        HStack(spacing: 8) {
            ForEach(SubTab.allCases) { tab in
                Button {
                    withAnimation(AppAnimation.sectionTransition) { subTab = tab }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: tab == .installed ? "square.grid.2x2.fill" : "play.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: .bold))
                    }
                    .padding(.vertical, 9)
                    .padding(.horizontal, 16)
                    .background(
                        Capsule().fill(subTab == tab
                            ? AnyShapeStyle(Theme.sectionGradient(for: .applications))
                            : AnyShapeStyle(Color.white.opacity(0.06)))
                    )
                    .overlay(
                        Capsule().strokeBorder(
                            subTab == tab
                                ? AnyShapeStyle(Color.white.opacity(0.30))
                                : AnyShapeStyle(Color.white.opacity(0.12)),
                            lineWidth: 1
                        )
                    )
                    .foregroundStyle(subTab == tab ? Color.white : Color.white.opacity(0.70))
                    .shadow(color: subTab == tab
                                ? Theme.accent(for: .applications).opacity(0.45)
                                : .clear,
                            radius: 10, y: 4)
                }
                .buttonStyle(.plain)
                .noFocusRing()
            }
            Spacer()
        }
    }
}
