import SwiftUI

/// Live process list modal. Refreshes every 2 seconds. Each row shows
/// PID, name, CPU%, memory%, owner. Trash icon sends SIGTERM; on
/// failure (process owned by root, refused) the user can opt in to
/// SIGKILL via the confirm dialog.
struct ProcessListSheet: View {
    enum SortColumn { case pid, name, cpu, memory, user }

    @Environment(\.dismiss) private var dismiss
    @State private var processes: [SystemProcess] = []
    @State private var search = ""
    @State private var hoveredID: pid_t?
    @State private var pendingKill: SystemProcess?
    @State private var killError: String?
    @State private var refreshTimer: Timer?
    @State private var sortColumn: SortColumn = .cpu
    @State private var sortAscending: Bool = false

    private var filtered: [SystemProcess] {
        let base: [SystemProcess]
        if search.isEmpty {
            base = processes
        } else {
            let q = search.lowercased()
            base = processes.filter {
                $0.name.lowercased().contains(q) ||
                $0.fullCommand.lowercased().contains(q) ||
                "\($0.pid)".contains(q)
            }
        }
        return base.sorted { lhs, rhs in
            let result: Bool
            switch sortColumn {
            case .pid:    result = lhs.pid < rhs.pid
            case .name:   result = lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            case .cpu:    result = lhs.cpuPercent < rhs.cpuPercent
            case .memory: result = lhs.memoryBytes < rhs.memoryBytes
            case .user:   result = lhs.user.localizedCaseInsensitiveCompare(rhs.user) == .orderedAscending
            }
            return sortAscending ? result : !result
        }
    }

    private func toggleSort(_ column: SortColumn) {
        if sortColumn == column {
            sortAscending.toggle()
        } else {
            sortColumn = column
            // First click on numeric columns defaults to descending
            // (most CPU/memory first), text columns to ascending.
            sortAscending = (column == .pid || column == .name || column == .user)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            toolbar
            Divider()
            list
            Divider()
            footer
        }
        .frame(width: 760, height: 620)
        .background(.regularMaterial)
        .onAppear {
            refresh()
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                refresh()
            }
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
        .onExitCommand { dismiss() }
        .alert(
            Localization.shared.t(.processQuitTitleFormat, pendingKill?.displayName ?? ""),
            isPresented: Binding(
                get: { pendingKill != nil },
                set: { if !$0 { pendingKill = nil } }
            ),
            presenting: pendingKill
        ) { proc in
            Button(Localization.shared.t(.commonCancel), role: .cancel) { pendingKill = nil }
            Button(Localization.shared.t(.processQuit), role: .destructive) { performKill(proc, force: false) }
            Button(Localization.shared.t(.processForceQuit)) { performKill(proc, force: true) }
        } message: { proc in
            Text(Localization.shared.t(.processQuitDetail, proc.pid, proc.user))
        }
        .alert(Localization.shared.t(.processCantQuitTitle),
               isPresented: Binding(
                   get: { killError != nil },
                   set: { if !$0 { killError = nil } }
               )) {
            Button(Localization.shared.t(.commonOK), role: .cancel) { killError = nil }
        } message: {
            Text(killError ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "cpu")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.Palette.cyan)
            VStack(alignment: .leading, spacing: 2) {
                Text(Localization.shared.t(.processesTitle))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text(Localization.shared.t(.processRunningRefreshFormat, processes.count))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(Localization.shared.t(.performanceLive))
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(.green.opacity(0.18)))
                .foregroundStyle(.green)
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

    private var toolbar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(Localization.shared.t(.processSearchPlaceholder), text: $search)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.quaternary.opacity(0.4)))

            Spacer()

            Text(Localization.shared.t(.processShownFormat, filtered.count))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private var listHeader: some View {
        HStack(spacing: 10) {
            sortHeaderButton("PID", column: .pid, width: 60, alignment: .trailing)
            sortHeaderButton(Localization.shared.t(.processColName), column: .name, width: nil, alignment: .leading)
            sortHeaderButton("CPU%", column: .cpu, width: 60, alignment: .trailing)
            sortHeaderButton(Localization.shared.t(.processColMemory), column: .memory, width: 90, alignment: .trailing)
            sortHeaderButton(Localization.shared.t(.processColUser), column: .user, width: 90, alignment: .leading)
            Spacer().frame(width: 36)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14).padding(.vertical, 6)
        .background(.quaternary.opacity(0.25))
    }

    @ViewBuilder
    private func sortHeaderButton(_ title: String, column: SortColumn,
                                  width: CGFloat?, alignment: Alignment) -> some View {
        let isActive = sortColumn == column
        Button {
            toggleSort(column)
        } label: {
            HStack(spacing: 4) {
                if alignment == .trailing { Spacer(minLength: 0) }
                Text(title)
                    .foregroundStyle(isActive ? Color.primary : .secondary)
                if isActive {
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.primary)
                }
                if alignment == .leading { Spacer(minLength: 0) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .noFocusRing()
        .frame(maxWidth: width ?? .infinity, alignment: alignment)
    }

    private var list: some View {
        VStack(spacing: 0) {
            listHeader
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filtered) { proc in
                        row(proc)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
            }
        }
    }

    private func row(_ proc: SystemProcess) -> some View {
        HStack(spacing: 10) {
            Text("\(proc.pid)")
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)
            Text(proc.displayName)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(proc.fullCommand)
            Text(String(format: "%.1f", proc.cpuPercent))
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(proc.cpuPercent > 50 ? Theme.Palette.coral
                                 : (proc.cpuPercent > 10 ? Theme.Palette.amber : .primary))
                .frame(width: 60, alignment: .trailing)
            Text(ByteCountFormatter.string(fromByteCount: proc.memoryBytes, countStyle: .memory))
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .trailing)
            Text(proc.user)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .frame(width: 90, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)
            Button {
                pendingKill = proc
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red.opacity(0.85))
            }
            .buttonStyle(.borderless)
            .frame(width: 36)
            .help(Localization.shared.t(.helpQuitFormat, proc.displayName))
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(hoveredID == proc.pid ? 0.10 : 0.0))
        )
        .onHover { inside in
            hoveredID = inside ? proc.pid : (hoveredID == proc.pid ? nil : hoveredID)
        }
        .animation(.easeInOut(duration: 0.12), value: hoveredID)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Text(Localization.shared.t(.processSearchHint))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(12)
    }

    // MARK: - Actions

    private func refresh() {
        Task.detached(priority: .userInitiated) {
            let snapshot = ProcessLister.list()
            await MainActor.run {
                self.processes = snapshot
            }
        }
    }

    private func performKill(_ proc: SystemProcess, force: Bool) {
        let ok = force ? ProcessLister.forceKill(proc.pid) : ProcessLister.terminate(proc.pid)
        if !ok {
            let action = Localization.shared.t(force ? .processActionForceQuit : .processActionQuit)
            killError = Localization.shared.t(.processQuitFailedFormat, action, proc.pid, proc.user)
        } else {
            // Optimistically drop from the list — refresh tick will
            // reconcile.
            processes.removeAll { $0.pid == proc.pid }
        }
        pendingKill = nil
    }
}
