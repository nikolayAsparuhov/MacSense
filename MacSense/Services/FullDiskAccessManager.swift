import AppKit
import Foundation

/// Detects whether Full Disk Access (FDA) has been granted to PureMac.
/// Without FDA, macOS TCC blocks access to ~/Desktop, ~/Documents, ~/Mail,
/// ~/.Trash, and other app containers even for non-sandboxed apps.
final class FullDiskAccessManager {
    static let shared = FullDiskAccessManager()

    private init() {}

    /// Check if Full Disk Access is granted by probing TCC-protected paths.
    ///
    /// Important: do NOT probe `~/.Trash` or `~/Desktop` — those are NOT
    /// TCC-protected on all macOS versions, so reading them succeeds without
    /// FDA and never registers PureMac with TCC. The user's bug
    /// ("PureMac does not appear in Full Disk Access list") was caused by the
    /// previous probe returning early on those paths and never touching a
    /// real TCC-protected file.
    ///
    /// We probe paths that are always TCC-gated. We also force a real read
    /// (not just `isReadableFile`) so the kernel records the access attempt
    /// and adds PureMac to the Full Disk Access list automatically.
    var hasFullDiskAccess: Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let probes = [
            "/Library/Application Support/com.apple.TCC/TCC.db",
            "\(home)/Library/Safari/Bookmarks.plist",
            "\(home)/Library/Safari/CloudTabs.db",
            "\(home)/Library/Mail",
            "\(home)/Library/Messages/chat.db",
        ]

        for path in probes {
            guard FileManager.default.fileExists(atPath: path) else { continue }
            if let handle = FileHandle(forReadingAtPath: path) {
                _ = try? handle.read(upToCount: 1)
                try? handle.close()
                return true
            }
            // File exists but FileHandle returned nil — TCC denied access.
            return false
        }
        // None of the probe paths exist on this system (extremely rare).
        // Treat as denied so the user sees the FDA prompt.
        return false
    }

    /// Opens System Settings to the Full Disk Access pane.
    func openFullDiskAccessSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }
}
