import Foundation

/// Top-level navigation section. Order here determines sidebar order.
enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case cleanup
    case performance
    case applications
    case storage

    var id: String { rawValue }

    /// Localization key for the section's sidebar title. Resolved
    /// at the call site via `Localization.shared.t(...)` so the
    /// model itself stays pure and synchronous.
    var titleKey: LocalizationKey {
        switch self {
        case .cleanup:      return .navCleanup
        case .performance:  return .navPerformance
        case .applications: return .navApplications
        case .storage:      return .navStorage
        }
    }

    /// Convenience that performs the lookup against the shared
    /// localization instance. Stays main-actor-safe because every
    /// SwiftUI view body is already on the main actor.
    @MainActor var title: String {
        Localization.shared.t(titleKey)
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
