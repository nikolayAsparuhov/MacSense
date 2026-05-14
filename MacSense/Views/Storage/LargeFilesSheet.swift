import SwiftUI

struct LargeFilesSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var typeFilter: MediaType? = nil
    @State private var hoveredID: UUID?

    private var visible: [CleanableItem] {
        guard let report = appState.storageReport else { return [] }
        var list = report.largeFiles
        if let typeFilter {
            list = list.filter { $0.subCategory == typeFilter.label }
        }
        if !search.isEmpty {
            let q = search.lowercased()
            list = list.filter {
                $0.name.lowercased().contains(q) ||
                $0.path.lowercased().contains(q)
            }
        }
        return list
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            filterBar
            Divider()
            list
            Divider()
            footer
        }
        .frame(width: 780, height: 600)
        .background(.regularMaterial)
        .onExitCommand { dismiss() }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "doc.magnifyingglass")
                .font(.system(size: 22))
                .gradientText(Theme.sectionGradient(for: .storage))
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(Localization.shared.t(.largeFilesTitle))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text(Localization.shared.t(.largeFilesTagline))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .noFocusRing()
        }
        .padding(20)
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(Localization.shared.t(.commonSearchFiles), text: $search).textFieldStyle(.plain)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.quaternary.opacity(0.4)))
            .frame(width: 220)

            HStack(spacing: 4) {
                pill("All", selected: typeFilter == nil) { typeFilter = nil }
                ForEach(MediaType.allCases) { t in
                    if let report = appState.storageReport,
                       report.largeFiles.contains(where: { $0.subCategory == t.label }) {
                        pill(t.label, selected: typeFilter == t, color: t.color) { typeFilter = t }
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private func pill(_ label: String, selected: Bool, color: Color = .accentColor, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: selected ? .semibold : .medium))
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(selected ? color.opacity(0.25) : Color.clear))
                .overlay(Capsule().strokeBorder(selected ? color : .secondary.opacity(0.25), lineWidth: 1))
                .foregroundStyle(selected ? Color.primary : Color.secondary)
        }
        .buttonStyle(.plain)
        .noFocusRing()
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(visible) { item in
                    row(item)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
    }

    private func row(_ item: CleanableItem) -> some View {
        let isSel = appState.storageSelectedFiles.contains(item.id)
        let type = MediaType.allCases.first { $0.label == item.subCategory } ?? .other
        return HStack(spacing: 10) {
            Toggle("", isOn: Binding(
                get: { isSel },
                set: { _ in appState.toggleStorageItem(item.id) }
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
                    .lineLimit(1)
                Text(item.path)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()

            if let mod = item.lastModified {
                Text(mod, style: .date)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Text(item.formattedSize)
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(hoveredID == item.id
                      ? AnyShapeStyle(Color.white.opacity(0.10))
                      : AnyShapeStyle(.quaternary.opacity(0.4)))
        )
        .onHover { inside in
            hoveredID = inside ? item.id : (hoveredID == item.id ? nil : hoveredID)
        }
        .animation(.easeInOut(duration: 0.12), value: hoveredID)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button(Localization.shared.t(.commonSelectAll))  { appState.selectAllStorage() }.buttonStyle(.soft)
            Button(Localization.shared.t(.commonDeselectAll)) { appState.deselectAllStorage() }.buttonStyle(.soft)
            Spacer()
            Button {
                appState.trashStorageSelection()
                dismiss()
            } label: {
                Text(Localization.shared.t(.largeFilesMoveFormat, appState.storageSelectedFiles.count, ByteCountFormatter.string(fromByteCount: appState.storageSelectedSize(), countStyle: .file)))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Capsule().fill(Theme.sectionGradient(for: .storage)))
            }
            .buttonStyle(.plain)
            .noFocusRing()
            .disabled(appState.storageSelectedFiles.isEmpty)
        }
        .padding(16)
    }
}
