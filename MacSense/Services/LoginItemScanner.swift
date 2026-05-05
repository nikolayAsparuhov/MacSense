import Foundation
import AppKit
import Security

/// Discovers and mutates launchd jobs (login items / background activity).
///
/// What System Settings → General → Login Items shows is a union of:
///   - SMAppService registrations (modern, macOS 13+)
///   - Classic LaunchAgents / LaunchDaemons under ~/Library/LaunchAgents,
///     /Library/LaunchAgents, /Library/LaunchDaemons
///
/// Both ultimately live as plist files on disk. Apple has no public API to
/// enumerate them, so we walk the three directories ourselves — same
/// approach used by AppCleaner, CleanMyMac, and similar tools.
final class LoginItemScanner {
    static let shared = LoginItemScanner()
    private let fm = FileManager.default
    private var signerCache: [String: SignerInfo] = [:]
    /// Bundle ID → app bundle URL, populated on first lookup per scan.
    /// Used by `lookupAppByLabel` to find a launchd job's parent app via
    /// longest-shared-prefix on the bundle ID — covers cases the Launch
    /// Services label walk misses (e.g. `com.docker.socket` shares the
    /// `com.docker` prefix with `com.docker.docker` = Docker Desktop).
    private var appBundleIndex: [String: URL] = [:]
    private var appBundleIndexBuilt = false
    private init() {}

    /// What we extract from a binary's code signature.
    private struct SignerInfo {
        let displayName: String?
        let teamID: String?
    }

