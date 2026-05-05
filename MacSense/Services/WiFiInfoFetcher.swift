import Foundation
import CoreWLAN

/// Single-shot fetcher for the Wi-Fi info modal. Queries CoreWLAN for
/// the active interface metrics, shells out to `route` / `scutil` for
/// gateway + DNS, and asks `api.ipify.org` for the public IP. All
/// pieces run in parallel.
actor WiFiInfoFetcher {
    static let shared = WiFiInfoFetcher()
    private init() {}

    func fetch() async -> WiFiInfo {
        async let publicIPTask = Self.fetchPublicIP()
        async let gatewayTask = Self.detached { Self.gatewayIP() }
        async let dnsTask = Self.detached { Self.dnsServers() }

        let local = NetworkScanner.currentDevice()
        let activeIface = local.interface

        // CoreWLAN returns the Wi-Fi interface even on a wired Mac
        // (the radio is present but not associated). We classify the
        // connection by:
        //   - active route's interface == the Wi-Fi adapter name, AND
        //   - the Wi-Fi adapter is powered on
        // SSID is NOT required because macOS 14+ hides SSID/BSSID
        // unless Location Services is granted — relying on it
        // mis-classified Wi-Fi sessions as Ethernet for users who
        // hadn't granted that permission.
        let cwInterface = CWWiFiClient.shared().interface()
        let cwIfaceName = cwInterface?.interfaceName
        let ssid = cwInterface?.ssid()
        let bssid = cwInterface?.bssid()
        let powerOn = cwInterface?.powerOn() ?? false

        let isWiFiActive = (activeIface != nil)
            && (cwIfaceName != nil)
            && (activeIface == cwIfaceName)
            && powerOn

        let connection: WiFiInfo.ConnectionKind
        if isWiFiActive {
            connection = .wifi
        } else if let activeIface, !activeIface.isEmpty {
            connection = .ethernet
        } else {
            connection = .unknown
        }

        // Wi-Fi metrics — only meaningful when we ARE on Wi-Fi.
        let security = isWiFiActive ? cwInterface.flatMap { Self.securityLabel($0.security()) } : nil
        let wifiProtocol = isWiFiActive ? cwInterface.flatMap { Self.phyModeLabel($0.activePHYMode()) } : nil
        let rssi = isWiFiActive ? cwInterface?.rssiValue() : nil
        let noise = isWiFiActive ? cwInterface?.noiseMeasurement() : nil
        let txRate = isWiFiActive ? cwInterface?.transmitRate() : nil
        let channelObj = isWiFiActive ? cwInterface?.wlanChannel() : nil
        let channelNumber = channelObj?.channelNumber
        let bandLabel = channelObj.flatMap { Self.bandLabel($0.channelBand) }
        let widthLabel = channelObj.flatMap { Self.widthLabel($0.channelWidth) }

        // Ethernet link speed via `networksetup -getMedia <iface>`.
        let linkMedia = (connection == .ethernet ? activeIface : nil)
            .flatMap { Self.linkMedia(forInterface: $0) }

        let publicIP = await publicIPTask
        let gateway = await gatewayTask
        let dns = await dnsTask

        return WiFiInfo(
            connection: connection,
            interfaceName: activeIface,
            linkMedia: linkMedia,
            ssid: ssid?.isEmpty == false ? ssid : nil,
            bssid: bssid?.isEmpty == false ? bssid : nil,
            security: security,
            wifiProtocol: wifiProtocol,
            localIP: local.ipAddress.isEmpty ? nil : local.ipAddress,
            gatewayIP: gateway,
            publicIP: publicIP,
            macAddress: local.macAddress,
            dnsServers: dns,
            rssi: rssi,
            noise: noise,
            txRateMbps: txRate,
            channel: channelNumber,
            band: bandLabel,
            width: widthLabel
        )
    }

    /// `networksetup -getMedia <iface>` output:
    ///   Current: 1000baseT <full-duplex>
    ///   Active:  1000baseT <full-duplex>
    /// Returns the "Active:" value when present, otherwise "Current:",
    /// otherwise nil. Strips trailing flag groups in angle brackets.
    private static func linkMedia(forInterface name: String) -> String? {
        let raw = runReadingStdout("/usr/sbin/networksetup", ["-getMedia", name])
        var current: String?
        var active: String?
        for line in raw.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("Active:") {
                active = parseMediaValue(trimmed.dropFirst("Active:".count))
            } else if trimmed.hasPrefix("Current:") {
                current = parseMediaValue(trimmed.dropFirst("Current:".count))
            }
        }
        let value = active ?? current
        if let value, !value.isEmpty, value.lowercased() != "autoselect" {
            return value
        }
        return nil
    }

    private static func parseMediaValue(_ s: Substring) -> String {
        var trimmed = s.trimmingCharacters(in: .whitespaces)
        if let openAngle = trimmed.firstIndex(of: "<") {
            trimmed = String(trimmed[..<openAngle]).trimmingCharacters(in: .whitespaces)
        }
        return trimmed
    }

    // MARK: - CoreWLAN enum mapping

    private static func phyModeLabel(_ mode: CWPHYMode) -> String? {
        // Use raw values so newer macOS SDK additions (Wi-Fi 7 / 11be)
        // don't trigger an exhaustive-switch warning.
        switch mode.rawValue {
        case CWPHYMode.modeNone.rawValue: return nil
        case CWPHYMode.mode11a.rawValue:  return "Wi-Fi (802.11a)"
        case CWPHYMode.mode11b.rawValue:  return "Wi-Fi (802.11b)"
        case CWPHYMode.mode11g.rawValue:  return "Wi-Fi (802.11g)"
        case CWPHYMode.mode11n.rawValue:  return "Wi-Fi 4 (802.11n)"
        case CWPHYMode.mode11ac.rawValue: return "Wi-Fi 5 (802.11ac)"
        case CWPHYMode.mode11ax.rawValue: return "Wi-Fi 6 (802.11ax)"
        case 7:                            return "Wi-Fi 7 (802.11be)"
        default:                           return nil
        }
    }

    private static func securityLabel(_ security: CWSecurity) -> String? {
        switch security.rawValue {
        case CWSecurity.none.rawValue:               return "Open"
        case CWSecurity.WEP.rawValue:                return "WEP"
        case CWSecurity.dynamicWEP.rawValue:         return "Dynamic WEP"
        case CWSecurity.wpaPersonal.rawValue:        return "WPA Personal"
        case CWSecurity.wpaPersonalMixed.rawValue:   return "WPA Personal Mixed"
        case CWSecurity.wpa2Personal.rawValue:       return "WPA2 Personal"
        case CWSecurity.personal.rawValue:           return "Personal"
        case CWSecurity.wpaEnterprise.rawValue:      return "WPA Enterprise"
        case CWSecurity.wpaEnterpriseMixed.rawValue: return "WPA Enterprise Mixed"
        case CWSecurity.wpa2Enterprise.rawValue:     return "WPA2 Enterprise"
        case CWSecurity.enterprise.rawValue:         return "Enterprise"
        case CWSecurity.wpa3Personal.rawValue:       return "WPA3 Personal"
        case CWSecurity.wpa3Enterprise.rawValue:     return "WPA3 Enterprise"
        case CWSecurity.wpa3Transition.rawValue:     return "WPA3 Transition"
        case CWSecurity.OWE.rawValue:                return "OWE"
        case CWSecurity.oweTransition.rawValue:      return "OWE Transition"
        default:                                     return nil
        }
    }

    private static func bandLabel(_ band: CWChannelBand) -> String? {
        switch band {
        case .band2GHz:      return "2.4 GHz"
        case .band5GHz:      return "5 GHz"
        case .band6GHz:      return "6 GHz"
        case .bandUnknown:   return nil
        @unknown default:    return nil
        }
    }

    private static func widthLabel(_ width: CWChannelWidth) -> String? {
        switch width {
        case .width20MHz:    return "20 MHz"
        case .width40MHz:    return "40 MHz"
        case .width80MHz:    return "80 MHz"
        case .width160MHz:   return "160 MHz"
        case .widthUnknown:  return nil
        @unknown default:    return nil
        }
    }

    // MARK: - Shell-derived bits

    /// `route -n get default | grep gateway`
    private static func gatewayIP() -> String? {
        let raw = runReadingStdout("/sbin/route", ["-n", "get", "default"])
        for line in raw.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("gateway:") {
                let value = trimmed.dropFirst("gateway:".count).trimmingCharacters(in: .whitespaces)
                return value.isEmpty ? nil : value
            }
        }
        return nil
    }

    /// Parse `scutil --dns` for the active resolver's nameserver list.
    /// Falls back to `/etc/resolv.conf` if scutil is empty.
    private static func dnsServers() -> [String] {
        var servers: [String] = []
        let raw = runReadingStdout("/usr/sbin/scutil", ["--dns"])
        var inFirstResolver = false
        for line in raw.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("resolver #1") { inFirstResolver = true; continue }
            if trimmed.hasPrefix("resolver #") && !trimmed.hasPrefix("resolver #1") { inFirstResolver = false }
            guard inFirstResolver else { continue }
            if trimmed.hasPrefix("nameserver[") {
                if let colon = trimmed.firstIndex(of: ":") {
                    let value = trimmed[trimmed.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                    if !value.isEmpty, !servers.contains(value) {
                        servers.append(value)
                    }
                }
            }
        }
        if servers.isEmpty {
            if let resolv = try? String(contentsOfFile: "/etc/resolv.conf", encoding: .utf8) {
                for line in resolv.components(separatedBy: "\n") {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("nameserver ") {
                        let value = trimmed.dropFirst("nameserver ".count).trimmingCharacters(in: .whitespaces)
                        if !value.isEmpty { servers.append(String(value)) }
                    }
                }
            }
        }
        return servers
    }

    // MARK: - Public IP

    private static func fetchPublicIP() async -> String? {
        guard let url = URL(string: "https://api.ipify.org") else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = 4
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let text = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
    }

    // MARK: - Helpers

    private static func detached<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
        await Task.detached(priority: .utility) { work() }.value
    }

    private static func runReadingStdout(_ executable: String, _ args: [String]) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}
