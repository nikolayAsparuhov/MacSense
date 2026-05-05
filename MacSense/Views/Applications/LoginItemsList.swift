import SwiftUI
import ServiceManagement

struct LoginItemsList: View {
    @EnvironmentObject var appState: AppState
    @State private var search = ""
    @State private var pendingDelete: LoginItem?
    @State private var userCollapsed = false
    @State private var systemCollapsed = false
    @State private var hoveredID: LoginItem.ID?

    private enum ScopeGroup: String, CaseIterable {
        case user, system
        var title: String { self == .user ? "User" : "System" }
        var icon: String { self == .user ? "person.crop.circle" : "gearshape.2" }
    }

    private var filtered: [LoginItem] {
        let base: [LoginItem]
        if search.isEmpty {
            base = appState.loginItems
        } else {
            let q = search.lowercased()
            base = appState.loginItems.filter {
                $0.label.lowercased().contains(q) ||
                ($0.appDisplayName?.lowercased().contains(q) ?? false) ||
                ($0.signerName?.lowercased().contains(q) ?? false) ||
                ($0.bundleIdentifier?.lowercased().contains(q) ?? false)
            }
        }
        return base.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private var userItems: [LoginItem] {
        filtered.filter { $0.scope == .userAgent }
    }

    private var systemItems: [LoginItem] {
        filtered.filter { $0.scope == .systemAgent || $0.scope == .systemDaemon }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
                .padding(.horizontal, 28)
                .padding(.top, 6)
                .padding(.bottom, 14)

            if appState.isLoadingLoginItems && appState.loginItems.isEmpty {
                ProgressView("Scanning launch agents and daemons…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appState.loginItems.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .onAppear {
            if appState.loginItems.isEmpty { appState.loadLoginItems() }
        }
        .alert("Login item action failed",
               isPresented: Binding(
                   get: { appState.loginItemError != nil },
                   set: { if !$0 { appState.loginItemError = nil } }
               )) {
            Button("Open System Settings") {
                openSystemSettingsLoginItems()
                appState.loginItemError = nil
            }
            Button("OK", role: .cancel) { appState.loginItemError = nil }
        } message: {
            Text((appState.loginItemError ?? "") + "\n\nMany modern login items are registered via SMAppService and can only be toggled by their parent app or in System Settings → General → Login Items.")
        }
        .alert(
            "Delete \(pendingDelete?.label ?? "")?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { item in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { appState.deleteLoginItem(item) }
        } message: { item in
            if item.isEmbedded {
                Text("Bundled inside \(item.appDisplayName ?? "parent app"). The plist file stays on disk (deleting it would corrupt the app), but the helper will be unloaded and prevented from launching again.")
            } else if item.scope.requiresAdmin {
                Text("This will unload and delete \(item.plistURL.path). Requires admin password.")
            } else {
                Text("This will unload and delete \(item.plistURL.path).")
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search login items", text: $search)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.regularMaterial))

            Spacer()

            Text("\(appState.loginItems.count) items")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Button {
                openSystemSettingsLoginItems()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "gear")
                    Text("System Settings")
                }
            }
            .buttonStyle(.soft)
            .help("macOS restricts toggling some login items registered via SMAppService. Use System Settings to change them.")

            Button { appState.loadLoginItems() } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.soft)
        }
    }

    private func openSystemSettingsLoginItems() {
        if #available(macOS 13.0, *) {
            SMAppService.openSystemSettingsLoginItems()
        } else {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preferences.users")!)
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if !userItems.isEmpty {
                    section(.user, items: userItems, isCollapsed: $userCollapsed)
                }
                if !systemItems.isEmpty {
                    section(.system, items: systemItems, isCollapsed: $systemCollapsed)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
    }

    private func section(_ group: ScopeGroup, items: [LoginItem], isCollapsed: Binding<Bool>) -> some View {
        VStack(spacing: 6) {
            Button {
                isCollapsed.wrappedValue.toggle()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: group.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22)
                    Text(group.title)
                        .font(.system(size: 13, weight: .semibold))
                    Text(items.count == 1 ? "1 item" : "\(items.count) items")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: isCollapsed.wrappedValue ? "chevron.right" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !isCollapsed.wrappedValue {
                VStack(spacing: 6) {
                    ForEach(items) { item in
                        row(item)
                    }
                }
            }
        }
    }

    private func row(_ item: LoginItem) -> some View {
        HStack(spacing: 12) {
            if let icon = item.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 28, height: 28)
            } else {
                Image(systemName: item.categorySymbol)
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(item.scope.label)\(item.isEmbedded ? " · Bundled" : "") · \(item.plistURL.lastPathComponent)")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Text(ByteCountFormatter.string(fromByteCount: item.totalSize, countStyle: .file))
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(.secondary)

            Toggle("", isOn: Binding(
                get: { item.isEnabled },
                set: { newVal in appState.toggleLoginItem(item, enable: newVal) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)

            Button {
                NSWorkspace.shared.selectFile(item.plistURL.path, inFileViewerRootedAtPath: "")
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
            .help("Reveal plist in Finder")

            Button { pendingDelete = item } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .help(item.isEmbedded
                  ? "Bundled inside parent app — disables the helper without deleting the bundle."
                  : "Delete this login item")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(hoveredID == item.id
                      ? AnyShapeStyle(Color.white.opacity(0.08))
                      : AnyShapeStyle(.regularMaterial))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(hoveredID == item.id
                              ? Color.white.opacity(0.18)
                              : Color.white.opacity(0.05),
                              lineWidth: 1)
        )
        .onHover { inside in
            hoveredID = inside ? item.id : (hoveredID == item.id ? nil : hoveredID)
        }
        .animation(.easeInOut(duration: 0.12), value: hoveredID)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "play.slash")
                .font(.system(size: 36))
                .gradientText(Theme.sectionGradient(for: .applications))
            Text("No login items")
                .font(.system(size: 15, weight: .semibold))
            Button("Scan") { appState.loadLoginItems() }
                .buttonStyle(.soft)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
