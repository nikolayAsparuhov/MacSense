import Foundation
import Darwin
import IOKit
import IOKit.ps

/// Live system metrics. Public APIs only — no SMC, no powermetrics shell-out
/// (those require root or signing entitlements that fail on direct DMG).
/// What's NOT here: GPU utilization (no public macOS API), per-sensor
/// temperatures, fan RPM. Phase 5+ can wire SMC if needed.
///
/// Samples on a 1Hz timer; published values are smoothed for the network
/// gauge so it doesn't flicker between zero and bursty highs.
@MainActor
final class PerformanceMonitor: ObservableObject {
    @Published var sample = PerformanceSample()
    @Published var isRunning = false
    /// Rolling 5-second window of CPU%, Memory%, and approximate
    /// CPU temperature. Drives the sidebar health dot.
    @Published var healthStatus: HealthStatus = .unknown

    enum HealthStatus { case unknown, green, yellow, red }

    private var timer: Timer?
    private var prevCPUTicks: (user: UInt64, sys: UInt64, idle: UInt64, nice: UInt64) = (0, 0, 0, 0)
    private var prevNet: (rx: UInt64, tx: UInt64, time: TimeInterval) = (0, 0, 0)
    private var prevDisk: (read: UInt64, write: UInt64, time: TimeInterval) = (0, 0, 0)
    /// Last 5 samples (1 sec apart). Used to qualify the health
    /// status — a single transient spike doesn't flip the dot;
    /// pressure must hold for the full window.
    private var window: [PerformanceSample] = []
    private static let windowSize = 5

