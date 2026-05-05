import SwiftUI

/// Master list of installed apps with combined size column. Click row to
/// open the uninstall sheet showing all related files.
struct InstalledAppsList: View {
    @EnvironmentObject var appState: AppState
    @State private var search = ""
    @State private var selection: InstalledApp.ID?
    @State private var hoveredID: InstalledApp.ID?

    /// Show the list only when results exist AND no discovery scan is
    /// running. While scanning we hold the hero (with the loading
    /// animation), matching Cleanup + Storage.
    private var hasDiscovered: Bool {
        !appState.installedApps.isEmpty && !appState.isLoadingApps
    }

    private var filtered: [InstalledApp] {
        let base: [InstalledApp]
        if search.isEmpty {
            base = appState.installedApps
        } else {
            let q = search.lowercased()
            base = appState.installedApps.filter {
                $0.appName.lowercased().contains(q) ||
                $0.bundleIdentifier.lowercased().contains(q)
            }
        }
        // Stable bundle-size order while related-file sizes stream in;
        // re-sort by total once every app is fully sized. Prevents the
        // rows from shuffling under the user's cursor mid-stream.
        if appState.appsSizingComplete {
            return base.sorted { $0.size > $1.size }
        }
        return base.sorted { $0.bundleSize > $1.bundleSize }
    }

    var body: some View {
        let isExpanded = appState.selectedApp != nil
        ZStack {
            Group {
                if hasDiscovered {
                    listLayout.transition(.contentLift)
                } else {
                    heroLayout.transition(.contentLift)
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
        .animation(AppAnimation.sectionTransition, value: hasDiscovered)
        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: appState.selectedApp)
        // ESC handler — see CleanupView for rationale.
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

    // MARK: - Hero

    private var heroLayout: some View {
        HeroLanding(
            title: "Installed Apps",
            tagline: "Discover every app on your Mac with combined size — bundle plus caches, prefs, containers. One-click uninstall removes the lot.",
            secondaryActionTitle: nil, secondaryAction: nil,
            ctaTitle: "Discover",
            ctaIcon: nil,
            ctaGradient: Theme.sectionGradient(for: .applications),
            ctaGlow: Theme.accent(for: .applications),
            ctaDisabled: false,
            ctaAction: {
                if appState.installedApps.isEmpty { appState.loadInstalledApps() }
            },
            isScanning: appState.isLoadingApps,
            scanProgress: nil,
            scanLabel: "Discovering apps…"
        ) {
            Hero3DIcon.forSection(.applications, size: 220)
                .frame(height: 320)
        }
    }

    // MARK: - List

    private var listLayout: some View {
        VStack(spacing: 0) {
            toolbar
                .padding(.horizontal, 28)
                .padding(.top, 6)
                .padding(.bottom, 14)

            if appState.isLoadingApps && appState.installedApps.isEmpty {
                ProgressView("Discovering apps…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appState.installedApps.isEmpty {
                emptyState
            } else {
                list
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search apps", text: $search)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.regularMaterial))

            Spacer()

            Text("\(appState.installedApps.count) apps")
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

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, app in
                    appRow(app)
                        .cascadeAppear(index: idx, base: 0.0, step: 0.018, cap: 0.35)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
    }

    private func appRow(_ app: InstalledApp) -> some View {
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
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                    Text(app.bundleIdentifier)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                if app.isSizeFullyKnown {
                    Text(app.formattedSize)
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.mini)
                        Text(ByteCountFormatter.string(fromByteCount: app.bundleSize, countStyle: .file))
                            .font(.system(size: 13, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(hoveredID == app.id
                          ? AnyShapeStyle(Color.white.opacity(0.08))
                          : AnyShapeStyle(.regularMaterial))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(hoveredID == app.id
                                  ? Color.white.opacity(0.18)
                                  : Color.white.opacity(0.05),
                                  lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .noFocusRing()
        .onHover { inside in
            hoveredID = inside ? app.id : (hoveredID == app.id ? nil : hoveredID)
        }
        .animation(.easeInOut(duration: 0.12), value: hoveredID)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 36))
                .gradientText(Theme.sectionGradient(for: .applications))
            Text("No apps found")
                .font(.system(size: 15, weight: .semibold))
            Button("Refresh") { appState.loadInstalledApps() }
                .buttonStyle(.soft)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
