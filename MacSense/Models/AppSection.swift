import Foundation

/// Top-level navigation section. Order here determines sidebar order.
enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case cleanup
    case performance
    case applications
    case storage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cleanup:      return "Cleanup"
        case .performance:  return "Performance"
        case .applications: return "Applications"
        case .storage:      return "Storage"
        }
    }

    var iconName: String {
        switch self {
        case .cleanup:      return "sparkles"
        case .performance:  return "speedometer"
        case .applications: return "square.grid.2x2.fill"
        case .storage:      return "internaldrive.fill"
        }
    }

    /// Short tagline shown under the section heading.
    var tagline: String {
        switch self {
        case .cleanup:
            return "Free up disk space by trimming caches and junk."
        case .performance:
            return "Live system metrics — CPU, memory, GPU, network, thermal."
        case .applications:
            return "Manage installed apps and login items."
        case .storage:
            return "See what's taking up your disk and reclaim it."
        }
    }
}
