import SwiftUI

/// Two states like CleanupView: hero landing → live monitor grid.
/// User taps "Start" to enter monitoring mode; the section persists the
/// running state across visits while the view exists.
struct PerformanceView: View {
    @EnvironmentObject var appState: AppState
    /// Shared monitor lives on AppState so the sidebar health dot
    /// can read the same rolling window. PerformanceView no longer
    /// owns it — start/stop happens at app level.
    private var monitor: PerformanceMonitor { appState.performanceMonitor }
    @State private var dnsFlushBusy = false
    @State private var activeAlert: ActiveAlert?

    /// Single alert host — SwiftUI only renders one `.alert` per view, so
    /// every dialog this screen needs goes through this enum.
    enum ActiveAlert: Identifiable {
        case dns(String)
        case permission(PermissionPrompt)
        var id: String {
            switch self {
            case .dns(let m): return "dns:\(m)"
            case .permission(let p): return "perm:\(p.id.uuidString)"
            }
        }
    }
    @State private var showNetworkScan = false
    @State private var showWiFiInfo = false
    @State private var showProcessList = false

    /// Carrier for the permissions-required dialog shown when the user
    /// taps an action that needs entitlements MacSense doesn't have yet.
    struct PermissionPrompt: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let primaryActionTitle: String?
        let primaryAction: (() -> Void)?
    }

    var body: some View {
        detailLayout
            // Monitor is started by AppState and runs always so the
            // sidebar health dot reflects live state. No per-view
            // start/stop here.
    }

    // MARK: - Detail (live grid)

    private var detailLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                // Hard-cap at 3 columns — wider windows give each card
                // more breathing room rather than packing in a 4th.
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(minimum: 280),
                                                       spacing: Theme.sectionSpacing),
                                   count: 3),
                    spacing: Theme.sectionSpacing
                ) {
                    cpuTile.cascadeAppear(index: 0, base: 0.05, step: 0.05, cap: 0.5)
                    memoryTile.cascadeAppear(index: 1, base: 0.05, step: 0.05, cap: 0.5)
                    diskTile.cascadeAppear(index: 2, base: 0.05, step: 0.05, cap: 0.5)
                    networkTile.cascadeAppear(index: 3, base: 0.05, step: 0.05, cap: 0.5)
                    batteryTile.cascadeAppear(index: 4, base: 0.05, step: 0.05, cap: 0.5)
                    thermalTile.cascadeAppear(index: 5, base: 0.05, step: 0.05, cap: 0.5)
                }
            }
            .padding(28)
        }
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .dns(let msg):
                return Alert(title: Text("DNS Cache"), message: Text(msg), dismissButton: .default(Text("OK")))
            case .permission(let prompt):
                if let primaryTitle = prompt.primaryActionTitle, let primaryAction = prompt.primaryAction {
                    return Alert(
                        title: Text(prompt.title),
                        message: Text(prompt.message),
                        primaryButton: .default(Text(primaryTitle)) { primaryAction() },
                        secondaryButton: .cancel()
                    )
                }
                return Alert(title: Text(prompt.title), message: Text(prompt.message), dismissButton: .cancel())
            }
        }
    }

    // MARK: - Tiles

    private var cpuTile: some View {
        let tint = Theme.Palette.cyan
        return GlossyCard(accent: Theme.sectionGradient(for: .performance), accentColor: tint) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "cpu").font(.system(size: 18, weight: .medium))
                        .foregroundStyle(tint)
                    Text("CPU").font(.system(size: 14, weight: .semibold))
                    Spacer()
                    livePill
                }
                RollingPercent(
                    value: monitor.sample.cpuUsage,
                    font: .system(size: 24, weight: .bold, design: .rounded),
                    foreground: AnyShapeStyle(tint)
                )
                .animation(AppAnimation.value, value: monitor.sample.cpuUsage)

                Button {
                    showProcessList = true
                } label: {
                    HStack(spacing: 4) {
                        Text("\(monitor.sample.processCount) processes running")
                            .font(.system(size: 11, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(tint)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(tint.opacity(0.12)))
                    .overlay(Capsule().strokeBorder(tint.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .noFocusRing()
                .help("Show running processes")

                ProgressView(value: max(0, min(1, monitor.sample.cpuUsage))).tint(tint).padding(.top, 2)
                    .animation(AppAnimation.value, value: monitor.sample.cpuUsage)
            }
        }
        .sheet(isPresented: $showProcessList) {
            ProcessListSheet()
        }
    }

    private var memoryTile: some View {
        let total = monitor.sample.memoryTotalBytes
        let used = monitor.sample.memoryUsedBytes
        let free = max(0, total - used)
        let tintColor = tint(for: monitor.sample.memoryPressure)
        let pct = monitor.sample.memoryPercent
        let summary = "\(byteString(free)) (\(percentString(pct))) out of \(byteString(total))"
        return usageTile(
            title: "Memory", icon: "memorychip",
            usedBytes: used,
            percent: pct,
            tint: tintColor,
            summary: summary,
            ratesLine: nil
        )
    }

    private var diskTile: some View {
        let total = monitor.sample.diskTotalBytes
        let free = monitor.sample.diskFreeBytes
        let used = max(0, total - free)
        let tintColor: Color = monitor.sample.diskPercent > 0.9 ? Theme.Palette.coral : Theme.Palette.azure
        let pct = monitor.sample.diskPercent
        let summary = "\(byteString(free)) (\(percentString(pct))) out of \(byteString(total))"
        return usageTile(
            title: "Disk", icon: "externaldrive",
            usedBytes: used,
            percent: pct,
            tint: tintColor,
            summary: summary,
            ratesLine: AnyView(diskRatesLine)
        )
    }

    /// Inline "Read X    Write Y" with adequate gap for big values
    /// (e.g. 100k MB/s). Left-aligned, not stretched edge-to-edge.
    private var diskRatesLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 18) {
            HStack(spacing: 4) {
                Text("Read")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                RollingRate(
                    value: Double(monitor.sample.diskReadPerSec),
                    font: .system(size: 12, weight: .semibold, design: .rounded).monospacedDigit(),
                    foreground: AnyShapeStyle(Theme.Palette.azure)
                )
                .animation(AppAnimation.value, value: monitor.sample.diskReadPerSec)
            }
            HStack(spacing: 4) {
                Text("Write")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                RollingRate(
                    value: Double(monitor.sample.diskWritePerSec),
                    font: .system(size: 12, weight: .semibold, design: .rounded).monospacedDigit(),
                    foreground: AnyShapeStyle(Theme.Palette.coral)
                )
                .animation(AppAnimation.value, value: monitor.sample.diskWritePerSec)
            }
            Spacer(minLength: 0)
        }
    }

    /// Shared layout for Memory + Disk tiles. Top row: big used bytes
    /// + small "{pct} used" caption (matches Thermal's "°C ≈ approximate"
    /// pattern). Followed by a single sentence summarizing free / total
    /// and an optional inline rates line below it.
    private func usageTile(title: String, icon: String,
                           usedBytes: Int64, percent: Double, tint: Color,
                           summary: String,
                           ratesLine: AnyView? = nil) -> some View {
        GlossyCard(accent: Theme.sectionGradient(for: .performance), accentColor: tint) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon).font(.system(size: 18, weight: .medium))
                        .foregroundStyle(tint)
                    Text(title).font(.system(size: 14, weight: .semibold))
                    Spacer()
                    livePill
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    RollingByteCount(
                        value: Double(usedBytes),
                        font: .system(size: 28, weight: .bold, design: .rounded),
                        foreground: AnyShapeStyle(tint)
                    )
                    .animation(AppAnimation.value, value: usedBytes)
                    Text("\(percentString(percent)) used")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .animation(AppAnimation.value, value: percent)
                }

                Text(summary)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if let ratesLine { ratesLine }

                ProgressView(value: max(0, min(1, percent))).tint(tint)
                    .animation(AppAnimation.value, value: percent)
            }
        }
    }

    private func byteString(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func rateString(_ bytesPerSec: Int64) -> String {
        if bytesPerSec <= 0 { return "0 B/s" }
        return ByteCountFormatter.string(fromByteCount: bytesPerSec, countStyle: .file) + "/s"
    }

    private var networkTile: some View {
        let local = NetworkScanner.currentDevice()
        return GlossyCard(accent: Theme.sectionGradient(for: .performance), accentColor: Theme.Palette.azure) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "network").font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Theme.Palette.sky)
                    Text("Network").font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Button {
                        showWiFiInfo = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                            Text("Network info")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .foregroundStyle(Theme.Palette.sky)
                        .background(Capsule().fill(Theme.Palette.sky.opacity(0.15)))
                        .overlay(Capsule().strokeBorder(Theme.Palette.sky.opacity(0.45), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .noFocusRing()
                    .help("Open network details")
                    livePill
                }

                // Primary: internal IP, sized to match Disk/Memory's
                // bold headline number.
                Text(local.ipAddress)
                    .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.Palette.sky)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                // Secondary: public IP + MAC address.
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Public")
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .leading)
                        if let publicIP = appState.publicIP {
                            Text(publicIP)
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                        } else if appState.isFetchingPublicIP {
                            ProgressView().controlSize(.mini)
                        } else {
                            Text("—").foregroundStyle(.tertiary)
                        }
                        Spacer(minLength: 0)
                    }
                    if let mac = local.macAddress, !mac.isEmpty {
                        HStack(spacing: 6) {
                            Text("MAC")
                                .foregroundStyle(.secondary)
                                .frame(width: 44, alignment: .leading)
                            Text(mac.uppercased())
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                            if let iface = local.interface {
                                Text("·").foregroundStyle(.tertiary)
                                Text(iface).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
                .font(.system(size: 12, weight: .medium).monospacedDigit())

                // Minor: read/write rates (matches `diskRatesLine`).
                networkRatesLine

                HStack(spacing: 8) {
                    tileActionButton(
                        title: "Scan",
                        icon: "wifi.router",
                        disabled: false,
                        tint: Theme.Palette.sky,
                        style: .primary
                    ) {
                        showNetworkScan = true
                    }

                    tileActionButton(
                        title: dnsFlushBusy ? "Flushing…" : "Flush DNS",
                        icon: "arrow.clockwise.circle",
                        disabled: dnsFlushBusy,
                        tint: Theme.Palette.sky,
                        style: .secondary
                    ) {
                        Task {
                            dnsFlushBusy = true
                            let ok = await appState.flushDNSCache()
                            dnsFlushBusy = false
                            activeAlert = .dns(ok ? "DNS cache flushed." : "DNS flush cancelled or failed.")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showNetworkScan) {
            NetworkScanSheet()
        }
        .sheet(isPresented: $showWiFiInfo) {
            WiFiInfoSheet()
        }
        .onAppear {
            // Refresh on every Performance tab open in case the IP
            // changed (network switch, VPN toggle). AppState dedupes
            // concurrent requests via `isFetchingPublicIP`.
            if appState.publicIP == nil {
                Task { await appState.refreshPublicIP() }
            }
        }
    }

    /// Compact "↓ X    ↑ Y" rates row, mirrors `diskRatesLine` so both
    /// network and disk read/write feel like the same secondary metric.
    private var networkRatesLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 18) {
            HStack(spacing: 4) {
                Text("↓").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                RollingRate(
                    value: Double(monitor.sample.networkRxPerSec),
                    font: .system(size: 12, weight: .semibold, design: .rounded).monospacedDigit(),
                    foreground: AnyShapeStyle(Theme.Palette.sky)
                )
                .animation(AppAnimation.value, value: monitor.sample.networkRxPerSec)
            }
            HStack(spacing: 4) {
                Text("↑").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                RollingRate(
                    value: Double(monitor.sample.networkTxPerSec),
                    font: .system(size: 12, weight: .semibold, design: .rounded).monospacedDigit(),
                    foreground: AnyShapeStyle(Theme.Palette.coral)
                )
                .animation(AppAnimation.value, value: monitor.sample.networkTxPerSec)
            }
            Spacer(minLength: 0)
        }
    }

    private var batteryTile: some View {
        if let level = monitor.sample.batteryLevel {
            let tintColor: Color = level < 0.2 ? Theme.Palette.coral : Theme.Palette.mint
            let timeChunk = batteryTimeLabel()
            let cycleChunk = monitor.sample.batteryCycleCount.map { "\($0) cycles" }
            let labelParts = [timeChunk, monitor.sample.batteryHealth.label, cycleChunk]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
            return AnyView(
                gaugeShell(
                    title: "Battery", icon: batteryIcon(level),
                    label: labelParts.joined(separator: " · "),
                    progress: level, tint: tintColor,
                    bottomAction: {
                        AnyView(
                            tileActionButton(title: "Battery Safe Mode", icon: "leaf", disabled: false, tint: tintColor) {
                                activeAlert = .permission(PermissionPrompt(
                                    title: "Battery Safe Mode",
                                    message: "Battery Safe Mode dims the display, pauses background scans, and reduces fan speed to extend battery life. It needs Accessibility access in System Settings → Privacy & Security so MacSense can adjust display brightness on your behalf.",
                                    primaryActionTitle: "Open System Settings",
                                    primaryAction: {
                                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                            NSWorkspace.shared.open(url)
                                        }
                                    }
                                ))
                            }
                        )
                    }
                ) {
                    RollingPercent(
                        value: level,
                        font: .system(size: 26, weight: .bold, design: .rounded),
                        foreground: AnyShapeStyle(tintColor)
                    )
                    .animation(AppAnimation.value, value: level)
                }
            )
        }
        return AnyView(infoTile(
            title: "Battery", icon: "powerplug", primary: "—",
            secondary: "Desktop or no battery detected", tint: .secondary
        ))
    }

    /// Thermal tile. Shows the SoC's thermal pressure label and an
    /// approximate °C reading derived from the thermal state + CPU load.
    private var thermalTile: some View {
        let state = monitor.sample.thermalState
        let temp = monitor.sample.cpuTemperature
        let tintColor = thermalTint(state)
        return GlossyCard(accent: Theme.sectionGradient(for: .performance), accentColor: tintColor) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "thermometer.medium")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(tintColor)
                    Text("Thermal").font(.system(size: 14, weight: .semibold))
                    Spacer()
                    livePill
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if let t = temp {
                        Text("\(Int(t.rounded()))°C")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(tintColor)
                            .contentTransition(.numericText())
                            .animation(AppAnimation.value, value: temp)
                        Text("≈ approximate")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("—")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                    }
                }
                HStack(spacing: 6) {
                    Text(state.label)
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(tintColor.opacity(0.20)))
                        .overlay(Capsule().strokeBorder(tintColor.opacity(0.55), lineWidth: 1))
                        .foregroundStyle(tintColor)
                }
                Text(thermalHint(state))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Reusable

    private func gaugeShell<V: View>(title: String, icon: String, label: String,
                                     progress: Double, tint: Color,
                                     bottomAction: (() -> AnyView)? = nil,
                                     @ViewBuilder valueLabel: @escaping () -> V) -> some View {
        GlossyCard(accent: Theme.sectionGradient(for: .performance), accentColor: tint) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: icon).font(.system(size: 18, weight: .medium))
                        .foregroundStyle(tint)
                    Text(title).font(.system(size: 14, weight: .semibold))
                    Spacer()
                    livePill
                }
                valueLabel()
                Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                ProgressView(value: max(0, min(1, progress))).tint(tint).padding(.top, 2)
                    .animation(AppAnimation.value, value: progress)
                if let bottomAction { bottomAction() }
            }
        }
    }

    private var livePill: some View {
        Text("LIVE")
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(.green.opacity(0.18)))
            .foregroundStyle(.green)
    }

    private func infoTile(title: String, icon: String, primary: String, secondary: String, tint: Color) -> some View {
        GlossyCard(accent: Theme.sectionGradient(for: .performance), accentColor: tint) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon).font(.system(size: 18, weight: .medium))
                        .foregroundStyle(tint)
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Spacer()
                }
                Text(primary).font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
                Text(secondary).font(.system(size: 10)).foregroundStyle(.secondary)
                    .lineLimit(3).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Compact pill button living at the bottom of a stat tile. Tinted in
    /// the tile's accent color, full-width inside the card. Disabled state
    /// drops opacity + replaces accent stroke with a quiet outline.
    /// `style: .secondary` produces a quieter outline-only variant for
    /// supporting actions placed next to a primary CTA.
    enum TileActionStyle { case primary, secondary }

    private func tileActionButton(title: String, icon: String, disabled: Bool,
                                  tint: Color, style: TileActionStyle = .primary,
                                  action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                Text(title).font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(disabled
                             ? Color.white.opacity(0.45)
                             : (style == .primary ? Color.white : tint))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(disabled
                               ? AnyShapeStyle(Color.white.opacity(0.05))
                               : (style == .primary
                                  ? AnyShapeStyle(LinearGradient(
                                        colors: [tint.opacity(0.45), tint.opacity(0.30)],
                                        startPoint: .top, endPoint: .bottom))
                                  : AnyShapeStyle(Color.white.opacity(0.04))))
            )
            .overlay(Capsule().strokeBorder(disabled
                                            ? .white.opacity(0.10)
                                            : tint.opacity(style == .primary ? 0.6 : 0.45),
                                            lineWidth: 1))
            .shadow(color: disabled || style == .secondary ? .clear : tint.opacity(0.30),
                    radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .noFocusRing()
        .disabled(disabled)
    }

    // MARK: - Helpers

    private func percentString(_ p: Double) -> String { "\(Int((p * 100).rounded()))%" }

    /// Battery time label. When charging shows time-to-full, when on
    /// battery shows time-to-empty. Returns nil if the system is still
    /// calculating (just plugged/unplugged) or running on AC with no
    /// remaining estimate.
    private func batteryTimeLabel() -> String? {
        guard let mins = monitor.sample.batteryTimeMinutes else {
            if monitor.sample.batteryOnAC && !monitor.sample.batteryIsCharging {
                return "On AC"
            }
            return nil
        }
        let h = mins / 60
        let m = mins % 60
        let stamp = h > 0 ? "\(h)h \(m)m" : "\(m)m"
        return monitor.sample.batteryIsCharging ? "\(stamp) to full" : "\(stamp) left"
    }

    private func batteryIcon(_ level: Double) -> String {
        switch level {
        case ..<0.1: return "battery.0"
        case ..<0.3: return "battery.25"
        case ..<0.6: return "battery.50"
        case ..<0.85: return "battery.75"
        default: return "battery.100"
        }
    }

    private func tint(for pressure: MemoryPressure) -> Color {
        switch pressure {
        case .normal:   return Theme.Palette.indigo
        case .warning:  return Theme.Palette.amber
        case .critical: return Theme.Palette.coral
        }
    }

    private func thermalTint(_ state: ProcessInfo.ThermalState) -> Color {
        switch state {
        case .nominal:  return Theme.Palette.mint
        case .fair:     return Theme.Palette.amber
        case .serious, .critical: return Theme.Palette.coral
        @unknown default: return .secondary
        }
    }

    private func thermalHint(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal:  return "Operating normally."
        case .fair:     return "Slight throttling possible."
        case .serious:  return "Macs may throttle CPU/GPU."
        case .critical: return "Heavy throttling — close apps."
        @unknown default: return "—"
        }
    }
}
