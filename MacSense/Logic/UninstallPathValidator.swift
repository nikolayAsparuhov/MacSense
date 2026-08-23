import Foundation

/// Last line of defence before anything is deleted during an uninstall.
///
/// The heuristic finder in `AppPathFinder` decides what *probably* belongs to
/// an app; this decides what is *allowed* to be removed at all. The two are
/// deliberately independent: a matcher bug can only ever produce a path this
/// validator already permits.
///
/// The rules, in order:
///   1. The path must still exist.
///   2. It is canonicalized (symlinks resolved) — every later check runs on
///      the real target, so a swapped symlink cannot smuggle a path in.
///   3. High-risk home dotpaths (`~/.ssh`, `~/.aws`, `~/.config`, …) are
///      refused outright, even though some of them are scan roots.
///   4. Protected locations — filesystem roots, the home folder, the standard
///      user folders, every mounted volume — are refused.
///   5. Anything two path components deep or shallower (`/`, `/Applications`)
///      is refused regardless of the lists above.
///   6. An approved root itself is refused; only strict descendants pass.
///
/// Approved roots are the very same list the scanner walks
/// (`Locations.appSearch.paths`), so the two cannot drift apart: if a location
/// isn't scanned, nothing under it can be deleted.
enum UninstallPathValidator {

    enum RejectionReason: Equatable {
        case missing
        case highRiskDotPath
        case protectedLocation
        case tooShallow
        case approvedRootItself
        case outsideApprovedRoots

        /// Non-localized label for logs. User-facing copy is applied by the UI.
        var debugLabel: String {
            switch self {
            case .missing:              return "path no longer exists"
            case .highRiskDotPath:      return "high-risk home dotpath"
            case .protectedLocation:    return "protected system location"
            case .tooShallow:           return "too close to a root directory"
            case .approvedRootItself:   return "is an approved root, not an item inside one"
            case .outsideApprovedRoots: return "outside every approved location"
            }
        }
    }

    struct Rejection: Error, Equatable {
        let path: String
        let reason: RejectionReason
    }

    // MARK: - Roots

    /// Every location the scanner is allowed to produce results from,
    /// canonicalized once. Derived from `Locations` so scan coverage and
    /// deletion permission are the same list.
    static let approvedRoots: Set<String> = {
        Set(Locations().appSearch.paths
            .filter { !$0.isEmpty }
            .map { URL(fileURLWithPath: $0).standardizedFileURL.resolvingSymlinksInPath().path })
    }()

    /// Locations that may never be deleted, including the roots of the user's
    /// own home layout and every mounted volume. Computed once — the home
    /// layout and mount table are stable within a run.
    static let protectedPaths: Set<String> = {
        var set: Set<String> = [
            "/", "/System", "/System/Library", "/System/Applications",
            "/Library", "/Users", "/Applications", "/Applications/Utilities",
            "/private", "/private/var", "/private/etc", "/private/tmp",
            "/usr", "/usr/local", "/usr/bin", "/usr/sbin",
            "/bin", "/sbin", "/etc", "/var", "/tmp", "/opt", "/cores", "/Volumes",
            "/Users/Shared",
        ]
        set.insert(home)
        for name in ["Library", "Applications", "Desktop", "Documents", "Downloads",
                     "Movies", "Music", "Pictures", "Public"] {
            set.insert("\(home)/\(name)")
        }
        // Standard Library subdirectories are containers for other apps' data —
        // an app may own an item inside them, never the directory itself.
        for name in Locations.standardLibrarySubdirectories {
            set.insert("\(home)/Library/\(name)")
            set.insert("/Library/\(name)")
        }
        if let volumes = try? FileManager.default.contentsOfDirectory(
            atPath: "/Volumes") {
            for volume in volumes { set.insert("/Volumes/\(volume)") }
        }
        return set
    }()

    // MARK: - Validation

