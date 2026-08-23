import SwiftUI
import AppKit

/// Folder bubble explorer. Left sidebar lists current folder's
/// children (matches CleanMyMac/DaisyDisk layout); right side renders
/// the bubble map. Both surfaces are clickable for drill-down. The
/// long tail of small siblings is grouped under an "Other items"
/// section that the user expands inline.
struct SizeTabView: View {
    @EnvironmentObject var appState: AppState
    /// True when the "Other items" group in the sidebar is expanded.
    /// Toggled by clicking the "Other items" row OR the synthetic
    /// "Other items" bubble on the right.
    @State private var othersExpanded: Bool = false

    var body: some View {
        VStack(spacing: 14) {
            breadcrumb
            content
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 24)
        .onAppear {
            if appState.sizeNavStack.isEmpty { appState.enterSizeRoot() }
        }
    }

    // MARK: - Breadcrumb

    private var breadcrumb: some View {
        HStack(spacing: 6) {
            HelpIcon(entryID: "storage-graph")

            if appState.sizeNavStack.count > 1 {
                Button {
                    withAnimation(AppAnimation.sectionTransition) {
                        appState.popSizeFolder()
                        othersExpanded = false
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(.white.opacity(0.10)))
                        .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .noFocusRing()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(appState.sizeNavStack.enumerated()), id: \.element.id) { idx, node in
                        Button {
                            withAnimation(AppAnimation.sectionTransition) {
                                appState.popSizeTo(index: idx)
                                othersExpanded = false
                            }
                        } label: {
                            Text(node.name)
                                .font(.system(size: 13, weight: idx == appState.sizeNavStack.count - 1 ? .bold : .medium))
                                .foregroundStyle(idx == appState.sizeNavStack.count - 1 ? Color.white : Color.white.opacity(0.55))
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(
                                    Capsule().fill(idx == appState.sizeNavStack.count - 1
                                                   ? Color.white.opacity(0.10)
                                                   : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                        .noFocusRing()
                        // Repeated folder names are common (a container folder
                        // holding a repo of the same name, node_modules
                        // packages). The full path on hover is what tells the
                        // two apart.
                        .help(node.path)
                        if idx < appState.sizeNavStack.count - 1 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                }
            }
            Spacer()
            if let current = appState.sizeNavStack.last {
                Text(currentSummary(for: current))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private func currentSummary(for node: StorageNode) -> String {
        let formatted = ByteCountFormatter.string(fromByteCount: node.size, countStyle: .file)
        return "\(node.childCount) items · \(formatted)"
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if appState.isScanningStorage && appState.storageGraph == nil {
            loading
        } else if let current = appState.sizeNavStack.last {
            let liveChildren = current.children.filter { !appState.trashedSizeNodeIDs.contains($0.id) }
            let split = bucketSplit(liveChildren)
            if split.kept.isEmpty && split.tail.isEmpty {
                emptyState(path: current.path)
            } else {
                ZStack(alignment: .bottom) {
                    HStack(alignment: .top, spacing: 18) {
                        sidebar(current: current, kept: split.kept, tail: split.tail)
                            .frame(width: 280)
                        BubbleMapView(
                            nodes: split.bubbleNodes,
                            selectedIDs: appState.sizeNavSelection,
                            onTap: { tapped in
                                if tapped.isAggregateOther {
                                    withAnimation(AppAnimation.sectionTransition) {
                                        othersExpanded = true
                                    }
                                    return
                                }
                                withAnimation(AppAnimation.sectionTransition) {
                                    appState.enterSizeFolder(tapped)
                                    othersExpanded = false
                                }
                            },
                            onToggleSelect: { node in
                                appState.toggleSizeNodeSelection(node)
                            }
                        )
                        .overlay(alignment: .topTrailing) {
                            HelpIcon(entryID: "bubble-map")
                                .padding(8)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        // Treat each folder as a distinct view so SwiftUI
                        // runs the configured transition on swap instead of
                        // diffing bubble-by-bubble.
                        .id(current.id)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96)),
                            removal: .opacity.combined(with: .scale(scale: 1.04))
                        ))
                        .animation(.easeInOut(duration: 0.32), value: current.id)
                        // Bubble labels are not meant to be selectable
                        // (would interfere with click-to-drill).
                        .textSelection(.disabled)
                    }

                    if !appState.sizeNavSelection.isEmpty {
                        deleteBar
                            .padding(.bottom, 12)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.85),
                           value: appState.sizeNavSelection.isEmpty)
                .alert(
                    {
                        let count = appState.sizeNavPendingDelete?.count ?? 0
                        return count == 1
                            ? Localization.shared.t(.sizeTabMoveTrashTitleSingular)
                            : Localization.shared.t(.sizeTabMoveTrashTitleFormat, count)
                    }(),
                    isPresented: Binding(
                        get: { appState.sizeNavPendingDelete != nil },
                        set: { if !$0 { appState.cancelTrashSelectedSizeNodes() } }
                    ),
                    presenting: appState.sizeNavPendingDelete
                ) { _ in
                    Button(Localization.shared.t(.commonCancel), role: .cancel) { appState.cancelTrashSelectedSizeNodes() }
                    Button(Localization.shared.t(.commonMoveToTrash), role: .destructive) { appState.confirmTrashSelectedSizeNodes() }
                } message: { items in
                    let total = items.reduce(Int64(0)) { $0 + $1.size }
                    let bytes = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
                    let names = items.prefix(3).map(\.name).joined(separator: ", ")
                    let suffix = items.count > 3 ? Localization.shared.t(.sizeTabMoveTrashMoreFormat, items.count - 3) : ""
                    Text(Localization.shared.t(.sizeTabMoveTrashDetailFormat, names + suffix, bytes))
                }
            }
        } else {
            loading
        }
    }

    private var deleteBar: some View {
        let count = appState.sizeNavSelection.count
        let bytes = appState.sizeNavSelectedBytes()
        return HStack(spacing: 12) {
            Text(Localization.shared.t(.sizeTabSelectedCountFormat, count, ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)

            Button(Localization.shared.t(.commonClear)) { appState.clearSizeNavSelection() }
                .buttonStyle(.soft)
                .controlSize(.small)

            Button {
                appState.requestTrashSelectedSizeNodes()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                    Text(Localization.shared.t(.sizeTabDelete))
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(Capsule().fill(LinearGradient(
                    colors: [Theme.Palette.coral, Theme.Palette.violet],
                    startPoint: .leading, endPoint: .trailing)))
                .shadow(color: Theme.Palette.coral.opacity(0.4), radius: 6, y: 3)
            }
            .buttonStyle(.plain)
            .noFocusRing()
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 18, y: 6)
    }

    // MARK: - Sidebar

    private func sidebar(current: StorageNode, kept: [StorageNode], tail: [StorageNode]) -> some View {
        let totalTailSize = tail.reduce(0) { $0 + $1.size }
        return GlossyCard(accent: Theme.sectionGradient(for: .storage)) {
            VStack(alignment: .leading, spacing: 8) {
                sidebarHeader(node: current)
                Divider().opacity(0.3)
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(Array(kept.enumerated()), id: \.element.id) { idx, node in
                            sidebarRow(node: node)
                                .cascadeAppear(index: idx, base: 0.04, step: 0.03, cap: 0.35)
                        }
                        if !tail.isEmpty {
                            sidebarOthersHeader(count: tail.count, size: totalTailSize)
                                .cascadeAppear(index: kept.count, base: 0.04, step: 0.03, cap: 0.35)
                            if othersExpanded {
                                ForEach(Array(tail.enumerated()), id: \.element.id) { idx, node in
                                    sidebarRow(node: node, indented: true)
                                        .cascadeAppear(index: idx, base: 0.02, step: 0.02, cap: 0.30)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func sidebarHeader(node: StorageNode) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: node.path))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(node.name == "/" ? Localization.shared.t(.bubbleMapMacintoshHD) : node.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(Localization.shared.t(.sizeTabSidebarItemsFormat, ByteCountFormatter.string(fromByteCount: node.size, countStyle: .file), formatItemCount(node.childCount)))
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer(minLength: 0)
        }
    }

    private func sidebarRow(node: StorageNode, indented: Bool = false) -> some View {
        let isSelected = appState.sizeNavSelection.contains(node.id)
        return HStack(spacing: 8) {
            if indented { Spacer().frame(width: 12) }
            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { _ in appState.toggleSizeNodeSelection(node) }
            ))
            .labelsHidden()
            .toggleStyle(.checkbox)
            .controlSize(.mini)

            Button {
                guard !node.isAggregateOther, node.isDirectory else { return }
                withAnimation(AppAnimation.sectionTransition) {
                    appState.enterSizeFolder(node)
                    othersExpanded = false
                }
            } label: {
                HStack(spacing: 8) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: node.path))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .opacity(node.isDirectory ? 1.0 : 0.7)
                    Text(node.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 4)
                    Text(ByteCountFormatter.string(fromByteCount: node.size, countStyle: .file))
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.7))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .noFocusRing()
            .disabled(!node.isDirectory)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Theme.Palette.coral.opacity(0.15) : .white.opacity(0.0))
        )
    }

    private func sidebarOthersHeader(count: Int, size: Int64) -> some View {
        Button {
            withAnimation(AppAnimation.sectionTransition) {
                othersExpanded.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: othersExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 18, alignment: .center)
                Text(Localization.shared.t(.sizeTabOtherItems))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer(minLength: 4)
                Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .noFocusRing()
    }

    private func formatItemCount(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.0fK", Double(count) / 1_000) }
        return "\(count)"
    }

    // MARK: - Loading + empty

    private var loading: some View {
        VStack(spacing: 14) {
            ScanProgressBar(
                progress: nil,
                label: Localization.shared.t(.storageBuildingGraph),
                gradient: Theme.sectionGradient(for: .storage),
                glow: Theme.accent(for: .storage)
            )
            .frame(width: 280)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyState(path: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 32))
                .foregroundStyle(.white.opacity(0.6))
            Text(Localization.shared.t(.sizeTabEmptyMessage))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
            Text(path)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Bucketing

    /// Splits children into:
    ///   - `kept`: surfaced individually (top 8 by rank or ≥4% of parent)
    ///   - `tail`: long tail rolled into the "Other items" group
    ///   - `bubbleNodes`: what the bubble map renders (kept + 1 synthetic Other)
    private func bucketSplit(_ nodes: [StorageNode]) -> (kept: [StorageNode], tail: [StorageNode], bubbleNodes: [StorageNode]) {
        let total = nodes.reduce(0) { $0 + $1.size }
        guard total > 0, nodes.count > 1 else { return (nodes, [], nodes) }

        let threshold = Int64(Double(total) * 0.04)
        let sorted = nodes.sorted { $0.size > $1.size }
        let topByPct = sorted.filter { $0.size >= threshold }
        let topByRank = Array(sorted.prefix(8))
        let kept = topByPct.count >= topByRank.count ? topByPct : topByRank

        let tail = Array(sorted.dropFirst(kept.count))
        let tailSize = tail.reduce(0) { $0 + $1.size }
        var bubbleNodes = kept
        if !tail.isEmpty, tailSize > 0 {
            bubbleNodes.append(StorageNode(
                path: "<other>",
                name: Localization.shared.t(.sizeTabOtherItems),
                size: tailSize,
                isDirectory: false,
                childCount: tail.count,
                children: [],
                isAggregateOther: true
            ))
        }
        return (kept, tail, bubbleNodes)
    }
}
