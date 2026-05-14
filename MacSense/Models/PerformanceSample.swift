import Foundation

/// One snapshot of system performance metrics. Sampled on a 1Hz timer by
/// `PerformanceMonitor`. Nil values mean the underlying API is unavailable
/// on this machine (or requires private/SMC access we haven't wired).
struct PerformanceSample {
    var cpuUsage: Double = 0           // 0.0 - 1.0 (whole-system)
    var processCount: Int = 0          // running processes
    var memoryUsedBytes: Int64 = 0
    var memoryTotalBytes: Int64 = 0
    var memoryPressure: MemoryPressure = .normal
    var diskFreeBytes: Int64 = 0
    var diskTotalBytes: Int64 = 0
    var diskReadPerSec: Int64 = 0      // bytes/s across all block devices
    var diskWritePerSec: Int64 = 0
    var networkRxPerSec: Int64 = 0     // bytes/s, EWMA-smoothed
    var networkTxPerSec: Int64 = 0
    var batteryLevel: Double? = nil    // 0.0 - 1.0; nil for desktops
    var batteryHealth: BatteryHealth = .unknown
    var batteryCycleCount: Int? = nil
    var batteryTimeMinutes: Int? = nil // time-to-empty when on battery, time-to-full when charging
    var batteryIsCharging: Bool = false
    var batteryOnAC: Bool = false
    var thermalState: ProcessInfo.ThermalState = .nominal
    var cpuTemperature: Double? = nil  // °C, SMC; nil if unreadable
    var gpuUsage: Double? = nil        // not available via public API

    var memoryPercent: Double {
        guard memoryTotalBytes > 0 else { return 0 }
        return Double(memoryUsedBytes) / Double(memoryTotalBytes)
    }
    var diskUsedBytes: Int64 { max(0, diskTotalBytes - diskFreeBytes) }
    var diskPercent: Double {
        guard diskTotalBytes > 0 else { return 0 }
        return Double(diskUsedBytes) / Double(diskTotalBytes)
    }
}

enum MemoryPressure: String {
    case normal, warning, critical

    var labelKey: LocalizationKey {
        switch self {
        case .normal:   return .memoryNormal
        case .warning:  return .memoryWarning
        case .critical: return .memoryCritical
        }
    }
}

enum BatteryHealth: String {
    case good, fair, poor, unknown

    @MainActor
    var label: String {
        switch self {
        case .good:    return Localization.shared.t(.batteryHealthGood)
        case .fair:    return Localization.shared.t(.batteryHealthFair)
        case .poor:    return Localization.shared.t(.batteryHealthPoor)
        case .unknown: return ""
        }
    }
}

extension ProcessInfo.ThermalState {
    var labelKey: LocalizationKey? {
        switch self {
        case .nominal:  return .thermalNominal
        case .fair:     return .thermalFair
        case .serious:  return .thermalSerious
        case .critical: return .thermalCritical
        @unknown default: return nil
        }
    }
}