    /// Validates one candidate. On success returns the canonicalized URL that
    /// should actually be deleted — callers must delete *that*, not the input,
    /// or the canonicalization is pointless.
    static func validate(_ url: URL) -> Result<URL, Rejection> {
        let canonical = url.standardizedFileURL.resolvingSymlinksInPath()
        let path = canonical.path

        // Refusals come before the existence check on purpose: a protected
        // path must report *why* it is off-limits even when it happens not to
        // exist on this machine, otherwise the reason the user sees depends on
        // their setup rather than on the rule that fired.
        for root in highRiskHomeDotPaths where path == root || path.hasPrefix(root + "/") {
            return .failure(Rejection(path: path, reason: .highRiskDotPath))
        }

        if protectedPaths.contains(path) {
            return .failure(Rejection(path: path, reason: .protectedLocation))
        }

        // "/Applications" -> ["/", "Applications"]. Anything at this depth is
        // a system-owned root even when the lists above missed it.
        if canonical.pathComponents.count <= 2 {
            return .failure(Rejection(path: path, reason: .tooShallow))
        }

        guard FileManager.default.fileExists(atPath: path) else {
            return .failure(Rejection(path: path, reason: .missing))
        }

        if approvedRoots.contains(path) {
            return .failure(Rejection(path: path, reason: .approvedRootItself))
        }

        guard approvedRoots.contains(where: { isStrictDescendant(path, of: $0) }) else {
            return .failure(Rejection(path: path, reason: .outsideApprovedRoots))
        }

        return .success(canonical)
    }

    /// Component-wise containment, so `/Applications` never matches
    /// `/ApplicationsOther` the way a plain string prefix would.
    static func isStrictDescendant(_ path: String, of root: String) -> Bool {
        let p = (path as NSString).pathComponents
        let r = (root as NSString).pathComponents
        guard p.count > r.count else { return false }
        return Array(p.prefix(r.count)) == r
    }
}

#if DEBUG
extension UninstallPathValidator {

    /// Runs on every Debug launch. The validator is the only thing standing
    /// between a matcher bug and a destroyed home directory, so it carries its
    /// own check rather than relying on manual testing.
    static func selfCheck() {
        func expectRejected(_ path: String, _ reason: RejectionReason, _ label: String) {
            switch validate(URL(fileURLWithPath: path)) {
            case .success:
                assertionFailure("PathValidator accepted \(label): \(path)")
            case .failure(let rejection):
                assert(rejection.reason == reason,
                       "PathValidator rejected \(label) for \(rejection.reason) — expected \(reason)")
            }
        }

        expectRejected("/", .protectedLocation, "the filesystem root")
        expectRejected("/System", .protectedLocation, "/System")
        expectRejected("/Library", .protectedLocation, "/Library")
        expectRejected("/Applications", .protectedLocation, "/Applications")
        expectRejected("/usr/local", .protectedLocation, "/usr/local")
        expectRejected(home, .protectedLocation, "the home directory")
        expectRejected("\(home)/Library", .protectedLocation, "~/Library")
        expectRejected("\(home)/Library/Caches", .protectedLocation, "~/Library/Caches")
        expectRejected("\(home)/Documents", .protectedLocation, "~/Documents")
        expectRejected("\(home)/.ssh", .highRiskDotPath, "~/.ssh")
        expectRejected("\(home)/.config", .highRiskDotPath, "~/.config")
        expectRejected("/etc/hosts", .outsideApprovedRoots, "a file outside every scan root")

        // Round-trip a real item inside an approved root, plus a symlink that
        // tries to escape from one.
        let fm = FileManager.default
        let sandbox = URL(fileURLWithPath: "\(home)/Library/Caches")
            .appendingPathComponent("tech.veraio.macsense.pathvalidator-selfcheck", isDirectory: true)
        try? fm.removeItem(at: sandbox)
        guard (try? fm.createDirectory(at: sandbox, withIntermediateDirectories: true)) != nil else { return }
        defer { try? fm.removeItem(at: sandbox) }

        let item = sandbox.appendingPathComponent("item.txt")
        try? Data("x".utf8).write(to: item)
        switch validate(item) {
        case .failure(let rejection):
            assertionFailure("PathValidator rejected a legitimate cache file: \(rejection.reason)")
        case .success(let canonical):
            assert(canonical.path == item.resolvingSymlinksInPath().path,
                   "PathValidator returned a non-canonical URL")
        }

        let escape = sandbox.appendingPathComponent("escape")
        try? fm.createSymbolicLink(at: escape, withDestinationURL: URL(fileURLWithPath: "\(home)/Documents"))
        expectRejected(escape.path, .protectedLocation, "a symlink pointing at ~/Documents")
    }
}
#endif
