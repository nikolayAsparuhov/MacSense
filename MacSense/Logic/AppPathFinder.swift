//
//  AppPathFinder.swift
//  PureMac
//
//  Heuristic file discovery engine that locates all filesystem artifacts
//  belonging to a given macOS application. Uses multi-level matching
//  against bundle identifiers, app names, entitlements, and team IDs
//  with configurable sensitivity.
//

import Foundation
import AppKit

class AppPathFinder {

    // MARK: - Types

    struct AppInfo {
        let appName: String
        let bundleIdentifier: String
        let path: URL
        let entitlements: [String]?
        let teamIdentifier: String?
    }

    enum Sensitivity {
        case strict    // Exact bundle ID + exact name match only
        case enhanced  // + partial matching, bundle components, stripped version
        case deep      // + company name, entitlements, team ID
    }

    // MARK: - Properties

    private let appInfo: AppInfo
    private let locations: Locations
    private let sensitivity: Sensitivity
    private var collection: [URL: MatchReason] = [:]
    /// Items that matched the app and were then vetoed by a rule. Surfaced to
    /// the user so a missing file has a visible reason rather than looking
    /// like the scanner simply didn't find it.
    private var excluded: [ExcludedItem] = []
    private let collectionQueue = DispatchQueue(label: "com.puremac.pathfinder.collection")

    // Pre-computed cached identifiers (computed once in init, used in hot loop)
    private let normalizedBundleID: String
    private let bundleLastTwo: String
    private let normalizedAppName: String
    private let appNameLettersOnly: String
    private let pathComponentName: String
    private let companyName: String?
    private let baseBundleID: String?
    private let strippedAppName: String?
    private let normalizedEntitlements: [String]
    private let normalizedTeamID: String?

    // MARK: - Initialization

    init(appInfo: AppInfo, locations: Locations, sensitivity: Sensitivity = .enhanced) {
        self.appInfo = appInfo
        self.locations = locations
        self.sensitivity = sensitivity

        self.normalizedBundleID = appInfo.bundleIdentifier.normalizedForMatching()
        self.bundleLastTwo = appInfo.bundleIdentifier.bundleLastTwoComponents
        self.normalizedAppName = appInfo.appName.normalizedForMatching()
        self.appNameLettersOnly = appInfo.appName.lettersOnly
        self.pathComponentName = appInfo.path.lastPathComponent
            .replacingOccurrences(of: ".app", with: "")
            .normalizedForMatching()
        self.companyName = appInfo.bundleIdentifier.bundleCompanyName
        self.baseBundleID = appInfo.bundleIdentifier.baseBundleIdentifier?.normalizedForMatching()

        let stripped = appInfo.appName.strippingTrailingVersion().normalizedForMatching()
        self.strippedAppName = (stripped != normalizedAppName && !stripped.isEmpty) ? stripped : nil

        self.normalizedEntitlements = appInfo.entitlements?.compactMap { e in
            let n = e.normalizedForMatching()
            return n.isEmpty ? nil : n
        } ?? []

        self.normalizedTeamID = appInfo.teamIdentifier?.normalizedForMatching()
    }

    // MARK: - Public API

    /// Find all files related to this app synchronously. Every returned URL
    /// carries the matching level that produced it.
    func findPaths() -> FinderResult {
        collection[appInfo.path] = .appBundle

        for location in locations.appSearch.paths {
            let isLibRoot = isLibraryDirectory(location)
            let maxDepth = isLibRoot ? 2 : 1
            processLocation(location, currentDepth: 0, maxDepth: maxDepth, isLibraryRootSearch: isLibRoot)
        }

        for (url, reason) in discoverContainers() where collection[url] == nil {
            collection[url] = reason
        }

        applyConditions()

        return FinderResult(matches: filterSubpaths(collection), excluded: excluded)
    }

    /// Find all files related to this app with parallel location processing.
    func findPathsAsync(completion: @escaping (FinderResult) -> Void) {
        collection[appInfo.path] = .appBundle

        let group = DispatchGroup()
        for location in locations.appSearch.paths {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                let isLibRoot = self.isLibraryDirectory(location)
                let maxDepth = isLibRoot ? 2 : 1
                self.processLocation(location, currentDepth: 0, maxDepth: maxDepth, isLibraryRootSearch: isLibRoot)
                group.leave()
            }
        }

