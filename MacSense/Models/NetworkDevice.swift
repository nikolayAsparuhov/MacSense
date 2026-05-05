import Foundation

/// One device on the local network, surfaced by `NetworkScanner`.
struct NetworkDevice: Identifiable, Hashable {
    let id: UUID
    let ipAddress: String
    let hostname: String?
    let macAddress: String?
    let interface: String?
    let isCurrentDevice: Bool

    var displayName: String {
        if let hostname, !hostname.isEmpty { return hostname }
        return ipAddress
    }

    var subtitle: String {
        var parts: [String] = []
        if hostname != nil { parts.append(ipAddress) }
        if let mac = macAddress, !mac.isEmpty { parts.append(mac.uppercased()) }
        if let interface { parts.append(interface) }
        return parts.joined(separator: " · ")
    }
}
