import SwiftUI

/// Modal that streams local-network device discovery. Pinned first row
/// is this Mac (excluded from scan); subsequent rows arrive as the
/// scanner emits them.
struct NetworkScanSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var devices: [NetworkDevice] = []
    @State private var isScanning = false
    @State private var scanTask: Task<Void, Never>? = nil

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            list
            Divider()
            footer
        }
        .frame(width: 580, height: 540)
        .background(.regularMaterial)
        .onAppear { startScan() }
        .onDisappear { scanTask?.cancel() }
        .onExitCommand { dismiss() }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.Palette.sky.opacity(0.18))
                    .frame(width: 38, height: 38)
                Image(systemName: "wifi.router")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.Palette.sky)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Network devices")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Text(isScanning
                     ? "Scanning local subnet…"
                     : "\(max(devices.count - 1, 0)) device\(devices.count - 1 == 1 ? "" : "s") found nearby")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isScanning {
                ProgressView().controlSize(.small)
                    .tint(Theme.Palette.sky)
            }

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

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(devices) { device in
                    row(device)
                }
                if isScanning && devices.count <= 1 {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Pinging neighbors…")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func row(_ device: NetworkDevice) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(device.isCurrentDevice
                          ? Theme.Palette.sky.opacity(0.22)
                          : Color.white.opacity(0.05))
                    .frame(width: 34, height: 34)
                Image(systemName: device.isCurrentDevice ? "laptopcomputer" : "desktopcomputer")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(device.isCurrentDevice ? Theme.Palette.sky : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(device.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                    if device.isCurrentDevice {
                        Text("This Mac")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.Palette.sky)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Theme.Palette.sky.opacity(0.18)))
                            .overlay(Capsule().strokeBorder(Theme.Palette.sky.opacity(0.45), lineWidth: 1))
                    }
                }
                Text(device.subtitle)
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
            Spacer()
            Text(device.ipAddress)
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .contextMenu {
            Button("Copy IP") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(device.ipAddress, forType: .string)
            }
            if let mac = device.macAddress, !mac.isEmpty {
                Button("Copy MAC") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(mac, forType: .string)
                }
            }
            if let host = device.hostname {
                Button("Copy Hostname") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(host, forType: .string)
                }
            }
            Button("Copy Row") {
                NSPasteboard.general.clearContents()
                let row = "\(device.displayName)\t\(device.ipAddress)\t\(device.macAddress ?? "")"
                NSPasteboard.general.setString(row, forType: .string)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(device.isCurrentDevice
                      ? Theme.Palette.sky.opacity(0.08)
                      : Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(device.isCurrentDevice
                              ? Theme.Palette.sky.opacity(0.35)
                              : Color.white.opacity(0.05),
                              lineWidth: 1)
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Spacer()
            Button {
                if isScanning {
                    scanTask?.cancel()
                    isScanning = false
                } else {
                    startScan()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isScanning ? "stop.circle" : "arrow.clockwise")
                    Text(isScanning ? "Stop" : "Re-scan")
                }
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 14).padding(.vertical, 7)
            }
            .buttonStyle(.soft)
        }
        .padding(16)
    }

    private func startScan() {
        scanTask?.cancel()
        // Keep current device pinned across re-scans; reset the rest.
        let pinned = devices.first(where: { $0.isCurrentDevice })
        devices = pinned.map { [$0] } ?? []
        isScanning = true
        scanTask = Task {
            for await device in await NetworkScanner.shared.scan() {
                if Task.isCancelled { break }
                await MainActor.run {
                    if device.isCurrentDevice {
                        if let idx = devices.firstIndex(where: { $0.isCurrentDevice }) {
                            devices[idx] = device
                        } else {
                            devices.insert(device, at: 0)
                        }
                    } else {
                        withAnimation(.easeOut(duration: 0.18)) {
                            devices.append(device)
                        }
                    }
                }
            }
            await MainActor.run { isScanning = false }
        }
    }
}
