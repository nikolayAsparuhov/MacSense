import SwiftUI

/// Inline expansion of an installed-app row. Replaces the previous modal
/// sheet so the close button stays reachable while background sizing
/// streams in, and so the UX matches the cleanup category cards
/// (slide-up panel + dimmed-grid backdrop).
struct ExpandedAppCard: View {
    @EnvironmentObject var appState: AppState
    let app: InstalledApp
    let onClose: () -> Void

    @State private var successCheckScale: CGFloat = 0.4
    @State private var successCheckOpacity: Double = 0
    @State private var successRingScale: CGFloat = 0.6
    @State private var successRingOpacity: Double = 0

    /// Reuses the precomputed size from the discovery phase so the modal
    /// header always matches the list cell. Recomputing it here used to
    /// disagree (e.g. SketchUp 5.9 GB list vs 3.44 GB modal) because the
    /// heuristic finder returns slightly different URL sets across runs
    /// and `recursiveAllocatedSize` is sensitive to which files are
    /// included.
    private var totalSize: Int64 { app.size }

    /// Looks up the cached per-URL size; renders an em-dash placeholder
    /// while the background sizing is still in flight. Never walks disk
    /// from the render path.
    private func rowSizeLabel(for url: URL) -> String {
        if let bytes = appState.appFileSizes[url] {
            return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        }
        return "—"
    }

    /// Sums per-URL sizes from the prefetched map — never walks disk on
    /// the main thread. Until the background sizing finishes, falls back
    /// to the app's full total when everything is selected.
    private var selectedSize: Int64 {
        guard !appState.discoveredFiles.isEmpty else { return 0 }
        if appState.selectedFiles.count == appState.discoveredFiles.count {
            return app.size
        }
        return appState.selectedFiles.reduce(Int64(0)) { acc, url in
            acc + (appState.appFileSizes[url] ?? 0)
        }
    }

    var body: some View {
        ZStack {
            GlossyCard(accent: Theme.sectionGradient(for: .applications),
                       accentColor: Theme.accent(for: .applications)) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .cascadeAppear(delay: 0.05)
                    Divider().opacity(0.3).padding(.vertical, 6)
                    content
                        .frame(maxHeight: 440)
                    Divider().opacity(0.3).padding(.vertical, 6)
                    footer
                        .cascadeAppear(delay: 0.18)
                }
            }

            if appState.deletionSucceededFor == app.id {
                successOverlay
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appState.deletionSucceededFor)
        .onChange(of: appState.deletionSucceededFor) { newValue in
            guard newValue == app.id else { return }
            // Reset before each play in case this card is reused.
            successCheckScale = 0.4
            successCheckOpacity = 0
            successRingScale = 0.6
            successRingOpacity = 0
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
                successCheckScale = 1.0
                successCheckOpacity = 1.0
                successRingScale = 1.0
                successRingOpacity = 1.0
            }
            // Auto-close after the user has had time to register the
            // success — doubled from 1.4s on user feedback.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                onClose()
            }
        }
        .alert(Localization.shared.t(.removalFailedTitle), isPresented: Binding(
            get: { appState.removalError != nil },
            set: { if !$0 { appState.removalError = nil } }
        )) {
            Button(Localization.shared.t(.commonOK), role: .cancel) { appState.removalError = nil }
        } message: {
            Text(appState.removalError ?? "")
        }
    }

    private var successOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(Theme.Palette.mint.opacity(0.6), lineWidth: 3)
                        .frame(width: 96, height: 96)
                        .scaleEffect(successRingScale)
                        .opacity(successRingOpacity)
                    Circle()
                        .fill(LinearGradient(
                            colors: [Theme.Palette.mint, Theme.Palette.cyan],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 80, height: 80)
                        .shadow(color: Theme.Palette.mint.opacity(0.55), radius: 18, x: 0, y: 6)
                        .scaleEffect(successCheckScale)
                        .opacity(successCheckOpacity)
                    Image(systemName: "checkmark")
                        .font(.system(size: 38, weight: .heavy))
                        .foregroundStyle(.white)
                        .scaleEffect(successCheckScale)
                        .opacity(successCheckOpacity)
                }

                Text(Localization.shared.t(.uninstallDeletedFormat, app.appName))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(successCheckOpacity)
                Text(Localization.shared.t(.uninstallFilesMoved))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
                    .opacity(successCheckOpacity)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.appName)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(app.bundleIdentifier)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .help(Localization.shared.t(.helpTotalSize))
                Text(Localization.shared.t(.uninstallSelectedOfFormat, appState.selectedFiles.count, appState.discoveredFiles.count))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
            .noFocusRing()
        }
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var content: some View {
        if appState.isScanningAppFiles {
            VStack(spacing: 8) {
                ProgressView()
                Text(Localization.shared.t(.uninstallScanning))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, minHeight: 200)
        } else if appState.discoveredFiles.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 36))
                    .foregroundStyle(.green)
                Text(Localization.shared.t(.uninstallNoRelated))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, minHeight: 200)
        } else {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(Array(appState.discoveredFiles.enumerated()), id: \.element) { idx, url in
                        fileRow(url)
                            .cascadeAppear(index: idx, base: 0.10, step: 0.022, cap: 0.40)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func fileRow(_ url: URL) -> some View {
        let isSelected = appState.selectedFiles.contains(url)
        return HStack(alignment: .top, spacing: 10) {
            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { selected in
                    if selected { appState.selectedFiles.insert(url) }
                    else { appState.selectedFiles.remove(url) }
                }
            ))
            .labelsHidden()
            .toggleStyle(.checkbox)
            .padding(.top, 4)

            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(url.path)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Text(rowSizeLabel(for: url))
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white.opacity(0.04))
        )
    }

    @ViewBuilder
    private var deletionNoticeBanner: some View {
        if let notice = appState.fileDeletionNotice {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.Palette.mint)
                Text(notice)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.Palette.mint.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Theme.Palette.mint.opacity(0.4), lineWidth: 1)
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
            .animation(.spring(response: 0.4, dampingFraction: 0.8),
                       value: appState.fileDeletionNotice)
            .padding(.bottom, 6)
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            deletionNoticeBanner
            footerActions
        }
    }

    private var footerActions: some View {
        HStack(spacing: 10) {
            Button(Localization.shared.t(.commonSelectAll)) { appState.selectedFiles = Set(appState.discoveredFiles) }
                .buttonStyle(.soft)
            Button(Localization.shared.t(.commonDeselectAll)) { appState.selectedFiles.removeAll() }
                .buttonStyle(.soft)
            Spacer()
            Button {
                appState.removeSelectedFiles()
            } label: {
                Text(Localization.shared.t(.uninstallDeleteFormat, appState.selectedFiles.count, ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file)))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Capsule().fill(LinearGradient(colors: [Theme.Palette.coral, Theme.Palette.violet], startPoint: .leading, endPoint: .trailing)))
                    .shadow(color: Theme.Palette.coral.opacity(0.4), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .noFocusRing()
            .disabled(appState.selectedFiles.isEmpty)
        }
        .padding(.top, 4)
    }
}
