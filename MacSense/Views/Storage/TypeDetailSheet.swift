import SwiftUI

/// Inline expansion of a media-type card. Replaces the modal sheet so
/// the close button stays reachable and the UX matches the cleanup
/// category cards (slide-up panel + dimmed-grid backdrop).
struct ExpandedTypeCard: View {
    let type: MediaType
    let onClose: () -> Void
    @EnvironmentObject var appState: AppState
    @State private var search = ""
    @State private var selected: Set<UUID> = []
    @State private var hoveredID: UUID?

    private var files: [CleanableItem] {
        appState.storageReport?.filesByType[type] ?? []
    }

    private var visible: [CleanableItem] {
        guard !search.isEmpty else { return files }
        let q = search.lowercased()
        return files.filter {
            $0.name.lowercased().contains(q) ||
            $0.path.lowercased().contains(q)
        }
    }

    private var selectedItems: [CleanableItem] {
        files.filter { selected.contains($0.id) }
    }

    private var selectedSize: Int64 {
        selectedItems.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        GlossyCard(accent: Theme.sectionGradient(for: .storage),
                   accentColor: Theme.accent(for: .storage)) {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .cascadeAppear(delay: 0.05)
                Divider().opacity(0.3).padding(.vertical, 6)
                filterBar
                    .cascadeAppear(delay: 0.10)
                list
                    .frame(maxHeight: 380)
                Divider().opacity(0.3).padding(.vertical, 6)
                footer
                    .cascadeAppear(delay: 0.18)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: type.icon)
                .font(.system(size: 22))
                .foregroundStyle(type.color)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(type.label)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(files.count) files · \(ByteCountFormatter.string(fromByteCount: files.reduce(0) { $0 + $1.size }, countStyle: .file))")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

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

    private var filterBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.6))
                TextField("Search files", text: $search)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.white.opacity(0.06)))
            .frame(width: 240)
            Spacer()
            Text("Top 200 by size")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.vertical, 4)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(Array(visible.enumerated()), id: \.element.id) { idx, item in
                    row(item)
                        .cascadeAppear(index: idx, base: 0.10, step: 0.022, cap: 0.40)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func row(_ item: CleanableItem) -> some View {
        let isSel = selected.contains(item.id)
        return HStack(spacing: 10) {
            Toggle("", isOn: Binding(
                get: { isSel },
                set: { _ in
                    if isSel { selected.remove(item.id) } else { selected.insert(item.id) }
                }
            ))
            .labelsHidden()
            .toggleStyle(.checkbox)

            Image(systemName: type.icon)
                .font(.system(size: 16))
                .foregroundStyle(type.color)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(item.path)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()

            if let mod = item.lastModified {
                Text(mod, style: .date)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6))
            }
            Text(item.formattedSize)
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(hoveredID == item.id ? 0.10 : 0.04))
        )
        .onHover { inside in
            hoveredID = inside ? item.id : (hoveredID == item.id ? nil : hoveredID)
        }
        .animation(.easeInOut(duration: 0.12), value: hoveredID)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button("Select all")  { selected = Set(visible.map(\.id)) }.buttonStyle(.soft)
            Button("Deselect all") { selected.removeAll() }.buttonStyle(.soft)
            Spacer()
            Button {
                appState.trashStorageItems(selectedItems)
                onClose()
            } label: {
                Text("Move \(selected.count) to Trash (\(ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file)))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Capsule().fill(Theme.sectionGradient(for: .storage)))
            }
            .buttonStyle(.plain)
            .noFocusRing()
            .disabled(selected.isEmpty)
        }
        .padding(.top, 4)
    }
}
