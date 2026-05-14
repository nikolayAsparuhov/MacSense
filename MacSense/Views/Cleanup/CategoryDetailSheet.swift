import SwiftUI

/// Inline expansion of a cleanup category card. Shows the file list, lets
/// the user toggle individual items, and runs the clean. Groups items by
/// `subCategory` when present (Developer Caches → Xcode / Brew / Node /
/// Docker). Replaces the previous modal sheet — drives a matchedGeometry
/// morph from the card frame on the grid.
struct ExpandedCategoryCard: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var loc = Localization.shared
    let category: CleaningCategory
    @State private var search = ""
    @State private var hoveredID: UUID?
    /// Sub-category keys whose files are currently expanded. Default
    /// is empty (all groups collapsed) — user clicks a header to
    /// reveal the per-path rows underneath.
    @State private var expandedGroups: Set<String> = []

    private var result: CategoryResult? { appState.categoryResults[category] }

    private func filtered(_ items: [CleanableItem]) -> [CleanableItem] {
        guard !search.isEmpty else { return items }
        let q = search.lowercased()
        return items.filter {
            $0.name.lowercased().contains(q) ||
            $0.path.lowercased().contains(q) ||
            ($0.subCategory?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        GlossyCard(accent: Theme.sectionGradient(for: .cleanup), accentColor: Theme.Palette.cyan) {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .cascadeAppear(delay: 0.05)
                Divider().opacity(0.3).padding(.vertical, 6)
                if let result, !result.items.isEmpty {
                    searchBar
                        .cascadeAppear(delay: 0.08)
                    fileList(items: filtered(result.items))
                        .frame(maxHeight: 420)
                } else {
                    emptyState
                        .cascadeAppear(delay: 0.12)
                }
                Divider().opacity(0.3).padding(.vertical, 6)
                footer
                    .cascadeAppear(delay: 0.18)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: category.icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.Palette.cyan)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(Localization.shared.t(category.titleKey))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(Localization.shared.t(category.subtitleKey))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            if let result {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(result.formattedSize)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(loc.t(.categoryDetailSelectedFormat, appState.selectedCount(in: category), result.itemCount))
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            Button {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                    appState.openedCategory = nil
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
            .noFocusRing()
        }
        .padding(.bottom, 4)
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.6))
            TextField(loc.t(.commonSearchFiles), text: $search)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.white.opacity(0.06)))
        .padding(.bottom, 4)
    }

    // MARK: - File list

    private func fileList(items: [CleanableItem]) -> some View {
        let sorted = items.sorted { $0.size > $1.size }
        let grouped = Dictionary(grouping: sorted, by: { $0.subCategory ?? "" })
        // Sort groups by total bytes descending so heaviest tool
        // surfaces first.
        let groupOrder = grouped.keys.sorted { lhs, rhs in
            (grouped[lhs]?.reduce(0) { $0 + $1.size } ?? 0) >
            (grouped[rhs]?.reduce(0) { $0 + $1.size } ?? 0)
        }

        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(groupOrder.enumerated()), id: \.element) { idx, key in
                    let groupItems = grouped[key] ?? []
                    toolGroupCard(subCategory: key, items: groupItems)
                        .cascadeAppear(index: idx, base: 0.08, step: 0.04, cap: 0.40)
                }
            }
            .padding(.vertical, 8)
        }
    }

    /// One card per dev-tool subcategory. Header shows the tool's
    /// brand-tinted badge + name + total size + chevron. Click the
    /// header to reveal/hide the per-path rows underneath. All
    /// groups start collapsed so the modal opens compact.
    private func toolGroupCard(subCategory: String, items: [CleanableItem]) -> some View {
        let tool = DevCacheCatalog.tool(forSubCategory: subCategory)
        let totalBytes = items.reduce(0) { $0 + $1.size }
        let totalLabel = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        let title = tool?.displayName ?? (subCategory.isEmpty ? Localization.shared.t(.mediaOther) : subCategory)
        let accent = tool?.accent ?? Theme.Palette.cyan
        let isExpanded = expandedGroups.contains(subCategory)

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    if isExpanded {
                        expandedGroups.remove(subCategory)
                    } else {
                        expandedGroups.insert(subCategory)
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    toolBadge(tool: tool, accent: accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                        Text(loc.t(items.count == 1 ? .categoryDetailLocationFormat : .categoryDetailLocationsFormat, items.count))
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer()
                    Text(totalLabel)
                        .font(.system(size: 14, weight: .semibold).monospacedDigit())
                        .foregroundStyle(accent)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(accent.opacity(0.85))
                        .frame(width: 18)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(accent.opacity(isExpanded ? 0.18 : 0.10))
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .noFocusRing()

            if isExpanded {
                VStack(spacing: 4) {
                    ForEach(items) { item in
                        row(item: item)
                    }
                }
                .padding(.top, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.bottom, 4)
    }

    private func toolBadge(tool: DevCacheTool?, accent: Color) -> some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [accent.opacity(0.85), accent.opacity(0.55)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 36, height: 36)
                .shadow(color: accent.opacity(0.4), radius: 4, y: 2)
            if let mark = tool?.textMark {
                Text(mark)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            } else if let symbol = tool?.symbol {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            } else {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }

    private func row(item: CleanableItem) -> some View {
        let isSelected = appState.isItemSelected(item)
        return HStack(alignment: .top, spacing: 12) {
            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { _ in appState.toggleItem(item) }
            ))
            .labelsHidden()
            .toggleStyle(.checkbox)
            .padding(.top, 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let explanation = item.explanation {
                    Text(explanation)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(item.path)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()

            Text(item.formattedSize)
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(hoveredID == item.id ? 0.10 : 0.04))
        )
        .onHover { inside in
            hoveredID = inside ? item.id : (hoveredID == item.id ? nil : hoveredID)
        }
        .animation(.easeInOut(duration: 0.12), value: hoveredID)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 38))
                .foregroundStyle(.green)
            Text(loc.t(.categoryDetailNothingToCleanTitle))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text(loc.t(.categoryDetailNothingToCleanBody))
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding()
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 10) {
            Button(loc.t(.commonSelectAll))  { appState.selectAll(in: category) }
                .buttonStyle(.soft)
            Button(loc.t(.commonDeselectAll)) { appState.deselectAll(in: category) }
                .buttonStyle(.soft)
            Spacer()
            Button(loc.t(.commonRescan)) { appState.scanCategory(category) }
                .buttonStyle(.soft)
            Button {
                appState.clean(category)
                withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                    appState.openedCategory = nil
                }
            } label: {
                Text(loc.t(.categoryDetailCleanFormat, ByteCountFormatter.string(fromByteCount: appState.selectedSize(in: category), countStyle: .file)))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Capsule().fill(Theme.sectionGradient(for: .cleanup)))
            }
            .buttonStyle(.plain)
            .noFocusRing()
            .disabled(appState.selectedCount(in: category) == 0)
        }
        .padding(.top, 4)
    }
}
