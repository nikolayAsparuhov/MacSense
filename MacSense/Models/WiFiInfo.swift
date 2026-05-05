import Foundation

/// One-shot snapshot of network state shown in the Network info modal.
/// Works for both Wi-Fi and wired Macs — Wi-Fi-only fields stay nil
/// when the active connection is Ethernet (Mac mini, Mac Pro, iMac).
struct WiFiInfo {
    enum ConnectionKind {
        case wifi
        case ethernet
        case unknown

        var label: String {
            switch self {
            case .wifi:     return "Wi-Fi"
            case .ethernet: return "Ethernet"
            case .unknown:  return "Unknown"
            }
        }
    }

    let connection: ConnectionKind
    let interfaceName: String?
    /// Link speed for wired interfaces (e.g. "1000baseT"). Nil for Wi-Fi
    /// or when `networksetup` couldn't read it.
    let linkMedia: String?

    // Wi-Fi specific (nil on Ethernet-only Macs)
    let ssid: String?
    let bssid: String?
    let security: String?
    let wifiProtocol: String?

    // Network identity (always populated when interface is up)
    let localIP: String?
    let gatewayIP: String?
    let publicIP: String?
    let macAddress: String?
    let dnsServers: [String]

    // Signal — Wi-Fi only
    let rssi: Int?         // dBm
    let noise: Int?        // dBm
    let txRateMbps: Double?
    let channel: Int?
    let band: String?
    let width: String?

    var isWiFi: Bool { connection == .wifi }
}