        group.notify(queue: .global(qos: .userInitiated)) {
            let containers = self.discoverContainers()
            self.collectionQueue.sync {
                for (url, reason) in containers where self.collection[url] == nil {
                    self.collection[url] = reason
                }
            }
            self.applyConditions()
            let result = FinderResult(matches: self.filterSubpaths(self.collection),
                                      excluded: self.excluded)
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    // MARK: - Location Processing

    private func processLocation(_ location: String, currentDepth: Int, maxDepth: Int, isLibraryRootSearch: Bool) {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: location) else {
            return
        }

        var localResults: [(URL, MatchReason)] = []
        var subdirs: [URL] = []

        for item in contents {
            let itemURL = URL(fileURLWithPath: location).appendingPathComponent(item)
            let normalizedName: String

            if itemURL.hasDirectoryPath || itemURL.pathExtension.isEmpty {
                normalizedName = item.normalizedForMatching()
            } else {
                normalizedName = (item as NSString).deletingPathExtension.normalizedForMatching()
            }

            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: itemURL.path, isDirectory: &isDir) else { continue }

            if shouldSkipItem(normalizedName, at: itemURL) {
                // Only worth reporting when the item would otherwise have been
                // collected — a skip rule firing on an unrelated file is not
                // information, it's the rule doing its job silently.
                if rawMatch(normalizedName: normalizedName, itemURL: itemURL) != nil {
                    record(ExcludedItem(url: itemURL, rule: .systemSkipRule))
                }
                continue
            }

            if let reason = matchesApp(normalizedName: normalizedName, itemURL: itemURL) {
                let itemToAdd: URL
                var reasonToAdd = reason

                // For depth-2 matches in Library root, promote to the
                // parent directory ONLY when the parent itself matches the
                // app — that means the parent is a vendor folder belonging
                // to us (e.g. `~/Library/Application Support/PureMac/`).
                // If the parent is a third-party tool's container that
                // merely happens to contain a subfolder whose name
                // includes our app token (e.g.
                // `~/Library/Caches/claude-cli-nodejs/<encoded path>`),
                // promoting the parent would delete the third party's
                // entire cache. Add the leaf only in that case.
                if isLibraryRootSearch && currentDepth == 2 {
                    let parent = itemURL.deletingLastPathComponent()
                    let parentName = parent.lastPathComponent
                    let parentNormalized = parentName.normalizedForMatching()
                    let parentIsStandard = Locations.standardLibrarySubdirectories.contains(parentName)
                    let parentReason = matchesApp(normalizedName: parentNormalized, itemURL: parent)
                    if !parentIsStandard, let parentReason {
                        itemToAdd = parent
                        reasonToAdd = parentReason
                    } else {
                        itemToAdd = itemURL
                    }
                } else {
                    itemToAdd = itemURL
                }

                localResults.append((itemToAdd, reasonToAdd))
            }

            // Recurse into subdirectories up to maxDepth
            if isDir.boolValue && currentDepth < maxDepth {
                if isLibraryRootSearch && currentDepth == 0 {
                    if !skipDeepSearch.contains(itemURL.lastPathComponent) {
                        subdirs.append(itemURL)
                    }
                } else {
                    subdirs.append(itemURL)
                }
            }
        }

        collectionQueue.sync {
            for (url, reason) in localResults where collection[url] == nil {
                collection[url] = reason
            }
        }