    func scan() -> [LoginItem] {
        let userDisabled = readDisabledLabels(target: "gui/\(getuid())")
        // System scope needs root for `launchctl print-disabled system` —
        // we rely on the plist's `Disabled` key for those instead.

        // Rebuild the bundle-ID index each scan so newly installed /
        // removed apps are reflected.
        appBundleIndex.removeAll()
        appBundleIndexBuilt = false

        var items: [LoginItem] = []
        var seenLabels: Set<String> = []

        // 1. Classic launchd directories (/Library/Launch*, ~/Library/LaunchAgents).
        let scopes: [LoginItemScope] = [.userAgent, .systemAgent, .systemDaemon]
        for scope in scopes {
            guard let names = try? fm.contentsOfDirectory(atPath: scope.directory) else { continue }
            for name in names where name.hasSuffix(".plist") {
                let url = URL(fileURLWithPath: "\(scope.directory)/\(name)")
                if let item = parse(url: url, scope: scope, isEmbedded: false, userDisabled: userDisabled) {
                    items.append(item)
                    seenLabels.insert(item.label)
                }
            }
        }

        // 2. Modern SMAppService plists embedded inside .app bundles —
        //    `/Applications/Foo.app/Contents/Library/LaunchAgents/*.plist`
        //    and likewise LaunchDaemons. This is what System Settings →
        //    Login Items / Background Activity surfaces for apps that
        //    register via `SMAppService.agent(plistName:)`. Apple does NOT
        //    expose an enumeration API — same workaround AppCleaner uses.
        let appRoots = [
            "/Applications",
            "/Applications/Utilities",
            "/System/Applications",
            "/System/Applications/Utilities",
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path,
        ]
        for root in appRoots {
            guard let entries = try? fm.contentsOfDirectory(atPath: root) else { continue }
            for entry in entries where entry.hasSuffix(".app") {
                let appPath = "\(root)/\(entry)"
                let pairs: [(String, LoginItemScope)] = [
                    ("\(appPath)/Contents/Library/LaunchAgents", .userAgent),
                    ("\(appPath)/Contents/Library/LaunchDaemons", .systemDaemon),
                ]
                for (dir, scope) in pairs {
                    guard let names = try? fm.contentsOfDirectory(atPath: dir) else { continue }
                    for name in names where name.hasSuffix(".plist") {
                        let url = URL(fileURLWithPath: "\(dir)/\(name)")
                        if let item = parse(url: url, scope: scope, isEmbedded: true, userDisabled: userDisabled) {
                            // Avoid double-listing if both the embedded
                            // plist and an `~/Library/LaunchAgents/<id>.plist`
                            // copy registered by SMAppService exist.
                            if seenLabels.insert(item.label).inserted {
                                items.append(item)
                            }
                        }
                    }
                }

                // 3. Legacy SMLoginItemSetEnabled helpers — deprecated API
                //    that registers a helper .app bundle inside
                //    `<App>.app/Contents/Library/LoginItems/<Helper>.app`.
                //    These don't have launchd plists in the usual
                //    locations (launchd registers them dynamically when
                //    the helper is enabled), so we synthesise a LoginItem
                //    by reading the helper bundle directly. System
                //    Settings surfaces them as separate rows.
                let loginItemsDir = "\(appPath)/Contents/Library/LoginItems"
                if let helpers = try? fm.contentsOfDirectory(atPath: loginItemsDir) {
                    for helper in helpers where helper.hasSuffix(".app") {
                        let helperPath = "\(loginItemsDir)/\(helper)"
                        if let item = parseHelperApp(helperURL: URL(fileURLWithPath: helperPath),
                                                    parentApp: URL(fileURLWithPath: appPath)) {
                            if seenLabels.insert(item.label).inserted {
                                items.append(item)
                            }
                        }
                    }
                }
            }
        }

        return items.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    /// Build a synthetic LoginItem for a legacy SMLoginItemSetEnabled
    /// helper at `<Parent>.app/Contents/Library/LoginItems/<Helper>.app`.
    /// Bundle ID becomes the launchd label (that's what SMLoginItem uses
    /// when registering with launchd).
    private func parseHelperApp(helperURL: URL, parentApp: URL) -> LoginItem? {
        guard let bundle = Bundle(url: helperURL),
              let bundleID = bundle.bundleIdentifier
        else { return nil }
        let info = appInfo(at: parentApp)
        let helperBinary = bundle.executableURL?.path
        let programSize = helperURL.recursiveAllocatedSize()
        let attrs = try? fm.attributesOfItem(atPath: helperURL.path)
        let lastModified = attrs?[.modificationDate] as? Date
        let signer = helperBinary.flatMap { signerInfo(for: $0) }
        return LoginItem(
            id: UUID(),
            label: bundleID,
            plistURL: helperURL,            // no real plist — point at the helper bundle
            program: helperBinary,
            programArguments: [],
            bundleIdentifier: bundleID,
            appDisplayName: info.name,
            iconSourcePath: info.iconPath,
            signerName: signer?.displayName,
            isEmbedded: true,
            scope: .userAgent,              // SMLoginItem registers in user domain
            isEnabled: false,               // can't query without SMJobCopyDictionary (deprecated); default off
            plistSize: 0,
            programSize: programSize,
            lastModified: lastModified,
            runAtLoad: true,
            keepAlive: false
        )
    }

    // MARK: - Mutation

    /// Toggle a launchd job. User-scope changes go through the user's
    /// `gui/<uid>` domain; system-scope changes go through `system` and
    /// require admin.
    ///
    /// Re-enable path: `launchctl disable` writes a sticky override that
    /// `bootstrap` alone will NOT clear — bootstrap loads the plist but
    /// kernel still refuses to start the job. So we always run
    /// `enable` first, then bootstrap. Bootstrap failures are treated
    /// as success when the job is already loaded.
    ///
    /// Disable path: `bootout` only unloads the current instance — on
    /// next login the plist would re-load. `disable` writes the sticky
    /// override that survives reboots. We run both.
    func setEnabled(_ enabled: Bool, for item: LoginItem) async -> Bool {
        // Embedded (SMAppService-registered) plists are managed by
        // backgroundtaskmanagementagent. Neither launchctl override DB
        // writes nor bootstrap/bootout affect what System Settings
        // reports — only the parent app or the user (via Settings) can
        // change them. Refuse the operation so the UI surfaces the
        // "Open System Settings" guidance instead of a silent no-op.
        if item.isEmbedded {
            Logger.shared.log("Refused setEnabled on embedded plist \(item.label) — SMAppService managed", level: .info)
            return false
        }

        let target = launchctlTarget(for: item.scope)
        let serviceTarget = "\(target)/\(item.label)"
        let admin = item.scope.requiresAdmin

        if enabled {
            // Authoritative step: clear sticky disable override. This
            // write always succeeds (no service-existence check) and
            // controls whether the kernel will run the job on next
            // login. We treat its result as ground truth.
            let overrideOK = await runLaunchctl(["enable", serviceTarget], requiresAdmin: admin)

            // Best-effort: kickstart/bootstrap to make the change
            // visible immediately. Either may fail — SMAppService-
            // managed plists in macOS 13+ are mediated by
            // backgroundtaskmanagementagent and reject manual
            // bootstrap from third-party processes. The override
            // already persists, so the service will run on next
            // login regardless.
            _ = await runLaunchctl(["bootstrap", target, item.plistURL.path],
                                   requiresAdmin: admin,
                                   tolerateAlreadyLoaded: true)
            _ = await runLaunchctl(["kickstart", serviceTarget],
                                   requiresAdmin: admin,
                                   tolerateNotLoaded: true)
            return overrideOK
        } else {
            // Authoritative step: write the disable override so the
            // job stays off across reboots / logins.
            let overrideOK = await runLaunchctl(["disable", serviceTarget], requiresAdmin: admin)

            // Best-effort: unload the running instance now. May fail
            // for the same SMAppService reason as above; persistence
            // is what counts.
            _ = await runLaunchctl(["bootout", serviceTarget],
                                   requiresAdmin: admin,
                                   tolerateNotLoaded: true)
            return overrideOK
        }
    }

    /// "Delete" semantics depend on whether the plist is embedded.
    ///
    /// - Non-embedded (`/Library/Launch{Agents,Daemons}`,
    ///   `~/Library/LaunchAgents`): bootout + disable + rm the plist.
    ///   Job is permanently removed.
    /// - Embedded (`<App>.app/Contents/Library/Launch*/...`): we cannot
    ///   touch the file — that would invalidate the parent app's code
    ///   signature. Instead we bootout + disable so the helper stops
    ///   running and won't re-load on next login. The plist stays on
    ///   disk; the caller (UI) communicates this via copy.
    func delete(_ item: LoginItem) async -> Bool {
        let target = launchctlTarget(for: item.scope)
        let serviceTarget = "\(target)/\(item.label)"
        let admin = item.scope.requiresAdmin

        _ = await runLaunchctl(["bootout", serviceTarget],
                               requiresAdmin: admin,
                               tolerateNotLoaded: true)
        _ = await runLaunchctl(["disable", serviceTarget], requiresAdmin: admin)

        if item.isEmbedded {
            // Bundle-internal plist — leave the file alone.
            return true
        }

        if item.scope.requiresAdmin {
            return await deleteWithAdmin(path: item.plistURL.path)
        }
        do {
            try fm.removeItem(at: item.plistURL)
            return true
        } catch {
            Logger.shared.log("rm \(item.plistURL.path) failed: \(error.localizedDescription)", level: .warning)
            return false
        }
    }

    // MARK: - Internals

    private func parse(url: URL, scope: LoginItemScope, isEmbedded: Bool, userDisabled: Set<String>) -> LoginItem? {
        guard let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            return nil
        }

        let label = (dict["Label"] as? String) ?? url.deletingPathExtension().lastPathComponent
        let program = dict["Program"] as? String
        let programArguments = (dict["ProgramArguments"] as? [String]) ?? []
        let resolvedProgram = program ?? programArguments.first

        // AssociatedBundleIdentifiers (modern SMAppService) is the most
        // reliable source. MachServices keys also commonly carry the
        // parent app's bundle ID for older Apple-style helpers.
        let bundleID = (dict["AssociatedBundleIdentifiers"] as? [String])?.first
            ?? (dict["MachServices"] as? [String: Any])?.keys.first

        let runAtLoad = (dict["RunAtLoad"] as? Bool) ?? false
        let keepAlive: Bool
        switch dict["KeepAlive"] {
        case let b as Bool: keepAlive = b
        case is [String: Any]: keepAlive = true   // dict form means "yes, with conditions"
        default: keepAlive = false
        }
        let disabledInPlist = (dict["Disabled"] as? Bool) ?? false

        let disabledByLaunchd: Bool
        switch scope {
        case .userAgent:
            disabledByLaunchd = userDisabled.contains(label)
        case .systemAgent, .systemDaemon:
            // Without root we can't query `print-disabled system`. Fall
            // back to the plist value alone — sufficient for the common
            // case where the job has never been overridden via launchctl.
            disabledByLaunchd = false
        }
        let isEnabled = !disabledInPlist && !disabledByLaunchd

        let plistAttrs = try? fm.attributesOfItem(atPath: url.path)
        let plistSize = (plistAttrs?[.size] as? Int64) ?? 0
        let lastModified = plistAttrs?[.modificationDate] as? Date

        var programSize: Int64 = 0
        if let resolvedProgram, !resolvedProgram.isEmpty {
            let expanded = (resolvedProgram as NSString).expandingTildeInPath
            if fm.fileExists(atPath: expanded) {
                programSize = URL(fileURLWithPath: expanded).recursiveAllocatedSize()
            }
        }

        // For embedded plists we already know the parent app — it's the
        // .app bundle the plist lives inside. Walk up `Contents/Library/...`
        // to the .app root.
        let parentApp: (name: String?, iconPath: String?)
        if isEmbedded, let appURL = enclosingAppBundle(for: url) {
            parentApp = appInfo(at: appURL)
        } else {
            parentApp = resolveParentApp(bundleID: bundleID, program: resolvedProgram)
        }

        // Signer info from the program binary's code signature. Used when
        // there's no parent .app to fall back on (legacy daemons like
        // com.docker.socket, com.google.keystone.*, com.nomachine.*) so
        // the row still shows a friendly vendor name + generic icon.
        let signer = resolvedProgram.flatMap { signerInfo(for: $0) }

        // When the binary is missing or unsigned, walk the launchd label
        // itself: try Launch Services with progressively shorter prefixes
        // (`com.google.keystone.agent` → `com.google.keystone` →
        // `com.google.Keystone` → `com.google.Chrome`...) and prettify
        // the label as a human-readable last resort.
        let labelLookup = lookupAppByLabel(label)

        let appName = parentApp.name
            ?? signer?.displayName
            ?? labelLookup.name
            ?? prettifyLaunchdLabel(label)

        let iconSourcePath: String?
        if let p = parentApp.iconPath {
            iconSourcePath = p
        } else if let p = labelLookup.iconPath {
            iconSourcePath = p
        } else if let resolvedProgram {
            let expanded = (resolvedProgram as NSString).expandingTildeInPath
            iconSourcePath = fm.fileExists(atPath: expanded) ? expanded : nil
        } else {
            iconSourcePath = nil
        }

        return LoginItem(
            id: UUID(),
            label: label,
            plistURL: url,
            program: resolvedProgram,
            programArguments: programArguments,
            bundleIdentifier: bundleID,
            appDisplayName: appName,
            iconSourcePath: iconSourcePath,
            signerName: signer?.displayName,
            isEmbedded: isEmbedded,
            scope: scope,
            isEnabled: isEnabled,
            plistSize: plistSize,
            programSize: programSize,
            lastModified: lastModified,
            runAtLoad: runAtLoad,
            keepAlive: keepAlive
        )
    }

