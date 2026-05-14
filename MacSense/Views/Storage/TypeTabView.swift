import SwiftUI

/// Per-media-type cards. Each card shows the type total and the top 5
/// largest files. Tapping anywhere on the card opens the full file
/// list for that type in a sheet.
struct TypeTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var detailType: MediaType? = nil

    private let columns = [
        GridItem(.adaptive(minimum: 320, maximum: 520), spacing: Theme.sectionSpacing, alignment: .top),
    ]

    var body: some View {
        let isExpanded = detailType != nil
        ZStack {
            ScrollView {
                if let report = appState.storageReport {
                    LazyVGrid(columns: columns, spacing: Theme.sectionSpacing) {
                        ForEach(Array(activeTypes(for: report).enumerated()), id: \.element) { idx, type in
                            TypeCard(
                                type: type,
                                breakdown: report.breakdowns.first { $0.type == type },
                                files: report.filesByType[type] ?? [],
                                onDetails: {
                                    withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                                        detailType = type
                                    }
                                }
                            )
                            .cascadeAppear(index: idx, base: 0.05, step: 0.04, cap: 0.5)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 24)
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

            if let type = detailType {
                ExpandedTypeCard(type: type, onClose: closeExpanded)
                    .environmentObject(appState)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 28)
                    .shadow(color: Theme.accent(for: .storage).opacity(0.35), radius: 30, y: 8)
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
        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: detailType)
        // Sidebar nav also clears the open type so the user can
        // dismiss by clicking anywhere in the app shell.
        .onChange(of: appState.selectedSection) { _ in
            detailType = nil
        }
        // ESC handler — see CleanupView for rationale.
        .background(
            Button("") {
                if detailType != nil { closeExpanded() }
            }
            .keyboardShortcut(.cancelAction)
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        )
    }

    private func closeExpanded() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
            detailType = nil
        }
    }

    private func activeTypes(for report: StorageReport) -> [MediaType] {
        let active = report.breakdowns
            .filter { $0.totalSize > 0 }
            .map(\.type)
        let pinned = active.filter { $0 != .other }
        let other = active.contains(.other) ? [MediaType.other] : []
        return pinned + other
    }
}

// MARK: - Card

private struct TypeCard: View {
    let type: MediaType
    let breakdown: MediaBreakdown?
    let files: [CleanableItem]
    let onDetails: () -> Void

    @State private var isHovering = false
    @ObservedObject private var loc = Localization.shared

    var body: some View {
        // `onTapGesture` instead of an outer Button so the embedded
        // HelpIcon can capture its own taps without SwiftUI's nested
        // hit-testing forwarding them to the parent.
        GlossyCard(accent: LinearGradient(colors: [type.color, type.color.opacity(0.55)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing)) {
            VStack(alignment: .leading, spacing: 12) {
                header
                Divider().opacity(0.25)
                topFiles
                footer
            }
        }
        .scaleEffect(isHovering ? 1.015 : 1.0)
        .shadow(color: type.color.opacity(isHovering ? 0.35 : 0), radius: 18, y: 6)
        .animation(.easeOut(duration: 0.18), value: isHovering)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !files.isEmpty else { return }
            onDetails()
        }
        .onHover { isHovering = $0 }
        .help(files.isEmpty ? "" : Localization.shared.t(.storageOpenDetailsFormat, Localization.shared.t(type.labelKey)))
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(type.color.opacity(0.20))
                    .frame(width: 44, height: 44)
                Image(systemName: type.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(type.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(loc.t(type.labelKey))
                        .font(.system(size: 16, weight: .semibold))
                    HelpIcon(entryID: type.helpEntryID)
                }
                Text(loc.t(.mediaFilesCount, breakdown?.fileCount ?? 0))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            RollingByteCount(
                value: Double(breakdown?.totalSize ?? 0),
                font: .system(size: 18, weight: .bold, design: .rounded),
                foreground: AnyShapeStyle(type.color)
            )
            .animation(AppAnimation.value, value: breakdown?.totalSize ?? 0)
        }
    }

    private var topFiles: some View {
        VStack(spacing: 4) {
            if files.isEmpty {
                Text(loc.t(.mediaTypeNoFiles))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                ForEach(Array(files.prefix(5))) { item in
                    HStack(spacing: 8) {
                        Image(systemName: type.icon)
                            .font(.system(size: 11))
                            .foregroundStyle(type.color.opacity(0.85))
                            .frame(width: 16)
                        Text(item.name)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(item.formattedSize)
                            .font(.system(size: 11, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 3)
                }
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        if files.count > 5 {
            HStack {
                Text(Localization.shared.t(.typeTabMoreFormat, files.count - 5))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(type.color.opacity(isHovering ? 1.0 : 0.55))
            }
        }
    }
}