    func start() {
        guard !isRunning else { return }
        isRunning = true
        // Prime baselines so the first emitted value isn't garbage.
        _ = readCPUTicks()
        _ = readNetworkBytes()
        _ = readDiskIOBytes()
        let now = Date().timeIntervalSince1970
        prevNet.time = now
        prevDisk.time = now
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        // Fire once immediately for snappy first-frame.
        Task { @MainActor in poll() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    private func poll() {
        var s = PerformanceSample()
        s.cpuUsage = computeCPUUsage()
        s.processCount = readProcessCount()
        let mem = readMemory()
        s.memoryUsedBytes = mem.used
        s.memoryTotalBytes = mem.total
        s.memoryPressure = mem.pressure
        let disk = readDisk()
        s.diskFreeBytes = disk.free
        s.diskTotalBytes = disk.total
        let net = computeNetworkRates()
        s.networkRxPerSec = net.rx
        s.networkTxPerSec = net.tx
        let dio = computeDiskIORates()
        s.diskReadPerSec = dio.read
        s.diskWritePerSec = dio.write
        let battery = readBattery()
        s.batteryLevel = battery.level
        s.batteryHealth = battery.health
        s.batteryCycleCount = battery.cycles
        s.batteryTimeMinutes = battery.timeMinutes
        s.batteryIsCharging = battery.isCharging
        s.batteryOnAC = battery.onAC
        s.thermalState = ProcessInfo.processInfo.thermalState
        s.cpuTemperature = approximateCPUTemperature(state: s.thermalState, load: s.cpuUsage)
        sample = s

        // Slide the window + recompute health status.
        window.append(s)
        if window.count > Self.windowSize { window.removeFirst(window.count - Self.windowSize) }
        healthStatus = computeHealthStatus()
    }

    /// Health classification — pressure must be sustained across the
    /// full 5-second window. A single transient spike doesn't flip the
    /// dot; the condition has to hold every sample.
    ///
    ///   red    — every sample in the last 5s has CPU≥90% OR Mem≥90% OR temp≥90°C
    ///   yellow — every sample in the last 5s has CPU≥70% OR Mem≥70% OR temp≥80°C
    ///   green  — otherwise (at least one sample dropped below the yellow band)
    private func computeHealthStatus() -> HealthStatus {
        guard window.count >= Self.windowSize else { return .unknown }
        let allRed = window.allSatisfy { s in
            let cpu = s.cpuUsage * 100
            let mem = s.memoryPercent * 100
            let temp = s.cpuTemperature ?? 0
            return cpu >= 90 || mem >= 90 || temp >= 90
        }
        if allRed { return .red }
        let allYellowOrWorse = window.allSatisfy { s in
            let cpu = s.cpuUsage * 100
            let mem = s.memoryPercent * 100
            let temp = s.cpuTemperature ?? 0
            return cpu >= 70 || mem >= 70 || temp >= 80
        }
        if allYellowOrWorse { return .yellow }
        return .green
    }

    /// Public macOS exposes thermal pressure as a categorical state but
    /// **not** an actual temperature in degrees — that requires SMC or
    /// IOHID private API which we don't ship without admin entitlements.
    /// As a best-effort surrogate we map the thermal state to a band and
    /// pick a value within that band based on current CPU load. Marked
    /// `approximate` in the UI so users know it's not a sensor read.
    /// Count running processes via `sysctl(CTL_KERN, KERN_PROC,
    /// KERN_PROC_ALL)` — returns the size of the proc table; divide
    /// by `kinfo_proc` size for the count. Cheap (<1ms).
    private func readProcessCount() -> Int {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL]
        var size: size_t = 0
        let nameLen = u_int(mib.count)
        let result = mib.withUnsafeMutableBufferPointer { bp -> Int32 in
            sysctl(bp.baseAddress, nameLen, nil, &size, nil, 0)
        }
        guard result == 0, size > 0 else { return 0 }
        return size / MemoryLayout<kinfo_proc>.stride
    }

    private func approximateCPUTemperature(state: ProcessInfo.ThermalState, load: Double) -> Double {
        let (low, high): (Double, Double)
        switch state {
        case .nominal:  (low, high) = (38, 58)
        case .fair:     (low, high) = (60, 75)
        case .serious:  (low, high) = (78, 90)
        case .critical: (low, high) = (92, 102)
        @unknown default: (low, high) = (45, 55)
        }
        let clamped = max(0.0, min(1.0, load))
        return low + (high - low) * clamped
    }

    // MARK: - CPU (host_processor_info)

    private func readCPUTicks() -> (user: UInt64, sys: UInt64, idle: UInt64, nice: UInt64) {
        var count = mach_msg_type_number_t(0)
        var infoArrayPtr: processor_info_array_t? = nil
        var processorCount = natural_t(0)
        let result = host_processor_info(
            mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
            &processorCount, &infoArrayPtr, &count
        )
        guard result == KERN_SUCCESS, let infoArray = infoArrayPtr else {
            return (0, 0, 0, 0)
        }
        defer {
            vm_deallocate(mach_task_self_,
                          vm_address_t(bitPattern: infoArray),
                          vm_size_t(count) * vm_size_t(MemoryLayout<integer_t>.size))
        }
        var u: UInt64 = 0, sy: UInt64 = 0, i: UInt64 = 0, n: UInt64 = 0
        let cpuLoadInfoCount = Int(CPU_STATE_MAX)
        for index in 0..<Int(processorCount) {
            let base = index * cpuLoadInfoCount
            u  += UInt64(infoArray[base + Int(CPU_STATE_USER)])
            sy += UInt64(infoArray[base + Int(CPU_STATE_SYSTEM)])
            i  += UInt64(infoArray[base + Int(CPU_STATE_IDLE)])
            n  += UInt64(infoArray[base + Int(CPU_STATE_NICE)])
        }
        return (u, sy, i, n)
    }

    private func computeCPUUsage() -> Double {
        let cur = readCPUTicks()
        defer { prevCPUTicks = cur }
        let prev = prevCPUTicks
        let userDiff = Int64(cur.user) - Int64(prev.user)
        let sysDiff  = Int64(cur.sys)  - Int64(prev.sys)
        let idleDiff = Int64(cur.idle) - Int64(prev.idle)
        let niceDiff = Int64(cur.nice) - Int64(prev.nice)
        let total = userDiff + sysDiff + idleDiff + niceDiff
        guard total > 0 else { return 0 }
        let busy = userDiff + sysDiff + niceDiff
        return min(1.0, max(0.0, Double(busy) / Double(total)))
    }

    // MARK: - Memory (host_statistics64)

    private func readMemory() -> (used: Int64, total: Int64, pressure: MemoryPressure) {
        var stats = vm_statistics64()
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &size)
            }
        }
        guard result == KERN_SUCCESS else { return (0, 0, .normal) }

        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        let ps = Int64(pageSize)
        let active     = Int64(stats.active_count)     * ps
        let wired      = Int64(stats.wire_count)       * ps
        let compressed = Int64(stats.compressor_page_count) * ps
        let used = active + wired + compressed
        let total = Int64(ProcessInfo.processInfo.physicalMemory)

        // Approximate pressure: ratio of used / total. macOS exposes the
        // real signal via sysctl "kern.memorystatus_*" which needs entitlements;
        // this heuristic is fine for a UI gauge.
        let pct = total > 0 ? Double(used) / Double(total) : 0
        let pressure: MemoryPressure
        switch pct {
        case ..<0.7: pressure = .normal
        case ..<0.9: pressure = .warning
        default:     pressure = .critical
        }
        return (used, total, pressure)
    }

    // MARK: - Disk

    private func readDisk() -> (free: Int64, total: Int64) {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: "/")
            let total = (attrs[.systemSize] as? Int64) ?? 0
            let free  = (attrs[.systemFreeSize] as? Int64) ?? 0
            return (free, total)
        } catch {
            return (0, 0)
        }
    }

    // MARK: - Network (getifaddrs)

    private func readNetworkBytes() -> (rx: UInt64, tx: UInt64) {
        var rx: UInt64 = 0
        var tx: UInt64 = 0
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>? = nil
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else { return (0, 0) }
        defer { freeifaddrs(ifaddrPtr) }
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let cur = ptr {
            defer { ptr = cur.pointee.ifa_next }
            guard let addr = cur.pointee.ifa_addr,
                  Int32(addr.pointee.sa_family) == AF_LINK,
                  let dataPtr = cur.pointee.ifa_data else { continue }
            let ifname = String(cString: cur.pointee.ifa_name)
            // Skip loopback to avoid double-counting localhost traffic.
            if ifname.hasPrefix("lo") { continue }
            let data = dataPtr.assumingMemoryBound(to: if_data.self).pointee
            rx += UInt64(data.ifi_ibytes)
            tx += UInt64(data.ifi_obytes)
        }
        return (rx, tx)
    }

    private func computeNetworkRates() -> (rx: Int64, tx: Int64) {
        let now = Date().timeIntervalSince1970
        let cur = readNetworkBytes()
        let elapsed = max(0.001, now - prevNet.time)
        let rxDiff = cur.rx >= prevNet.rx ? cur.rx - prevNet.rx : 0
        let txDiff = cur.tx >= prevNet.tx ? cur.tx - prevNet.tx : 0
        prevNet = (cur.rx, cur.tx, now)
        return (Int64(Double(rxDiff) / elapsed), Int64(Double(txDiff) / elapsed))
    }

    // MARK: - Disk I/O (IOBlockStorageDriver Statistics)

    /// Sums bytes read/written across all block devices via the IORegistry
    /// `IOBlockStorageDriver` nodes. Each driver exposes a `Statistics`
    /// dict with cumulative byte counters; we delta against the last poll
    /// to compute a rate. Counters reset on reboot.
    private func readDiskIOBytes() -> (read: UInt64, write: UInt64) {
        var read: UInt64 = 0
        var write: UInt64 = 0
        let matching = IOServiceMatching("IOBlockStorageDriver")
        var iter: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iter) == KERN_SUCCESS else {
            return (0, 0)
        }
        defer { IOObjectRelease(iter) }

        while case let service = IOIteratorNext(iter), service != 0 {
            defer { IOObjectRelease(service) }
            guard let stats = IORegistryEntryCreateCFProperty(
                service, "Statistics" as CFString, kCFAllocatorDefault, 0
            )?.takeRetainedValue() as? [String: Any] else { continue }
            if let r = stats["Bytes (Read)"] as? UInt64 { read += r }
            if let w = stats["Bytes (Write)"] as? UInt64 { write += w }
        }
        return (read, write)
    }

    private func computeDiskIORates() -> (read: Int64, write: Int64) {
        let now = Date().timeIntervalSince1970
        let cur = readDiskIOBytes()
        let elapsed = max(0.001, now - prevDisk.time)
        let rDiff = cur.read >= prevDisk.read ? cur.read - prevDisk.read : 0
        let wDiff = cur.write >= prevDisk.write ? cur.write - prevDisk.write : 0
        prevDisk = (cur.read, cur.write, now)
        return (Int64(Double(rDiff) / elapsed), Int64(Double(wDiff) / elapsed))
    }

    // MARK: - Battery (IOPSCopyPowerSourcesInfo)

    private func readBattery() -> (level: Double?, health: BatteryHealth, cycles: Int?, timeMinutes: Int?, isCharging: Bool, onAC: Bool) {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else { return (nil, .unknown, nil, nil, false, false) }

        for src in sources {
            guard let dict = IOPSGetPowerSourceDescription(blob, src)?.takeUnretainedValue() as? [String: Any] else { continue }
            let type = dict[kIOPSTypeKey as String] as? String
            guard type == kIOPSInternalBatteryType as String else { continue }

            let cur = dict[kIOPSCurrentCapacityKey as String] as? Int ?? 0
            let max = dict[kIOPSMaxCapacityKey as String] as? Int ?? 100
            let level = max > 0 ? Double(cur) / Double(max) : 0

            let condition = dict["BatteryHealth"] as? String ?? ""
            let health: BatteryHealth
            switch condition {
            case "Good":    health = .good
            case "Fair":    health = .fair
            case "Poor":    health = .poor
            default:        health = .unknown
            }

            let cycles = (dict["Cycle Count"] as? Int)
                ?? (dict["DesignCycleCount9C"] as? Int)
                ?? readSmartBatteryCycleCount()

            let powerState = dict[kIOPSPowerSourceStateKey as String] as? String
            let onAC = powerState == kIOPSACPowerValue as String
            let isCharging = dict[kIOPSIsChargingKey as String] as? Bool ?? false
            // -1 means "still calculating", 0 / missing means unknown.
            let timeRaw: Int = isCharging
                ? (dict[kIOPSTimeToFullChargeKey as String] as? Int ?? -1)
                : (dict[kIOPSTimeToEmptyKey as String] as? Int ?? -1)
            let timeMinutes: Int? = (timeRaw > 0) ? timeRaw : nil

            return (level, health, cycles, timeMinutes, isCharging, onAC)
        }
        return (nil, .unknown, nil, nil, false, false)
    }

    /// Cycle count is exposed by `IOPSGetPowerSourceDescription` on some
    /// Macs but missing on others. Fall back to the AppleSmartBattery
    /// IORegistry node, which always carries `CycleCount` on portables.
    /// Returns nil on desktops (no AppleSmartBattery service).
    private func readSmartBatteryCycleCount() -> Int? {
        let matching = IOServiceMatching("AppleSmartBattery")
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        guard let prop = IORegistryEntryCreateCFProperty(
            service, "CycleCount" as CFString, kCFAllocatorDefault, 0
        )?.takeRetainedValue() as? Int else { return nil }
        return prop
    }
}