    /// Read the code signature of `binaryPath` and pull signer name + team
    /// ID. Cached per path. Returns nil for unsigned, missing, or
    /// unreadable binaries (e.g., when the file no longer exists).
    private func signerInfo(for binaryPath: String) -> SignerInfo? {
        let expanded = (binaryPath as NSString).expandingTildeInPath
        if let cached = signerCache[expanded] { return cached }
        guard fm.fileExists(atPath: expanded) else {
            signerCache[expanded] = SignerInfo(displayName: nil, teamID: nil)
            return nil
        }

        let url = URL(fileURLWithPath: expanded)
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode) == errSecSuccess,
              let code = staticCode else {
            signerCache[expanded] = SignerInfo(displayName: nil, teamID: nil)
            return nil
        }
        var info: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        guard SecCodeCopySigningInformation(code, flags, &info) == errSecSuccess,
              let dict = info as? [String: Any] else {
            signerCache[expanded] = SignerInfo(displayName: nil, teamID: nil)
            return nil
        }

        let teamID = dict["teamid"] as? String
        var displayName: String?
        if let certs = dict["certificates"] as? [SecCertificate], let leaf = certs.first {
            var cn: CFString?
            if SecCertificateCopyCommonName(leaf, &cn) == errSecSuccess,
               let cnStr = cn as String? {
                displayName = cleanCertificateCommonName(cnStr)
            }
        }
        let result = SignerInfo(displayName: displayName, teamID: teamID)
        signerCache[expanded] = result
        return result
    }

    /// Strip Apple's certificate-CN boilerplate down to a vendor name.
    /// Examples:
    ///   "Developer ID Application: Docker Inc. (9BNSXJN65R)" -> "Docker Inc."
    ///   "Apple Mac OS Application Signing"                    -> "Apple"
    private func cleanCertificateCommonName(_ raw: String) -> String {
        var s = raw
        let prefixes = [
            "Developer ID Application: ",
            "Apple Development: ",
            "Apple Distribution: ",
            "Mac Developer: ",
            "3rd Party Mac Developer Application: ",
        ]
        for p in prefixes where s.hasPrefix(p) {
            s.removeFirst(p.count)
        }
        // Strip the trailing " (TEAMID)" suffix on Developer ID certs.
        if s.hasSuffix(")"), let openParen = s.range(of: " (", options: .backwards) {
            s = String(s[..<openParen.lowerBound])
        }
        // Apple's own daemons sign as "Apple Mac OS Application Signing"
        // or "Software Signing" — collapse to "Apple".
        if s == "Apple Mac OS Application Signing" || s == "Software Signing" {
            s = "Apple"
        }
        return s.trimmingCharacters(in: .whitespaces)
    }

    /// Last-resort lookup for daemons whose plist has no
    /// AssociatedBundleIdentifiers, no MachServices, no .app ancestor in
    /// the program path, and no readable code signature. Walks the
    /// launchd label like a reverse-DNS bundle ID, asking Launch Services
    /// at each suffix-trimmed level. `com.google.keystone.agent` →
    /// `com.google.keystone.agent` → `com.google.keystone` →
    /// `com.google.Keystone` (case-corrected) → eventually finds a .app.
    /// If that fails, fall back to scanning installed apps for the bundle
    /// ID with the longest shared dot-prefix — handles unrelated suffixes
    /// like `com.docker.socket` ↔ `com.docker.docker` (Docker Desktop).
    private func lookupAppByLabel(_ label: String) -> (name: String?, iconPath: String?) {
        var parts = label.split(separator: ".").map(String.init)
        // Common reverse-DNS roots that aren't useful as a bundle ID.
        let roots: Set<String> = ["com", "org", "net", "io", "co"]
        while parts.count >= 2 {
            let candidate = parts.joined(separator: ".")
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: candidate) {
                return appInfo(at: url)
            }
            // Try TitleCased last component (Keystone vs keystone).
            if let last = parts.last, last != last.capitalized {
                var cap = parts
                cap[cap.count - 1] = last.capitalized
                let capCandidate = cap.joined(separator: ".")
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: capCandidate) {
                    return appInfo(at: url)
                }
            }
            parts.removeLast()
            // Stop when we'd be left only with a generic root like "com".
            if parts.count == 1, roots.contains(parts[0].lowercased()) { break }
        }

        if let url = longestPrefixAppMatch(for: label) {
            return appInfo(at: url)
        }
        return (nil, nil)
    }

    /// Walk every .app under standard application roots, read each
    /// Info.plist for `CFBundleIdentifier`, and store the result.
    /// Lazy — runs on first lookup per scan() invocation.
    private func buildAppBundleIndex() {
        guard !appBundleIndexBuilt else { return }
        appBundleIndexBuilt = true
        let roots = [
            "/Applications",
            "/Applications/Utilities",
            "/System/Applications",
            "/System/Applications/Utilities",
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path,
        ]
        for root in roots {
            guard let entries = try? fm.contentsOfDirectory(atPath: root) else { continue }
            for entry in entries where entry.hasSuffix(".app") {
                let url = URL(fileURLWithPath: "\(root)/\(entry)")
                if let id = readBundleIdentifier(at: url), !id.isEmpty {
                    // Don't overwrite — first hit wins (user /Applications
                    // takes precedence over /System/Applications duplicates).
                    if appBundleIndex[id] == nil { appBundleIndex[id] = url }
                }
            }
        }
    }

    /// Read CFBundleIdentifier directly from `Contents/Info.plist` —
    /// dramatically faster than constructing a `Bundle` instance for
    /// hundreds of installed apps just to read one key.
    private func readBundleIdentifier(at appURL: URL) -> String? {
        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        return dict["CFBundleIdentifier"] as? String
    }

    /// Find the installed .app whose bundle ID shares the longest dot-
    /// separated prefix with `label`. Requires at least 2 shared
    /// components (e.g. `com.docker`) so we don't promote every `com.*`
    /// app for an unmatched label. Case-insensitive.
    private func longestPrefixAppMatch(for label: String) -> URL? {
        buildAppBundleIndex()
        let labelParts = label.split(separator: ".").map { String($0).lowercased() }
        guard labelParts.count >= 2 else { return nil }

        var bestDepth = 1
        var bestURL: URL?
        for (id, url) in appBundleIndex {
            let idParts = id.split(separator: ".").map { String($0).lowercased() }
            let cap = min(labelParts.count, idParts.count)
            var shared = 0
            for i in 0..<cap {
                if labelParts[i] == idParts[i] { shared += 1 } else { break }
            }
            if shared > bestDepth {
                bestDepth = shared
                bestURL = url
            }
        }
        return bestURL
    }

    /// Turn a launchd label into a human-readable name when nothing else
    /// resolves. Drops reverse-DNS root, picks the most descriptive
    /// component, splits camelCase + underscores, and Title Cases.
    /// `com.google.keystone.agent`         → "Google Keystone"
    /// `com.docker.socket`                  → "Docker"
    /// `com.macpaw.CleanMyMac5.Updater`     → "CleanMyMac5"
    /// `com.nomachine.uninstallAgent`       → "NoMachine"
    private func prettifyLaunchdLabel(_ label: String) -> String {
        let parts = label.split(separator: ".").map(String.init)
        let roots: Set<String> = ["com", "org", "net", "io", "co"]
        // Common helper-tail components we want to discard so the vendor
        // shows through.
        let helperTail: Set<String> = [
            "agent", "daemon", "helper", "service", "xpcservice", "xpc",
            "socket", "updater", "uninstall", "uninstallagent",
            "loginhelper", "loginitem", "background",
        ]
        // Drop leading reverse-DNS root.
        var tokens = parts
        if let first = tokens.first, roots.contains(first.lowercased()) {
            tokens.removeFirst()
        }
        // Drop trailing helper components when there's still a vendor
        // token before them.
        while tokens.count > 1, let last = tokens.last, helperTail.contains(last.lowercased()) {
            tokens.removeLast()
        }
        guard !tokens.isEmpty else { return label }

        // For something like ["google", "keystone"] or ["nomachine"]
        // produce "Google Keystone" / "NoMachine". For ["macpaw",
        // "CleanMyMac5"] prefer the descriptive child over the vendor.
        let display: String
        if tokens.count >= 2, tokens[1].count >= tokens[0].count {
            display = tokens[1]
        } else if tokens.count >= 2 {
            display = "\(tokens[0]) \(tokens[1])"
        } else {
            display = tokens[0]
        }
        return splitCamelCase(display)
    }

    /// "CleanMyMac5" → "Clean My Mac 5", "uninstallAgent" → "Uninstall Agent",
    /// already-spaced strings pass through unchanged.
    private func splitCamelCase(_ s: String) -> String {
        guard !s.isEmpty else { return s }
        var out = ""
        var prevIsLower = false
        var prevIsLetter = false
        for ch in s {
            let isUpper = ch.isUppercase
            let isLetter = ch.isLetter
            let isDigit = ch.isNumber
            if !out.isEmpty {
                if isUpper && prevIsLower {
                    out.append(" ")
                } else if isDigit && prevIsLetter {
                    out.append(" ")
                } else if isLetter && !prevIsLetter && !out.hasSuffix(" ") {
                    out.append(" ")
                }
            }
            out.append(ch)
            prevIsLower = ch.isLowercase
            prevIsLetter = isLetter
        }
        // Capitalize the very first character.
        return out.prefix(1).uppercased() + out.dropFirst()
    }

    /// For an embedded plist at `<App>.app/Contents/Library/Launch{Agents,Daemons}/<id>.plist`,
    /// return the enclosing `.app` URL.
    private func enclosingAppBundle(for plistURL: URL) -> URL? {
        var url = plistURL.deletingLastPathComponent()
        while url.path != "/" {
            if url.pathExtension == "app" { return url }
            url.deleteLastPathComponent()
        }
        return nil
    }

    /// Try to locate the parent `.app` bundle for a launchd job and pull
    /// its display name + icon. Two strategies, in order:
    ///
    /// 1. If the plist has an `AssociatedBundleIdentifiers` (modern
    ///    SMAppService apps) or a `MachServices` key that maps to a
    ///    bundle ID, ask Launch Services where that app lives.
    /// 2. Otherwise walk the job's `Program` / `ProgramArguments[0]` path
    ///    looking for a `.app` ancestor — covers older Apple-style helpers
    ///    embedded inside an app bundle's `Contents/Library/LoginItems/`.
    ///
    /// Both fall through to nil for stale plists whose parent app is gone.
    private func resolveParentApp(bundleID: String?, program: String?) -> (name: String?, iconPath: String?) {
        if let bundleID, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return appInfo(at: url)
        }
        if let program {
            let parts = (program as NSString).pathComponents
            if let appIdx = parts.firstIndex(where: { ($0 as NSString).pathExtension == "app" }) {
                let appPath = NSString.path(withComponents: Array(parts.prefix(appIdx + 1)))
                if fm.fileExists(atPath: appPath) {
                    return appInfo(at: URL(fileURLWithPath: appPath))
                }
            }
        }
        return (nil, nil)
    }

    private func appInfo(at url: URL) -> (name: String?, iconPath: String?) {
        let bundle = Bundle(url: url)
        let displayName = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)?.nonEmpty
        let bundleName = (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)?.nonEmpty
        let fallback = url.deletingPathExtension().lastPathComponent
        return (displayName ?? bundleName ?? fallback, url.path)
    }

    /// Reads `launchctl print-disabled <target>` and returns labels that the
    /// user explicitly disabled via `launchctl disable` (independent of the
    /// `Disabled` key in the plist).
    private func readDisabledLabels(target: String) -> Set<String> {
        let output = runReadingStdout(executable: "/bin/launchctl", arguments: ["print-disabled", target])
        var disabled: Set<String> = []
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let arrow = trimmed.range(of: "=>") else { continue }
            let labelPart = trimmed[..<arrow.lowerBound]
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"' \t"))
            let valuePart = trimmed[arrow.upperBound...]
                .trimmingCharacters(in: .whitespaces)
            if valuePart == "true" {
                disabled.insert(labelPart)
            }
        }
        return disabled
    }

    private func launchctlTarget(for scope: LoginItemScope) -> String {
        switch scope {
        case .userAgent: return "gui/\(getuid())"
        case .systemAgent, .systemDaemon: return "system"
        }
    }

    private func runLaunchctl(_ arguments: [String],
                              requiresAdmin: Bool,
                              tolerateAlreadyLoaded: Bool = false,
                              tolerateNotLoaded: Bool = false) async -> Bool {
        if requiresAdmin {
            let cmd = "/bin/launchctl " + arguments.map { "'\($0.replacingOccurrences(of: "'", with: "'\\''"))'" }.joined(separator: " ")
            return await runWithAdmin(cmd)
        }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = arguments
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let status = task.terminationStatus
            if status == 0 { return true }

            // launchctl returns POSIX-style codes; common ones:
            //   17 (EEXIST) — "Service is already loaded"
            //   3 / 113 (ESRCH / not found) — "Could not find specified service"
            //   36 — "Operation already in progress"
            if tolerateAlreadyLoaded && (status == 17 || status == 36) { return true }
            if tolerateNotLoaded && (status == 3 || status == 113) { return true }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            Logger.shared.log("launchctl \(arguments.joined(separator: " ")) exited \(status): \(msg)", level: .info)
            return false
        } catch {
            Logger.shared.log("launchctl spawn failed: \(error.localizedDescription)", level: .warning)
            return false
        }
    }

    private func deleteWithAdmin(path: String) async -> Bool {
        let escaped = path.replacingOccurrences(of: "'", with: "'\\''")
        return await runWithAdmin("/bin/rm -f '\(escaped)'")
    }

    /// Runs a shell command via AppleScript's `do shell script ... with
    /// administrator privileges`. Pops the standard admin-password sheet.
    private func runWithAdmin(_ shellCommand: String) async -> Bool {
        let asEscaped = shellCommand
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(asEscaped)\" with administrator privileges"
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                var errorInfo: NSDictionary?
                let script = NSAppleScript(source: source)
                _ = script?.executeAndReturnError(&errorInfo)
                if let errorInfo {
                    let code = (errorInfo[NSAppleScript.errorNumber] as? Int) ?? 0
                    if code != -128 {
                        let msg = (errorInfo[NSAppleScript.errorMessage] as? String) ?? "\(errorInfo)"
                        Logger.shared.log("admin shell failed (\(code)): \(msg)", level: .warning)
                    }
                    continuation.resume(returning: false)
                } else {
                    continuation.resume(returning: true)
                }
            }
        }
    }

    private func runReadingStdout(executable: String, arguments: [String]) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = arguments
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
