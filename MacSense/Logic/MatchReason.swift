import Foundation

/// Why the path finder believes a file belongs to an app.
///
/// `AppPathFinder` runs a ladder of increasingly loose heuristics; before this
/// existed, all nine levels collapsed into a single `true` and the user was
/// shown a path with no way to judge it. Each case names the level that fired,
/// so the UI can show it, the safety score can weigh it, and the uninstall log
/// can record it.
enum MatchReason: Equatable, Hashable {
    case appBundle
    case condition(String)
    case forceIncludePath
    case entitlement
    case bundleIdentifier
    case appName
    case bundleFileName
    case lettersOnlyName
    case bundleLastTwo
    case baseBundleIdentifier
    case strippedAppName
    case companyName
    case teamIdentifier
    case containerMetadata
    case containerNamed

    /// How much the match is worth trusting. Drives the safety assessment and
    /// the colour of the confidence dot in the file list.
    enum Confidence: Int, Comparable {
        case low = 0, medium, high
        static func < (lhs: Confidence, rhs: Confidence) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    /// Identifier-derived and rule-derived matches are near-certain. Partial
    /// identifier matches can collide across a vendor's apps. Name- and
    /// vendor-derived matches are the ones that catch unrelated files, so they
    /// are the ones worth showing the user before they click delete.
    var confidence: Confidence {
        switch self {
        case .appBundle, .condition, .forceIncludePath, .entitlement,
             .bundleIdentifier, .containerMetadata, .containerNamed:
            return .high
        case .bundleLastTwo, .baseBundleIdentifier:
            return .medium
        case .appName, .bundleFileName, .lettersOnlyName, .strippedAppName,
             .companyName, .teamIdentifier:
            return .low
        }
    }

    /// Display label. Several internal cases share one label on purpose — the
    /// user needs to know *how strong* the evidence is, not which of four
    /// name-matching variants fired. The precise case still reaches the log.
    var labelKey: LocalizationKey {
        switch self {
        case .appBundle:                                  return .matchReasonAppBundle
        case .condition, .forceIncludePath:               return .matchReasonRule
        case .entitlement:                                return .matchReasonEntitlement
        case .bundleIdentifier:                           return .matchReasonBundleID
        case .bundleLastTwo, .baseBundleIdentifier:       return .matchReasonPartialBundleID
        case .appName, .bundleFileName,
             .lettersOnlyName, .strippedAppName:          return .matchReasonAppName
        case .companyName, .teamIdentifier:               return .matchReasonVendor
        case .containerMetadata, .containerNamed:         return .matchReasonContainer
        }
    }

    /// Main-actor isolated: `Localization` publishes the active locale to
    /// SwiftUI, and every caller of this is a view body.
    @MainActor
    var localizedLabel: String { Localization.shared.t(labelKey) }

    /// Stable identifier for the uninstall log — never localized.
    var logLabel: String {
        switch self {
        case .appBundle:            return "app-bundle"
        case .condition(let id):    return "rule:\(id)"
        case .forceIncludePath:     return "rule-force-include"
        case .entitlement:          return "entitlement"
        case .bundleIdentifier:     return "bundle-id"
        case .appName:              return "app-name"
        case .bundleFileName:       return "bundle-file-name"
        case .lettersOnlyName:      return "letters-only-name"
        case .bundleLastTwo:        return "bundle-id-last-two"
        case .baseBundleIdentifier: return "base-bundle-id"
        case .strippedAppName:      return "stripped-app-name"
        case .companyName:          return "company-name"
        case .teamIdentifier:       return "team-id"
        case .containerMetadata:    return "container-metadata"
        case .containerNamed:       return "container-named"
        }
    }
}