        for subdir in subdirs {
            processLocation(subdir.path, currentDepth: currentDepth + 1, maxDepth: maxDepth, isLibraryRootSearch: isLibraryRootSearch)
        }
    }

    // MARK: - Matching Engine

    // Minimum token length required for a name-based match to pass. Prevents
    // a malicious app named "s-s-h" (normalized "ssh", 3 chars) from
    // short-name-bombing home dotfiles like ~/.ssh into the uninstall list.
    private static let minMatchTokenLength = 5

    /// Anchored check for whether `self.normalizedBundleID` belongs to the
    /// family identified by `conditionBundleID`. Accepts exact equality,
    /// ".child" extension, or "parent." suffix - rejects a bundle ID that
    /// merely contains the condition string as a substring. This prevents
    /// `com.evil.jetbrainsapp` from hijacking the `jetbrains` rule.
    private func bundleIDMatchesCondition(_ conditionBundleID: String) -> Bool {
        guard !conditionBundleID.isEmpty else { return false }
        if normalizedBundleID == conditionBundleID { return true }
        if normalizedBundleID.hasPrefix(conditionBundleID + ".") { return true }
        if normalizedBundleID.hasSuffix("." + conditionBundleID) { return true }
        return false
    }

    /// True for cache leaves whose name encodes a filesystem path —
    /// `-Users-nikolai-Projects-…-PureMac`, `-private-tmp-…`, etc. These
    /// belong to project-aware tools (Claude Code, Cursor, npm, pnpm,
    /// VSCode workspace storage) that key per-project caches by URL-
    /// encoded absolute path. A coincidental match (the path happens to
    /// contain our app's name as a directory component) is never a real
    /// signal of ownership — uninstalling app X must not delete tool Y's
    /// cache for project X.
    private static func looksLikeEncodedProjectPath(_ rawName: String) -> Bool {
        let lower = rawName.lowercased()
        let prefixes = ["-users-", "-private-", "-volumes-", "-applications-", "-system-", "-tmp-", "-var-"]
        if prefixes.contains(where: { lower.hasPrefix($0) }) { return true }
        // Many path-encoded names also have 4+ dash-separated components
        // (e.g. "users-nikolai-projects-puremac"). Only flag when the
        // first component is plausibly a top-level filesystem directory.
        let parts = lower.split(separator: "-")
        if parts.count >= 4,
           ["users", "private", "volumes", "applications", "system", "tmp", "var", "opt", "home"]
               .contains(String(parts[0])) {
            return true
        }
        return false
    }

    /// Multi-level heuristic matcher. Returns true if the normalized filename
    /// belongs to the target app at the current sensitivity level.
    private func matchesApp(normalizedName: String, itemURL: URL) -> MatchReason? {
        guard let reason = rawMatch(normalizedName: normalizedName, itemURL: itemURL) else { return nil }

        // Vetoes run after the ladder so a refusal can be reported with the
        // rule that caused it. Cache leaves shaped like encoded project paths
        // are never owned by a third-party app whose name happens to appear as
        // a path component.
        if AppPathFinder.looksLikeEncodedProjectPath(itemURL.lastPathComponent) {
            record(ExcludedItem(url: itemURL, rule: .encodedProjectPath))
            return nil
        }
        for condition in appConditions where bundleIDMatchesCondition(condition.bundleID) {
            if condition.excludeTerms.contains(where: { normalizedName.contains($0) }) {
                record(ExcludedItem(url: itemURL, rule: .appRuleExcludeTerm))
                return nil
            }
        }
        return reason
    }

    /// The matching ladder itself, with no vetoes applied.
    private func rawMatch(normalizedName: String, itemURL: URL) -> MatchReason? {
        // Per-app condition overrides take priority. Anchor the bundle ID
        // check (see bundleIDMatchesCondition above).
        for condition in appConditions where bundleIDMatchesCondition(condition.bundleID) {
            if condition.includeTerms.contains(where: { normalizedName.contains($0) }) {
                return .condition(condition.bundleID)
            }
        }

        // Entitlement-based matching
        for entitlement in normalizedEntitlements {
            let match = sensitivity == .strict
                ? normalizedName == entitlement
                : normalizedName.contains(entitlement)
            if match { return .entitlement }
        }

        // Level 1: Full bundle identifier
        let fullBundleMatch = normalizedName.contains(normalizedBundleID)

        // Level 2: App name
        let isStrict = sensitivity == .strict
        let minLen = AppPathFinder.minMatchTokenLength
        let appNameMatch = normalizedAppName.count >= minLen && (isStrict
            ? normalizedName == normalizedAppName
            : normalizedName.contains(normalizedAppName))

        // Level 3: Path component name (the .app directory name without extension)
        let pathMatch = pathComponentName.count >= minLen && (isStrict
            ? normalizedName == pathComponentName
            : normalizedName.contains(pathComponentName))

        // Level 4: Letters-only app name
        let lettersMatch = appNameLettersOnly.count >= minLen && (isStrict
            ? normalizedName == appNameLettersOnly
            : normalizedName.contains(appNameLettersOnly))

        if normalizedBundleID.count >= 5, fullBundleMatch { return .bundleIdentifier }
        if appNameMatch { return .appName }
        if pathMatch { return .bundleFileName }
        if lettersMatch { return .lettersOnlyName }

        // Enhanced mode: additional partial matching strategies
        if sensitivity != .strict {
            // Level 5: Last two bundle ID components
            if bundleLastTwo.count >= minLen, normalizedName.contains(bundleLastTwo) { return .bundleLastTwo }

            // Level 6: Base bundle ID (strips .helper/.agent/.daemon suffixes)
            if let base = baseBundleID, base.count >= minLen, normalizedName.contains(base) { return .baseBundleIdentifier }

            // Level 7: Version-stripped app name
            if let stripped = strippedAppName, stripped.count >= minLen, normalizedName.contains(stripped) { return .strippedAppName }
        }

        // Deep mode: broadest matching heuristics
        if sensitivity == .deep {
            // Level 8: Company name extracted from bundle ID
            if let company = companyName, company.count >= minLen, normalizedName.contains(company) { return .companyName }

            // Level 9: Team identifier from code signature
            if let teamID = normalizedTeamID, teamID.count >= minLen, normalizedName.contains(teamID) { return .teamIdentifier }
        }

        return nil
    }

    /// Exclusions are appended from the same parallel location walkers that
    /// fill `collection`, so they share its queue.
    private func record(_ item: ExcludedItem) {
        collectionQueue.sync {
            if !excluded.contains(item) { excluded.append(item) }
        }
    }

    // MARK: - Skip Logic

    private func shouldSkipItem(_ normalizedName: String, at url: URL) -> Bool {
        if collectionQueue.sync(execute: { collection[url] != nil }) { return true }

        for skip in skipConditions {
            for path in skip.skipPaths {
                if url.path.hasPrefix(path) { return true }
            }
            if skip.skipPrefixes.contains(where: { normalizedName.hasPrefix($0) }) {
                if !skip.allowPrefixes.contains(where: { normalizedName.hasPrefix($0) }) {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Container Discovery

    /// Discovers sandboxed app containers that belong to this app by checking
    /// both UUID-named containers (via metadata plist) and name-matched containers.
    private func discoverContainers() -> [(URL, MatchReason)] {
        var containers: [(URL, MatchReason)] = []

        guard let containersPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("Containers") else { return containers }

        guard let dirs = try? FileManager.default.contentsOfDirectory(
            at: containersPath, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
        ) else { return containers }

        for dir in dirs {
            let dirName = dir.lastPathComponent

            // UUID-named containers: read the metadata plist for the owning bundle ID
            if dirName.count == 36 && dirName.contains("-") {
                let metaPlist = dir.appendingPathComponent(".com.apple.containermanagerd.metadata.plist")
                if let meta = NSDictionary(contentsOf: metaPlist),
                   let bundleID = meta["MCMMetadataIdentifier"] as? String,
                   bundleID == appInfo.bundleIdentifier {
                    containers.append((dir, .containerMetadata))
                }
            }

            // Named containers matching the bundle ID directly. Require the
            // bundle ID itself to be at least 5 chars to avoid picking up a
            // container owned by an app with a degenerate bundle identifier.
            if normalizedBundleID.count >= 5,
               dirName.normalizedForMatching() == normalizedBundleID {
                containers.append((dir, .containerNamed))
            }
        }

        return containers
    }

    // MARK: - Condition Application

    /// Applies per-app force-include and force-exclude path overrides after
    /// the main scan has completed.
    private func applyConditions() {
        for condition in appConditions {
            guard bundleIDMatchesCondition(condition.bundleID) else { continue }
            if let paths = condition.forceIncludePaths {
                for path in paths {
                    if FileManager.default.fileExists(atPath: path.path) {
                        collection[path] = .forceIncludePath
                    }
                }
            }
            if let paths = condition.forceExcludePaths {
                for path in paths {
                    if collection.removeValue(forKey: path) != nil {
                        record(ExcludedItem(url: path, rule: .forceExcludePath))
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func isLibraryDirectory(_ location: String) -> Bool {
        location == "\(home)/Library" || location == "/Library"
    }

    /// Removes child paths when a parent is already in the set, and discards
    /// results that consist solely of a Trash item.
    private func filterSubpaths(_ found: [URL: MatchReason]) -> [URL: MatchReason] {
        let sorted = found
            .map { (url: $0.key.standardizedFileURL, reason: $0.value) }
            .sorted { $0.url.path < $1.url.path }
        var filtered: [(url: URL, reason: MatchReason)] = []

        for entry in sorted {
            // Remove any existing entries that are children of this URL
            filtered.removeAll { $0.url.path.hasPrefix(entry.url.path + "/") }

            // Only add if this URL is not a child of an existing entry
            if !filtered.contains(where: { entry.url.path.hasPrefix($0.url.path + "/") }) {
                filtered.append(entry)
            }
        }

        // A single result pointing into the Trash is not meaningful
        if filtered.count == 1, let first = filtered.first, first.url.path.contains(".Trash") {
            return [:]
        }

        return Dictionary(uniqueKeysWithValues: filtered.map { ($0.url, $0.reason) })
    }
}
