import SwiftUI

/// "Unused" tab — surfaces installed apps the user hasn't opened in a
/// while so they can free up disk space. Apps are bucketed by their
/// Spotlight `kMDItemLastUsedDate`:
///   - "Unused for ≥ X days" — sorted oldest first
///   - "Never opened" — apps with no last-used metadata
///
/// Threshold is user-configurable via `UnusedThreshold` and persists
/// across launches. Tapping a row reuses the existing uninstall flow
/// driven by `appState.selectedApp`.
struct UnusedAppsList: View {
    @EnvironmentObject var appState: AppState
    @State private var threshold: UnusedThreshold = UnusedThreshold.current

    private var staleApps: [InstalledApp] {
        let cutoff = Date().addingTimeInterval(-threshold.seconds)
        return appState.installedApps
            .filter { app in
                guard let last = app.lastUsedDate else { return false }
                return last < cutoff
            }
            .sorted { ($0.lastUsedDate ?? .distantPast) < ($1.lastUsedDate ?? .distantPast) }
    }

    private var neverOpenedApps: [InstalledApp] {
        appState.installedApps
            .filter { $0.lastUsedDate == nil }
            .sorted { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }
    }

    private var hasAny: Bool { !staleApps.isEmpty || !neverOpenedApps.isEmpty }

    var body: some View {
        let isExpanded = appState.selectedApp != nil
        ZStack {
            Group {
                if appState.installedApps.isEmpty && appState.isLoadingApps {
                    ProgressView("Discovering apps…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    content.transition(.contentLift)
                }
            }
            .scaleEffect(isExpanded ? 0.96 : 1.0, anchor: .center)
            .blur(radius: isExpanded ? 14 : 0)
            .opacity(isExpanded ? 0.35 : 1.0)
            .allowsHitTesting(!isExpanded)

            if isExpanded {
                Rectangle()
                    .fill(.black.opacity(0.45))
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { closeExpanded() }
                    .transition(.opacity)
            }

            if let app = appState.selectedApp {
                ExpandedAppCard(app: app, onClose: closeExpanded)
                    .environmentObject(appState)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 28)
                    .shadow(color: Theme.accent(for: .applications).opacity(0.35), radius: 30, y: 8)
                    .shadow(color: .black.opacity(0.55), radius: 40, y: 18)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom)
                            .combined(with: .opacity)
                            .combined(with: .scale(scale: 0.92, anchor: .bottom)),
                        removal: .move(edge: .bottom)
                            .combined(with: .opacity)
                            .combined(with: .scale(scale: 0.94, anchor: .bottom))
                    ))
                    .zIndex(2)
            }
        }
        .clipped()
        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: appState.selectedApp)
        .onAppear {
            if appState.installedApps.isEmpty && !appState.isLoadingApps {
                appState.loadInstalledApps()
            }
        }
        .background(
            Button("") {
                if appState.selectedApp != nil { closeExpanded() }
            }
            .keyboardShortcut(.cancelAction)
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        )
    }

    private func closeExpanded() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
            appState.selectedApp = nil
        }
        appState.discoveredFiles = []
        appState.selectedFiles = []
        appState.deletionSucceededFor = nil
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            toolbar
                .padding(.horizontal, 28)
                .padding(.top, 6)
                .padding(.bottom, 14)

            if hasAny {
                list
            } else {
                emptyHero
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                ForEach(UnusedThreshold.allCases) { value in
                    let isActive = value == threshold
                    Button {
                        threshold = value
                        UnusedThreshold.current = value
                    } label: {
                        Text(value.label)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(isActive ? .white : .white.opacity(0.7))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(
                                Capsule().fill(isActive
                                               ? AnyShapeStyle(Theme.sectionGradient(for: .applications))
                                               : AnyShapeStyle(Color.white.opacity(0.06)))
                            )
                            .overlay(Capsule().strokeBorder(.white.opacity(isActive ? 0.0 : 0.15), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .noFocusRing()
                }
            }

            HelpIcon(entryID: "last-used-date")

            Spacer()

            Text("\(staleApps.count) stale · \(neverOpenedApps.count) never opened")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Button {
                appState.loadInstalledApps()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.soft)
            .help("Refresh")
        }
    }

    // MARK: - List

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                if !staleApps.isEmpty {
                    sectionHeader("Unused for ≥ \(threshold.rawValue) days")
                    ForEach(Array(staleApps.enumerated()), id: \.element.id) { idx, app in
                        appRow(app, isNeverOpened: false)
                            .cascadeAppear(index: idx, base: 0.0, step: 0.018, cap: 0.35)
                    }
                }
                if !neverOpenedApps.isEmpty {
                    sectionHeader("Never opened")
                        .padding(.top, staleApps.isEmpty ? 0 : 12)
                    ForEach(Array(neverOpenedApps.enumerated()), id: \.element.id) { idx, app in
                        appRow(app, isNeverOpened: true)
                            .cascadeAppear(index: idx, base: 0.0, step: 0.018, cap: 0.35)
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white.opacity(0.55))
            .textCase(.uppercase)
            .padding(.vertical, 6)
    }

    private func appRow(_ app: InstalledApp, isNeverOpened: Bool) -> some View {
        Button {
            appState.scanForAppFiles(app)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                appState.selectedApp = app
            }
        } label: {
            HStack(spacing: 12) {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.appName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(app.bundleIdentifier)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                pill(for: app, isNeverOpened: isNeverOpened)
                Text(app.formattedSize)
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(minWidth: 80, alignment: .trailing)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .noFocusRing()
    }

    @ViewBuilder
    private func pill(for app: InstalledApp, isNeverOpened: Bool) -> some View {
        if isNeverOpened {
            Text("Never opened")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.Palette.amber)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(Theme.Palette.amber.opacity(0.14)))
                .overlay(Capsule().strokeBorder(Theme.Palette.amber.opacity(0.4), lineWidth: 1))
        } else if let last = app.lastUsedDate {
            Text(relativeLabel(for: last))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(Color.white.opacity(0.06)))
                .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 1))
        }
    }

    private func relativeLabel(for date: Date) -> String {
        let days = Int(Date().timeIntervalSince(date) / 86_400)
        return "\(days)d ago"
    }

    // MARK: - Empty hero

    private var emptyHero: some View {
        VStack(spacing: 16) {
            Hero3DIcon.forSection(.applications, size: 140)
            Text("Nothing stale — nicely curated.")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
            Text("Every app on this Mac was opened within the last \(threshold.rawValue) days.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
