import Foundation

/// A file the scanner found and then deliberately dropped, with the rule that
/// dropped it.
///
/// Only *vetoes* are recorded — an item that matched the app and was then
/// refused. The tens of thousands of files that simply never matched are not
/// exclusions, they are noise, and listing them would bury the handful of
/// entries that actually tell the user something.
struct ExcludedItem: Hashable, Identifiable {
    let url: URL
    let rule: ExclusionRule

    var id: String { url.path + rule.logLabel }
}

enum ExclusionRule: Hashable {
    /// Cache leaf whose name encodes a filesystem path — belongs to a
    /// project-aware tool, not to the app whose name appears in that path.
    case encodedProjectPath
    /// A per-app rule in `Conditions.swift` listed this as a known collision.
    case appRuleExcludeTerm
    /// A force-exclude path from the same per-app rule.
    case forceExcludePath
    /// A system/Apple skip rule matched the name or location.
    case systemSkipRule
    /// The path validator refused it at plan time.
    case validator(UninstallPathValidator.RejectionReason)

    var labelKey: LocalizationKey {
        switch self {
        case .encodedProjectPath:  return .exclusionEncodedProjectPath
        case .appRuleExcludeTerm,
             .forceExcludePath:    return .exclusionAppRule
        case .systemSkipRule:      return .exclusionSystemItem
        case .validator(let reason):
            switch reason {
            case .highRiskDotPath:   return .exclusionHighRiskDotPath
            case .protectedLocation,
                 .tooShallow,
                 .approvedRootItself: return .exclusionProtectedLocation
            case .outsideApprovedRoots: return .exclusionOutsideScanRoots
            case .missing:              return .exclusionMissing
            }
        }
    }

    @MainActor
    var localizedLabel: String { Localization.shared.t(labelKey) }

    /// Stable, never-localized identifier for the uninstall log.
    var logLabel: String {
        switch self {
        case .encodedProjectPath:   return "encoded-project-path"
        case .appRuleExcludeTerm:   return "app-rule-exclude-term"
        case .forceExcludePath:     return "app-rule-force-exclude"
        case .systemSkipRule:       return "system-skip-rule"
        case .validator(let r):     return "validator:\(r.debugLabel)"
        }
    }
}

/// What the scanner produced for one app: the files it will act on, and the
/// ones it refused.
struct FinderResult {
    var matches: [URL: MatchReason]
    var excluded: [ExcludedItem]

    static let empty = FinderResult(matches: [:], excluded: [])
}

/// The pre-delete verdict shown before anything is removed.
///
/// This is the "dry run" made explicit: the scan is already non-destructive,
/// what was missing was a summary the user can act on. Nothing here touches
/// the file system beyond checking who owns the parent directory.
struct SafetyAssessment {

    enum Level {
        case safe
        case review
        case highRisk

        var titleKey: LocalizationKey {
            switch self {
            case .safe:     return .safetyLevelSafe
            case .review:   return .safetyLevelReview
            case .highRisk: return .safetyLevelHighRisk
            }
        }

        var systemImage: String {
            switch self {
            case .safe:     return "checkmark.shield.fill"
            case .review:   return "exclamationmark.shield.fill"
            case .highRisk: return "xmark.shield.fill"
            }
        }
    }

    let level: Level
    let itemCount: Int
    /// Items whose parent directory the user cannot write — removing them
    /// prompts for an administrator password.
    let adminRequiredCount: Int
    /// Launch agents, launch daemons, privileged helpers, system extensions.
    let systemComponentCount: Int
    /// Matches that rest on the app's *name* rather than its identifier —
    /// the ones most likely to have caught an unrelated file.
    let lowConfidenceCount: Int
    let excludedCount: Int
    /// The app (or one of its helpers) is running. Removing a live app's files
    /// leaves the process writing into paths that no longer exist, so the
    /// preflight quits it first — the user should know that is about to happen.
    let appIsRunning: Bool

    /// Paths whose removal changes system behaviour beyond the app itself.
    private static let systemComponentRoots = [
        "/Library/LaunchDaemons", "/Library/LaunchAgents",
        "/Library/PrivilegedHelperTools", "/Library/Extensions",
        "\(home)/Library/LaunchAgents",
    ]

    init(urls: [URL], reasons: [URL: MatchReason], excluded: [ExcludedItem], appIsRunning: Bool) {
        let fm = FileManager.default
        self.appIsRunning = appIsRunning
        itemCount = urls.count
        excludedCount = excluded.count

        adminRequiredCount = urls.filter {
            !fm.isWritableFile(atPath: $0.deletingLastPathComponent().path)
        }.count

        systemComponentCount = urls.filter { url in
            Self.systemComponentRoots.contains {
                UninstallPathValidator.isStrictDescendant(url.path, of: $0)
            }
        }.count

        lowConfidenceCount = urls.filter { (reasons[$0]?.confidence ?? .high) == .low }.count

        if systemComponentCount > 0 {
            level = .highRisk
        } else if adminRequiredCount > 0 || lowConfidenceCount > 0 || appIsRunning {
            level = .review
        } else {
            level = .safe
        }
    }

    /// True when the user should have to confirm before the delete runs.
    var requiresConfirmation: Bool { level != .safe }

    /// One line per thing worth knowing, in severity order. Empty for a clean
    /// `.safe` verdict — silence is the right output when there is nothing to
    /// warn about.
    @MainActor
    var warnings: [String] {
        var list: [String] = []
        if systemComponentCount > 0 {
            list.append(Localization.shared.t(.safetyWarningSystemComponents, systemComponentCount))
        }
        if adminRequiredCount > 0 {
            list.append(Localization.shared.t(.safetyWarningAdminRequired, adminRequiredCount))
        }
        if lowConfidenceCount > 0 {
            list.append(Localization.shared.t(.safetyWarningLowConfidence, lowConfidenceCount))
        }
        if appIsRunning {
            list.append(Localization.shared.t(.safetyWarningAppRunning))
        }
        return list
    }
}
