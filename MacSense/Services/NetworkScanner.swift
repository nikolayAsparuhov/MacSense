import Foundation
import Darwin

/// Lightweight LAN scanner. Collects nearby devices via the kernel's
/// ARP table (already populated by normal traffic) plus a quick ping
/// sweep across the local /24 to provoke neighbors that haven't been
/// addressed recently. Yields devices incrementally as they're
/// discovered so the UI can stream results.
///
/// Always pinned first: the current device (this Mac), which is
/// excluded from the sweep itself — its IP is reserved and rendered
/// from local interface info.
actor NetworkScanner {
    static let shared = NetworkScanner()
    private init() {}

    /// Snapshot of this Mac's primary IPv4 + hostname, used as the
    /// pinned first row of the scan list.
    struct LocalInfo {
        let ipAddress: String
        let hostname: String
        let macAddress: String?
        let interface: String?
    }

    /// Open an async stream of discovered devices. The first emitted
    /// item is always the current device. The ping sweep runs in the
    /// background while we poll the ARP table every ~200ms — each
    /// neighbor lands on screen the moment its ARP entry materializes
    /// instead of after the whole /24 finishes.
    func scan() -> AsyncStream<NetworkDevice> {
        AsyncStream { continuation in
            let task = Task.detached { [weak self] in
                guard let self else { continuation.finish(); return }
                let local = Self.currentDevice()
                continuation.yield(NetworkDevice(
                    id: UUID(),
                    ipAddress: local.ipAddress,
                    hostname: local.hostname,
                    macAddress: local.macAddress,
                    interface: local.interface,
                    isCurrentDevice: true
                ))

                guard !local.ipAddress.isEmpty else {
                    continuation.finish()
                    return
                }

                // Ping sweep runs in the background. We do not await it
                // here so the polling loop below can stream devices as
                // they appear in the ARP table. `sweepDoneRef` lets the
                // poll loop know when to stop early.
                final class DoneFlag: @unchecked Sendable {
                    var done = false
                }
                let sweepDone = DoneFlag()
                let sweepTask = Task.detached(priority: .utility) {
                    await Self.pingSweep(localIP: local.ipAddress)
                    sweepDone.done = true
                }

                var seenIPs: Set<String> = [local.ipAddress]

                func emitNew() async {
                    let entries = await self.parseARP()
                    let pending = entries.filter { !seenIPs.contains($0.ipAddress) }
                    guard !pending.isEmpty else { return }
                    for entry in pending { seenIPs.insert(entry.ipAddress) }

                    // Resolve every new entry's reverse-DNS in parallel
                    // (DNS round-trip is the slowest per-device step;
                    // doing them serially blocked the whole stream).
                    // The TaskGroup yields each completed device as
                    // soon as its DNS lookup returns, so the UI sees
                    // them land out-of-order but as fast as possible.
                    await withTaskGroup(of: NetworkDevice.self) { group in
                        for entry in pending {
                            group.addTask {
                                let host = await Self.reverseDNS(ip: entry.ipAddress)
                                return NetworkDevice(
                                    id: UUID(),
                                    ipAddress: entry.ipAddress,
                                    hostname: host?.isEmpty == false ? host : entry.hostname,
                                    macAddress: entry.macAddress,
                                    interface: entry.interface,
                                    isCurrentDevice: false
                                )
                            }
                        }
                        for await device in group {
                            if Task.isCancelled { return }
                            continuation.yield(device)
                            // Light stagger keeps row animations
                            // visually distinct without holding up
                            // the next emission.
                            try? await Task.sleep(nanoseconds: 35_000_000)
                        }
                    }
                }

                // Poll while the sweep runs.
                let deadline = Date().addingTimeInterval(12.0)
                while !Task.isCancelled && Date() < deadline {
                    await emitNew()
                    if sweepDone.done { break }
                    try? await Task.sleep(nanoseconds: 150_000_000)
                }
                _ = await sweepTask.value
                // Final pass to catch any late ARP arrivals.
                if !Task.isCancelled { await emitNew() }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Current device

    static func currentDevice() -> LocalInfo {
        let interfaces = primaryIPv4Interfaces()
        if let primary = interfaces.first {
            return LocalInfo(
                ipAddress: primary.ip,
                hostname: ProcessInfo.processInfo.hostName,
                macAddress: macAddress(forInterface: primary.name),
                interface: primary.name
            )
        }
        return LocalInfo(
            ipAddress: "0.0.0.0",
            hostname: ProcessInfo.processInfo.hostName,
            macAddress: nil,
            interface: nil
        )
    }

    /// Walks `getifaddrs` to find non-loopback IPv4 interfaces. Returns
    /// the most likely "primary" (en0, en1, en…) first.
    private static func primaryIPv4Interfaces() -> [(name: String, ip: String)] {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return [] }
        defer { freeifaddrs(head) }

        var out: [(String, String)] = []
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let cur = ptr {
            let flags = Int32(cur.pointee.ifa_flags)
            let family = cur.pointee.ifa_addr?.pointee.sa_family
            let isUp = (flags & IFF_UP) == IFF_UP
            let isLoop = (flags & IFF_LOOPBACK) == IFF_LOOPBACK
            if isUp, !isLoop, family == UInt8(AF_INET), let addr = cur.pointee.ifa_addr {
                var hostBuf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let size = socklen_t(MemoryLayout<sockaddr_in>.size)
                if getnameinfo(addr, size, &hostBuf, socklen_t(hostBuf.count),
                               nil, 0, NI_NUMERICHOST) == 0 {
                    let ip = String(cString: hostBuf)
                    let name = String(cString: cur.pointee.ifa_name)
                    if !ip.isEmpty, ip != "127.0.0.1" {
                        out.append((name, ip))
                    }
                }
            }
            ptr = cur.pointee.ifa_next
        }
        // Prefer enX (Wi-Fi / wired) over utun / awdl / bridge.
        return out.sorted { lhs, rhs in
            let lhsIsEn = lhs.0.hasPrefix("en")
            let rhsIsEn = rhs.0.hasPrefix("en")
            if lhsIsEn != rhsIsEn { return lhsIsEn }
            return lhs.0 < rhs.0
        }
    }

    private static func macAddress(forInterface name: String) -> String? {
        // `ifconfig <name>` is the simplest cross-version source.
        let output = runReadingStdout("/sbin/ifconfig", [name])
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("ether ") {
                let mac = trimmed.dropFirst("ether ".count)
                    .components(separatedBy: " ").first ?? ""
                return mac.isEmpty ? nil : String(mac)
            }
        }
        return nil
    }

    // MARK: - Ping sweep + ARP parse

    /// Sends one ICMP packet to every host in the /24 of `localIP`.
    /// Used to populate the ARP table before parsing it. Capped
    /// concurrency (64 in flight) avoids spawning 254 simultaneous
    /// `ping` processes, which on small Macs starves the polling /
    /// DNS-resolution tasks. Tight `-W 200` timeout returns missing
    /// hosts quickly so the whole sweep finishes in well under a
    /// second on a typical home subnet.
    private static func pingSweep(localIP: String) async {
        let parts = localIP.split(separator: ".")
        guard parts.count == 4 else { return }
        let prefix = "\(parts[0]).\(parts[1]).\(parts[2])."
        let maxInFlight = 64
        await withTaskGroup(of: Void.self) { group in
            var dispatched = 0
            for host in 1...254 {
                let ip = "\(prefix)\(host)"
                if ip == localIP { continue }
                if dispatched >= maxInFlight {
                    await group.next()
                    dispatched -= 1
                }
                group.addTask {
                    let task = Process()
                    task.executableURL = URL(fileURLWithPath: "/sbin/ping")
                    task.arguments = ["-c", "1", "-W", "200", "-q", ip]
                    task.standardOutput = Pipe()
                    task.standardError = Pipe()
                    do {
                        try task.run()
                        task.waitUntilExit()
                    } catch {
                        // ignored
                    }
                }
                dispatched += 1
            }
        }
    }

    private struct ARPEntry {
        let ipAddress: String
        let hostname: String?
        let macAddress: String
        let interface: String?
    }

    private func parseARP() -> [ARPEntry] {
        let raw = Self.runReadingStdout("/usr/sbin/arp", ["-a"])
        var entries: [ARPEntry] = []
        for line in raw.components(separatedBy: "\n") {
            // Format:
            //   ? (192.168.1.1) at aa:bb:cc:dd:ee:ff on en0 ifscope [ethernet]
            //   host.local (192.168.1.5) at 11:22:33:44:55:66 on en0 ifscope [ethernet]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            guard let ipRange = trimmed.range(of: #"\(([\d\.]+)\)"#, options: .regularExpression) else { continue }
            let ipFull = String(trimmed[ipRange])
            let ip = String(ipFull.dropFirst().dropLast())

            let nameToken = String(trimmed[..<ipRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let hostname = (nameToken == "?" || nameToken.isEmpty) ? nil : nameToken

            guard let atRange = trimmed.range(of: " at ") else { continue }
            let afterAt = trimmed[atRange.upperBound...]
            let mac = afterAt.components(separatedBy: " ").first ?? ""
            if mac == "(incomplete)" { continue }
            guard mac.contains(":") else { continue }

            var iface: String? = nil
            if let onRange = trimmed.range(of: " on ") {
                let afterOn = trimmed[onRange.upperBound...]
                iface = afterOn.components(separatedBy: " ").first.flatMap { $0.isEmpty ? nil : $0 }
            }

            // Drop noise: virtual bridges (Docker / OrbStack / Parallels
            // expose `bridge100..` interfaces with their own ARP tables),
            // VPN / utun / Apple-internal interfaces. Real LAN devices
            // live on en0/en1.
            if let iface, Self.isVirtualInterface(iface) { continue }

            // Drop subnet base + broadcast addresses (.0 / .255 of a /24)
            // — these aren't real hosts. Bridge interfaces also commonly
            // mirror their own gateway/network IP into ARP, so this also
            // helps even if the iface filter misses something.
            if Self.isNetworkOrBroadcastIP(ip) { continue }

            // Drop broadcast + multicast MACs (ff:ff:ff:ff:ff:ff and any
            // address whose first octet has the low bit set, including
            // 01:00:5e:* IPv4 mcast and 33:33:* IPv6 mcast).
            if Self.isBroadcastOrMulticastMAC(mac) { continue }

            entries.append(ARPEntry(
                ipAddress: ip,
                hostname: hostname,
                macAddress: mac,
                interface: iface
            ))
        }
        return entries.sorted { lhs, rhs in
            ipSortKey(lhs.ipAddress) < ipSortKey(rhs.ipAddress)
        }
    }

    private static let virtualInterfacePrefixes: [String] = [
        "bridge", "utun", "awdl", "llw", "anpi", "ap", "lo", "gif",
        "stf", "vmenet", "vboxnet", "vlan", "feth", "ipsec",
    ]

    static func isVirtualInterface(_ name: String) -> Bool {
        let lower = name.lowercased()
        return virtualInterfacePrefixes.contains { lower.hasPrefix($0) }
    }

    /// True for `.0` / `.255` of a typical /24. Doesn't catch every
    /// netmask but covers the common home/office subnets that produce
    /// the bulk of the noise.
    static func isNetworkOrBroadcastIP(_ ip: String) -> Bool {
        let parts = ip.split(separator: ".")
        guard parts.count == 4, let last = UInt8(parts[3]) else { return false }
        return last == 0 || last == 255
    }

    static func isBroadcastOrMulticastMAC(_ mac: String) -> Bool {
        let normalized = mac.lowercased()
        if normalized == "ff:ff:ff:ff:ff:ff" { return true }
        let firstByteHex = normalized.split(separator: ":").first.map(String.init) ?? ""
        guard let firstByte = UInt8(firstByteHex, radix: 16) else { return false }
        // Low bit of the first octet flags multicast (per IEEE 802).
        return (firstByte & 0x01) == 0x01
    }

    private func ipSortKey(_ ip: String) -> UInt32 {
        let parts = ip.split(separator: ".").compactMap { UInt32($0) }
        guard parts.count == 4 else { return 0 }
        return (parts[0] << 24) | (parts[1] << 16) | (parts[2] << 8) | parts[3]
    }

    // MARK: - Reverse DNS

    /// Best-effort reverse DNS via `getnameinfo`. Returns nil on
    /// timeout or when the resolver only echoes the IP back.
    private static func reverseDNS(ip: String) async -> String? {
        await withCheckedContinuation { (cont: CheckedContinuation<String?, Never>) in
            DispatchQueue.global(qos: .utility).async {
                var addr = sockaddr_in()
                addr.sin_family = sa_family_t(AF_INET)
                addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
                if inet_pton(AF_INET, ip, &addr.sin_addr) != 1 {
                    cont.resume(returning: nil); return
                }
                var hostBuf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let result = withUnsafePointer(to: &addr) { ptr -> Int32 in
                    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sap in
                        getnameinfo(sap, socklen_t(MemoryLayout<sockaddr_in>.size),
                                    &hostBuf, socklen_t(hostBuf.count),
                                    nil, 0, NI_NAMEREQD)
                    }
                }
                guard result == 0 else { cont.resume(returning: nil); return }
                let host = String(cString: hostBuf)
                if host == ip || host.isEmpty {
                    cont.resume(returning: nil)
                } else {
                    cont.resume(returning: host)
                }
            }
        }
    }

    // MARK: - Process helper

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
