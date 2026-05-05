import Foundation
import AppKit

/// Where the launchd plist lives. Determines the launchd domain (user vs.
/// system) and whether modifying it requires admin escalation.
enum LoginItemScope: String, Codable {
    case userAgent       // ~/Library/LaunchAgents       — current user only
    case systemAgent     // /Library/LaunchAgents        — every login session
    case systemDaemon    // /Library/LaunchDaemons       — global, runs as root

    var requiresAdmin: Bool { self != .userAgent }

    var label: String {
        switch self {
        case .userAgent: return "User"
        case .systemAgent: return "System (Agent)"
        case .systemDaemon: return "System (Daemon)"
        }
    }

    var directory: String {
        switch self {
        case .userAgent:
            return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/LaunchAgents").path
        case .systemAgent:
            return "/Library/LaunchAgents"
        case .systemDaemon:
            return "/Library/LaunchDaemons"
        }
    }
}

/// One launchd job — what System Settings calls a "background activity" or
/// "login item". Backed by a plist on disk in one of three known locations.
struct LoginItem: Identifiable, Hashable {
    let id: UUID
    let label: String
    let plistURL: URL
    let program: String?
    let programArguments: [String]
    let bundleIdentifier: String?
    /// Display name of the parent .app bundle this job belongs to (resolved
    /// via NSWorkspace from the bundle ID, or extracted from the program
    /// path's `.app` ancestor). Nil when the job's parent app can't be
    /// identified — typically stale entries left behind after the parent
    /// app was deleted.
    let appDisplayName: String?
    /// Path to a file whose Finder icon should be displayed for this
    /// item — usually the parent .app bundle, or the binary itself.
    /// Stored as a path (not an NSImage) so hundreds of login items
    /// don't sit on hundreds of bitmap reps in idle memory.
    let iconSourcePath: String?

    /// Computed Finder icon, fetched lazily via NSWorkspace whenever
    /// a row paints. NSWorkspace caches resolution results internally
    /// so repeated reads are cheap. Nil when the source path no
    /// longer exists (stale plist).
    var appIcon: NSImage? {
        guard let path = iconSourcePath,
              FileManager.default.fileExists(atPath: path) else { return nil }
        return NSWorkspace.shared.icon(forFile: path)
    }
    /// Vendor / signer extracted from the program binary's code signature
    /// (e.g. "Docker Inc.", "NoMachine S.a.r.l.", "Postgres.app"). Used as
    /// a grouping key and as a fallback display name when the parent .app
    /// bundle can't be located. Nil for unsigned or unreadable binaries.
    let signerName: String?
    /// True for plists that ship inside an .app bundle (modern
    /// SMAppService registrations). These cannot be deleted independently
    /// — that would corrupt the parent app — so the UI hides the delete
    /// action for them. Toggling on/off still works via launchctl.
    let isEmbedded: Bool
    let scope: LoginItemScope
    /// True if the job is loaded by launchd AND not marked Disabled.
    let isEnabled: Bool
    let plistSize: Int64
    let programSize: Int64
    let lastModified: Date?
    let runAtLoad: Bool
    let keepAlive: Bool

    var totalSize: Int64 { plistSize + programSize }

    /// First line of the table row. `Zoom (us.zoom.ZoomDaemon)` when we
    /// know the parent app, otherwise just the launchd label.
    var displayName: String {
        if let appDisplayName, let bundleIdentifier {
            return "\(appDisplayName) (\(bundleIdentifier))"
        }
        if let appDisplayName {
            return "\(appDisplayName) (\(label))"
        }
        if let signerName {
            return "\(signerName) (\(label))"
        }
        return label
    }

    /// What to show as "source" — typically the parent app's bundle ID
    /// (e.g. com.docker.docker), failing that the program path.
    var source: String {
        if let bundleIdentifier { return bundleIdentifier }
        if let program { return program }
        return plistURL.lastPathComponent
    }

    /// SF Symbol name to render when no `appIcon` could be resolved. Picks
    /// a semantically meaningful glyph based on the launchd label so a
    /// VPN daemon, an updater, a database service, etc. each get a
    /// distinct icon instead of all sharing the generic scope glyph.
    var categorySymbol: String {
        let needle = (label + " " + (bundleIdentifier ?? "") + " " + (program ?? ""))
            .lowercased()
        // Order matters — first match wins; specific terms before generic.
        let rules: [(needles: [String], symbol: String)] = [
            (["vpn", "openvpn", "wireguard", "tunnelblick", "tailscale", "sophos.connect"], "lock.shield"),
            (["docker", "container", "orbstack", "podman"],                                  "shippingbox"),
            (["postgres", "mysql", "mariadb", "redis", "mongo", "sqlite", "database"],       "cylinder"),
            (["update", "updater", "keystone", "sparkle", "softwareupdate"],                 "arrow.triangle.2.circlepath"),
            (["uninstall"],                                                                  "trash"),
            (["backup", "timemachine", "snapshot"],                                          "externaldrive.badge.timemachine"),
            (["sync", "drive", "dropbox", "onedrive", "icloud", "rclone"],                   "icloud"),
            (["socket", "server", "nxserver", "nxnode", "rdp", "vnc", "ssh", "sshd"],        "network"),
            (["mail", "imap", "smtp"],                                                       "envelope"),
            (["chat", "slack", "messenger", "teams", "discord", "telegram"],                 "message"),
            (["audio", "sound", "mic"],                                                      "speaker.wave.2"),
            (["camera", "video", "webcam"],                                                  "video"),
            (["print", "cups"],                                                              "printer"),
            (["bluetooth"],                                                                  "wave.3.right"),
            (["keyboard"],                                                                   "keyboard"),
            (["mouse"],                                                                      "computermouse"),
            (["wifi", "wireless", "iwifi"],                                                  "wifi"),
            (["security", "antivirus", "sophos", "malware"],                                 "shield"),
            (["analytics", "telemetry", "crashreport"],                                      "chart.bar"),
            (["loginhelper", "loginitem"],                                                   "person.crop.circle.badge.checkmark"),
            (["agent", "daemon", "helper", "service", "xpc"],                                "gearshape.2"),
        ]
        for rule in rules {
            if rule.needles.contains(where: { needle.contains($0) }) {
                return rule.symbol
            }
        }
        // Final fallback by scope.
        switch scope {
        case .userAgent:    return "person.crop.circle"
        case .systemAgent:  return "gearshape"
        case .systemDaemon: return "gearshape.2"
        }
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: LoginItem, rhs: LoginItem) -> Bool { lhs.id == rhs.id }
}
