import SwiftUI

/// Wi-Fi + network details modal. Three grouped sections:
///   1. Connection (security, protocol, country)
///   2. Network (local/gateway/public IP, MAC, BSSID, DNS)
///   3. Signal (RSSI, noise, TX rate, channel, band, width)
struct WiFiInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var info: WiFiInfo? = nil
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let info {
                        section(rows: connectionRows(for: info))
                        section(rows: networkRows(for: info))

                        // Signal section — Wi-Fi only.
                        if info.isWiFi {
                            let loc = Localization.shared
                            section(rows: [
                                (loc.t(.wifiRSSILabel),    info.rssi.map { "\($0) dBm" } ?? "—"),
                                (loc.t(.wifiNoiseLabel),   info.noise.map { "\($0) dBm" } ?? "—"),
                                (loc.t(.wifiTXRate),       info.txRateMbps.map { String(format: "%.1f Mbps", $0) } ?? "—"),
                                (loc.t(.wifiChannelLabel), info.channel.map { "\($0)" } ?? "—"),
                                (loc.t(.wifiBandLabel),    info.band ?? "—"),
                                (loc.t(.wifiWidthLabel),   info.width ?? "—"),
                            ])
                        }

                        if info.isWiFi, info.ssid == nil {
                            Text(Localization.shared.t(.wifiLocationHint))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                    } else if isLoading {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text(Localization.shared.t(.wifiReading))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        Text(Localization.shared.t(.wifiNoInterface))
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 520, height: 620)
        .background(.regularMaterial)
        .task { await load() }
        .onExitCommand { dismiss() }
    }

    private var header: some View {
        let icon: String = {
            switch info?.connection ?? .unknown {
            case .wifi:     return "wifi"
            case .ethernet: return "cable.connector"
            case .unknown:  return "network"
            }
        }()
        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.Palette.sky)

            VStack(alignment: .leading, spacing: 2) {
                Text(Localization.shared.t(.perfNetworkInfo))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                if let ssid = info?.ssid {
                    Text(ssid)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if let iface = info?.interfaceName {
                    let connLabel = info.map { Localization.shared.t($0.connection.labelKey) } ?? ""
                    Text("\(connLabel) · \(iface)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
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

    private func section(rows: [(String, String)]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                HStack(alignment: .top, spacing: 12) {
                    Text(row.0)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(width: 120, alignment: .leading)
                    Text(row.1)
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                        .truncationMode(.middle)
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                if idx < rows.count - 1 {
                    Divider().opacity(0.25)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    private func connectionRows(for info: WiFiInfo) -> [(String, String)] {
        let loc = Localization.shared
        var rows: [(String, String)] = [
            (loc.t(.wifiConnLabel),      loc.t(info.connection.labelKey)),
            (loc.t(.wifiInterfaceLabel), info.interfaceName ?? "—"),
        ]
        if info.connection == .ethernet, let media = info.linkMedia {
            rows.append((loc.t(.wifiLinkSpeed), media))
        }
        if info.isWiFi {
            rows.append((loc.t(.wifiSecurityLabel), info.security ?? "—"))
            rows.append((loc.t(.wifiProtocolLabel), info.wifiProtocol ?? "—"))
        }
        return rows
    }

    private func networkRows(for info: WiFiInfo) -> [(String, String)] {
        let loc = Localization.shared
        var rows: [(String, String)] = [
            (loc.t(.wifiLocalIP),       info.localIP ?? "—"),
            (loc.t(.wifiGatewayIP),     info.gatewayIP ?? "—"),
            (loc.t(.wifiPublicIPLabel), info.publicIP ?? "—"),
            (loc.t(.wifiMACLabel),      info.macAddress ?? "—"),
        ]
        if info.isWiFi {
            rows.append((loc.t(.wifiBSSIDLabel), info.bssid ?? "—"))
        }
        rows.append((loc.t(.wifiDNSLabel), info.dnsServers.isEmpty ? "—" : info.dnsServers.joined(separator: ", ")))
        return rows
    }

    private func load() async {
        isLoading = true
        let fetched = await WiFiInfoFetcher.shared.fetch()
        info = fetched
        isLoading = false
    }
}
