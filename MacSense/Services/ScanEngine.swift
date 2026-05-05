import Foundation

actor ScanEngine {
    private let fileManager = FileManager.default
    private let home = FileManager.default.homeDirectoryForCurrentUser.path

    private struct CleanupTarget {
        let name: String
        let path: String
    }

    // MARK: - Public API

    func scanCategory(_ category: CleaningCategory) async -> CategoryResult {
        switch category {
        case .systemJunk:       return scanSystemJunk()
        case .userCache:        return scanUserCache()
        case .trashBins:        return scanTrash()
        case .purgeableSpace:   return scanPurgeableSpace()
        case .developerCaches:  return scanDeveloperCaches()
        }
    }

    /// Roll up Xcode + Homebrew + Node + Docker caches into a single
    /// developer-caches bucket, tagging each item with `subCategory` so the
    /// detail view can group them by tool.
    private func scanDeveloperCaches() -> CategoryResult {
        var items: [CleanableItem] = []
        items.append(contentsOf: scanXcodeJunk().items.map { remap($0, sub: "Xcode") })
        items.append(contentsOf: scanBrewCache().items.map { remap($0, sub: "Homebrew") })
        items.append(contentsOf: scanNodeCache().items.map { remap($0, sub: "Node / npm / yarn / pnpm") })
        items.append(contentsOf: scanDockerCache().items.map { remap($0, sub: "Docker") })

        // Catalog-driven scan for the long tail (pip, NuGet, Maven,
        // Cargo, Go, Composer, Gradle, Coursier, etc.). Each catalog
        // entry's known cache paths are walked, sizes summed, and the
        // tool surfaces as a single row labeled with its name. Paths
        // already covered by the dedicated scanners above (Homebrew,
        // Docker, Node, Xcode) are excluded so we don't double-count.
        let alreadyCounted: Set<String> = [
            "npm", // dedicated scanNodeCache covers ~/.npm
        ]
        for tool in DevCacheCatalog.all where !alreadyCounted.contains(tool.id) {
            for path in tool.paths {
                guard fileManager.fileExists(atPath: path) else { continue }
                let size = directorySize(path: path)
                guard size > 0 else { continue }
                items.append(CleanableItem(
                    name: tool.displayName,
                    path: path,
                    size: size,
                    category: .developerCaches,
                    subCategory: tool.id,
                    explanation: tool.explanation,
                    isSelected: true,
                    lastModified: fileModDate(path: path)
                ))
            }
        }

        let total = items.reduce(0) { $0 + $1.size }
        return CategoryResult(category: .developerCaches, items: items, totalSize: total)
    }

    private func remap(_ item: CleanableItem, sub: String) -> CleanableItem {
        CleanableItem(
            name: item.name,
            path: item.path,
            size: item.size,
            category: .developerCaches,
            subCategory: sub,
            explanation: item.explanation,
            isSelected: item.isSelected,
            lastModified: item.lastModified
        )
    }

    func getDiskInfo() -> DiskInfo {
        var info = DiskInfo()
        do {
            let attrs = try fileManager.attributesOfFileSystem(forPath: "/")
            if let total = attrs[.systemSize] as? Int64 {
                info.totalSpace = total
            }
            if let free = attrs[.systemFreeSize] as? Int64 {
                info.freeSpace = free
            }
            info.usedSpace = info.totalSpace - info.freeSpace

            // Use URLResourceValues for accurate purgeable space detection
            let rootURL = URL(fileURLWithPath: "/")
            let values = try rootURL.resourceValues(forKeys: [
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeAvailableCapacityKey
            ])
            if let importantCapacity = values.volumeAvailableCapacityForImportantUsage,
               let freeCapacity = values.volumeAvailableCapacity {
                // Purgeable = important capacity (free + purgeable) minus actual free
                let purgeable = importantCapacity - Int64(freeCapacity)
                if purgeable > 10 * 1024 * 1024 { // Only report if > 10 MB
                    info.purgeableSpace = purgeable
                }
            }
        } catch {
            Logger.shared.log("Disk info unavailable: \(error.localizedDescription)", level: .warning)
        }
        return info
    }

    // MARK: - Scanners

    private func scanSystemJunk() -> CategoryResult {
        var items: [CleanableItem] = []
        var totalSize: Int64 = 0

        let systemPaths = [
            "/Library/Caches",
            "/Library/Logs",
            "/private/var/log",
            "\(home)/Library/Logs",
            "/tmp",
            "/private/var/tmp",
        ]

        for path in systemPaths {
            let scanned = scanDirectory(path: path, category: .systemJunk, recursive: true, maxDepth: 3)
            items.append(contentsOf: scanned)
        }

        totalSize = items.reduce(0) { $0 + $1.size }
        return CategoryResult(category: .systemJunk, items: items, totalSize: totalSize)
    }

    private func scanUserCache() -> CategoryResult {
        var items: [CleanableItem] = []
        // Only exclude Homebrew since it has its own dedicated scan category
        let excludedRootPaths = Set([
            "\(home)/Library/Caches/Homebrew",
        ].map(normalizePath))

        // Dynamically enumerate ~/Library/Caches/ so every subdirectory is visible
        let cachePath = "\(home)/Library/Caches"
        let scanned = scanDirectory(
            path: cachePath,
            category: .userCache,
            recursive: false,
            maxDepth: 1,
            excluding: excludedRootPaths
        )
        items.append(contentsOf: scanned)

        // Also scan for npm/pip/yarn caches
        let devCaches = [
            "\(home)/.npm/_cacache",
            "\(home)/.cache/pip",
            "\(home)/.cache/yarn",
            "\(home)/.cache/pnpm",
            "\(home)/Library/Caches/pip",
        ]

        for path in devCaches {
            if let item = makeCleanupItem(
                name: URL(fileURLWithPath: path).lastPathComponent,
                path: path,
                category: .userCache
            ) {
                items.append(item)
            }
        }

        let uniqueItems = deduplicatedItems(items)
        let totalSize = uniqueItems.reduce(0) { $0 + $1.size }
        return CategoryResult(category: .userCache, items: uniqueItems, totalSize: totalSize)
    }

    private func scanTrash() -> CategoryResult {
        var items: [CleanableItem] = []

        let trashPath = "\(home)/.Trash"
        let scanned = scanDirectory(path: trashPath, category: .trashBins, recursive: false, maxDepth: 1)
        items.append(contentsOf: scanned)

        let totalSize = items.reduce(0) { $0 + $1.size }
        return CategoryResult(category: .trashBins, items: items, totalSize: totalSize)
    }

    private func scanPurgeableSpace() -> CategoryResult {
        var items: [CleanableItem] = []
        var accounted: Int64 = 0

        // 1. Local Time Machine snapshots — deletable on demand via
        //    `tmutil deletelocalsnapshots <date>`.
        for snapshot in getLocalSnapshots() {
            let size = max(0, snapshot.size)
            accounted += size
            items.append(CleanableItem(
                name: "Time Machine local snapshot · \(snapshot.name)",
                path: snapshot.name,
                size: size,
                category: .purgeableSpace,
                explanation: "Frozen point-in-time copy of your disk that Time Machine keeps locally between backups. Removing it doesn't affect your external Time Machine backup.",
                isSelected: true,
                lastModified: snapshot.date
            ))
        }

        // 2. Top-level iCloud Drive containers with offloaded (not-downloaded)
        //    items. Each container is grouped into one row showing the bytes
        //    macOS is keeping evictable for that app/vendor. Rolling up by
        //    container avoids generating 10,000 individual placeholder rows
        //    on heavy iCloud users.
        for item in scanICloudOffloadable() {
            accounted += item.size
            items.append(item)
        }

        // 3. Sleepimage / VM swap. Owned by root, listed for visibility only —
        //    cannot be deleted from user space. macOS rebuilds them.
        for item in scanVMFiles() {
            accounted += item.size
            items.append(item)
        }

        // 4. System-managed remainder. macOS does not expose what's inside
        //    the rest of the purgeable bucket via any public API: dyld cache,
        //    Spotlight index, log archives, document revisions, etc. We can
        //    ask the kernel to release it via `diskutil apfs purgePurgeable /`
        //    + `tmutil thinlocalsnapshots / 1TB 4`, but the kernel only
        //    complies when it sees disk pressure.
        let totalPurgeable = getDiskInfo().purgeableSpace
        let remainder = totalPurgeable - accounted
        if remainder > 10 * 1024 * 1024 {
            items.append(CleanableItem(
                name: "Reclaimable system caches",
                path: "/",
                size: remainder,
                category: .purgeableSpace,
                explanation: "macOS-managed bucket that includes dyld shared cache, Spotlight indexes, log archives, document revisions, and Photos cache. The kernel normally only releases this on disk pressure; cleaning forces an immediate release. Safe — files regenerate as needed.",
                isSelected: true,
                lastModified: nil
            ))
        }

        let totalSize = items.reduce(0) { $0 + $1.size }
        return CategoryResult(category: .purgeableSpace, items: items, totalSize: totalSize)
    }

    /// Walks `~/Library/Mobile Documents` and rolls up bytes of files that
    /// are evictable iCloud placeholders (downloaded == false). Grouped by
    /// top-level container directory so we get one row per app/vendor
    /// instead of thousands of placeholder files.
    private func scanICloudOffloadable() -> [CleanableItem] {
        let root = "\(home)/Library/Mobile Documents"
        guard fileManager.fileExists(atPath: root) else { return [] }

        var perContainer: [String: (size: Int64, lastModified: Date?)] = [:]
        let rootURL = URL(fileURLWithPath: root)
        let keys: [URLResourceKey] = [
            .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey,
            .totalFileAllocatedSizeKey,
            .fileSizeKey,
            .contentModificationDateKey,
        ]
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var visited = 0
        for case let fileURL as URL in enumerator {
            visited += 1
            if visited > 200_000 { break }

            guard let v = try? fileURL.resourceValues(forKeys: Set(keys)),
                  v.isUbiquitousItem == true,
                  v.ubiquitousItemDownloadingStatus == .notDownloaded else { continue }

            let size = Int64(v.totalFileAllocatedSize ?? v.fileSize ?? 0)
            guard size > 0 else { continue }

            // Top-level container: ~/Library/Mobile Documents/<container>/...
            let relative = fileURL.path.dropFirst(root.count + 1)
            let container = String(relative.split(separator: "/").first ?? "iCloud")
            let prev = perContainer[container] ?? (0, nil)
            let mostRecent = [prev.lastModified, v.contentModificationDate]
                .compactMap { $0 }
                .max()
            perContainer[container] = (prev.size + size, mostRecent)
        }

        return perContainer.map { container, value in
            // Render container name like "com.apple.CloudDocs" -> "iCloud Drive (com.apple.CloudDocs)"
            // (the underscore-tilde-tilde format used on disk is how iCloud
            // namespaces apps; show it raw so the user can find the source).
            CleanableItem(
                name: "iCloud Drive offloaded files · \(container.replacingOccurrences(of: "~", with: "."))",
                path: "\(root)/\(container)",
                size: value.size,
                category: .purgeableSpace,
                explanation: "Files this app stores in iCloud Drive that aren't currently downloaded. macOS counts the cloud copy as purgeable. Removing a placeholder DELETES the file from iCloud Drive — not just from this Mac. Not selected by default for that reason.",
                // Not auto-selected: deleting a placeholder removes the file
                // from iCloud Drive entirely, not just locally.
                isSelected: false,
                lastModified: value.lastModified
            )
        }
        .sorted { $0.size > $1.size }
    }

    /// Stat sleepimage + swap files. They're root-owned, so we can read the
    /// inode metadata (size + mtime) but cannot delete them from user space —
    /// surfaced for visibility only, not selected by default.
    private func scanVMFiles() -> [CleanableItem] {
        let vmDir = "/private/var/vm"
        guard let contents = try? fileManager.contentsOfDirectory(atPath: vmDir) else { return [] }

        var items: [CleanableItem] = []
        for name in contents where name == "sleepimage" || name.hasPrefix("swapfile") {
            let path = "\(vmDir)/\(name)"
            guard let attrs = try? fileManager.attributesOfItem(atPath: path),
                  let size = attrs[.size] as? Int64, size > 0 else { continue }

            let displayName: String
            let explanation: String
            if name == "sleepimage" {
                displayName = "Sleep image (memory dump for hibernation)"
                explanation = "Snapshot of your Mac's RAM written to disk so the system can restore state after a deep sleep / power loss. Owned by root — listed for visibility only; macOS rebuilds it on next sleep."
            } else {
                displayName = "Swap file · \(name)"
                explanation = "Virtual memory paged out by the kernel when RAM is tight. Owned by root — listed for visibility only; macOS manages these automatically."
            }

            items.append(CleanableItem(
                name: displayName,
                path: path,
                size: size,
                category: .purgeableSpace,
                explanation: explanation,
                isSelected: false,
                lastModified: attrs[.modificationDate] as? Date
            ))
        }
        return items
    }

    private func scanXcodeJunk() -> CategoryResult {
        var items: [CleanableItem] = []

        let xcodePaths = [
            "\(home)/Library/Developer/Xcode/DerivedData",
            "\(home)/Library/Developer/Xcode/Archives",
            "\(home)/Library/Developer/CoreSimulator/Caches",
            "\(home)/Library/Caches/com.apple.dt.Xcode",
        ]

        for path in xcodePaths {
            if fileManager.fileExists(atPath: path) {
                let size = directorySize(path: path)
                if size > 0 {
                    items.append(CleanableItem(
                        name: URL(fileURLWithPath: path).lastPathComponent,
                        path: path,
                        size: size,
                        category: .developerCaches,
                        isSelected: true,
                        lastModified: nil
                    ))
                }
            }
        }

        let totalSize = items.reduce(0) { $0 + $1.size }
        return CategoryResult(category: .developerCaches, items: items, totalSize: totalSize)
    }

    private func scanBrewCache() -> CategoryResult {
        var items: [CleanableItem] = []

        // Default Homebrew download cache
        var brewCachePaths = [
            "\(home)/Library/Caches/Homebrew",
        ]

        // Known-good Homebrew cache roots. Any path returned by `brew --cache`
        // that is NOT inside one of these is refused - prevents an attacker
        // setting HOMEBREW_CACHE=$HOME/Documents from steering our cleanup.
        let knownBrewRoots = [
            "\(home)/Library/Caches/Homebrew",
            "/opt/homebrew/Library/Caches",
            "/usr/local/Homebrew/Library/Caches",
            "/Library/Caches/Homebrew",
        ]

        // Detect custom HOMEBREW_CACHE via `brew --cache`. Strip HOMEBREW_*
        // from the child env so an attacker can't steer the output via
        // launchctl setenv, then validate the output against knownBrewRoots.
        let brewBinPaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        var detectedCustomCache = false
        for brewBin in brewBinPaths {
            guard fileManager.fileExists(atPath: brewBin) else { continue }
            let task = Process()
            task.executableURL = URL(fileURLWithPath: brewBin)
            task.arguments = ["--cache"]
            var sanitizedEnv = ProcessInfo.processInfo.environment
            for key in Array(sanitizedEnv.keys) where key.hasPrefix("HOMEBREW_") {
                sanitizedEnv.removeValue(forKey: key)
            }
            task.environment = sanitizedEnv
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()
            do {
                try task.run()
                task.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !output.isEmpty {
                    let normalized = normalizePath(output)
                    let isKnown = knownBrewRoots.contains { root in
                        normalized == root || normalized.hasPrefix(root + "/")
                    }
                    guard isKnown else {
                        Logger.shared.log("Refusing suspicious brew cache path: \(output)", level: .warning)
                        break
                    }
                    if !brewCachePaths.map(normalizePath).contains(normalized) {
                        brewCachePaths.append(output)
                    }
                    detectedCustomCache = true
                }
            } catch {
                Logger.shared.log("Failed to run \(brewBin) --cache: \(error.localizedDescription)", level: .warning)
            }
            break // Only need the first available brew binary
        }

        if !detectedCustomCache {
            Logger.shared.log("Homebrew not found at standard paths; scanning default cache location only", level: .info)
        }

        for path in brewCachePaths {
            if fileManager.fileExists(atPath: path) {
                let size = directorySize(path: path)
                if size > 0 {
                    items.append(CleanableItem(
                        name: URL(fileURLWithPath: path).lastPathComponent,
                        path: path,
                        size: size,
                        category: .developerCaches,
                        isSelected: true,
                        lastModified: nil
                    ))
                }
            }
        }

        let totalSize = items.reduce(0) { $0 + $1.size }
        return CategoryResult(category: .developerCaches, items: items, totalSize: totalSize)
    }

    private func scanNodeCache() -> CategoryResult {
        // Each entry is `(displayName, defaultPath, optional CLI for cache-dir
        // detection)`. The CLI invocation overrides `defaultPath` if the user
        // has set a custom location (e.g. via `npm config set cache`).
        struct ManagerCache {
            let name: String
            let defaultPath: String
            let detectionCommand: (cli: String, args: [String])?
        }

        let managers: [ManagerCache] = [
            ManagerCache(
                name: "npm cache",
                defaultPath: "\(home)/.npm",
                detectionCommand: (cli: "npm", args: ["config", "get", "cache"])
            ),
            ManagerCache(
                name: "yarn classic cache",
                defaultPath: "\(home)/Library/Caches/Yarn",
                detectionCommand: (cli: "yarn", args: ["cache", "dir"])
            ),
            // Yarn Berry / v2+ uses a per-project .yarn/cache. We don't try to
            // chase those — they're inside user projects and shouldn't be
            // touched by a system cleaner. The classic cache above remains the
            // global, safe-to-clean location.
            ManagerCache(
                name: "pnpm content-addressable store",
                defaultPath: "\(home)/Library/pnpm/store",
                detectionCommand: (cli: "pnpm", args: ["store", "path"])
            ),
        ]

        var items: [CleanableItem] = []

        // Common $PATH locations on macOS where these CLIs land.
        let cliSearchPaths = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "\(home)/.local/bin",
            "\(home)/.volta/bin",
            "\(home)/.nvm/versions/node",
        ]

        for manager in managers {
            var paths: [String] = []
            paths.append(manager.defaultPath)

            if let cmd = manager.detectionCommand,
               let cliPath = locateExecutable(named: cmd.cli, searchPaths: cliSearchPaths),
               let detected = runCommandReadingStdout(executable: cliPath, args: cmd.args) {
                let normalized = detected.trimmingCharacters(in: .whitespacesAndNewlines)
                if !normalized.isEmpty,
                   !paths.map(normalizePath).contains(normalizePath(normalized)) {
                    paths.append(normalized)
                }
            }

            for path in paths {
                guard fileManager.fileExists(atPath: path) else { continue }
                let size = directorySize(path: path)
                guard size > 0 else { continue }
                items.append(CleanableItem(
                    name: manager.name,
                    path: path,
                    size: size,
                    category: .developerCaches,
                    isSelected: true,
                    lastModified: nil
                ))
            }
        }

        let totalSize = items.reduce(0) { $0 + $1.size }
        return CategoryResult(category: .developerCaches, items: items, totalSize: totalSize)
    }

    // -- Process helpers (used by scanNodeCache) --

    private func locateExecutable(named name: String, searchPaths: [String]) -> String? {
        for dir in searchPaths {
            let candidate = (dir as NSString).appendingPathComponent(name)
            if fileManager.isExecutableFile(atPath: candidate) {
                return candidate
            }
            // For nvm: ~/.nvm/versions/node/<version>/bin/<name>
            if dir.hasSuffix("/.nvm/versions/node"),
               let versions = try? fileManager.contentsOfDirectory(atPath: dir) {
                for v in versions {
                    let nested = (dir as NSString).appendingPathComponent("\(v)/bin/\(name)")
                    if fileManager.isExecutableFile(atPath: nested) {
                        return nested
                    }
                }
            }
        }
        return nil
    }

    private func runCommandReadingStdout(executable: String, args: [String]) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            Logger.shared.log("\(executable) \(args.joined(separator: " ")) failed: \(error.localizedDescription)", level: .warning)
            return nil
        }
        guard task.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }

    private func scanDockerCache() -> CategoryResult {
        var items: [CleanableItem] = []

        // Docker Desktop on macOS keeps its VM disk + caches under
        // ~/Library/Containers/com.docker.docker/Data. The caches we
        // surface here are *recoverable* — they will be regenerated by
        // Docker on next pull/build, and `docker system prune` is the
        // CLI equivalent of cleaning them.
        let dockerDataDirs = [
            // Build cache (BuildKit), per-user
            "\(home)/Library/Containers/com.docker.docker/Data/cache",
            // Vmnetd / vpnkit log + telemetry caches
            "\(home)/Library/Containers/com.docker.docker/Data/log",
            "\(home)/Library/Containers/com.docker.docker/Data/tmp",
            // Group containers caches (Docker Desktop helper apps)
            "\(home)/Library/Group Containers/group.com.docker/Caches",
            // CLI plugin download cache
            "\(home)/.docker/cli-plugins/.cache",
            // Buildx / containerd inline cache
            "\(home)/.docker/buildx/cache",
        ]

        for path in dockerDataDirs {
            guard fileManager.fileExists(atPath: path) else { continue }
            let size = directorySize(path: path)
            guard size > 0 else { continue }
            items.append(CleanableItem(
                name: URL(fileURLWithPath: path).lastPathComponent,
                path: path,
                size: size,
                category: .developerCaches,
                isSelected: true,
                lastModified: nil
            ))
        }

        // If the `docker` CLI is available, surface reclaimable space
        // reported by `docker system df` as a single virtual entry.
        // We don't try to delete it directly — the user runs
        // `docker system prune` themselves, which is the safe path.
        // We just show how much they can recover.
        let dockerBinPaths = ["/usr/local/bin/docker", "/opt/homebrew/bin/docker"]
        for dockerBin in dockerBinPaths where fileManager.fileExists(atPath: dockerBin) {
            if let reclaimable = reclaimableDockerSpace(dockerBin: dockerBin), reclaimable > 0 {
                items.append(CleanableItem(
                    name: "Reclaimable (docker images, containers, build cache)",
                    path: dockerBin,
                    size: reclaimable,
                    category: .developerCaches,
                    isSelected: true,
                    lastModified: nil
                ))
            }
            break
        }

        let totalSize = items.reduce(0) { $0 + $1.size }
        return CategoryResult(category: .developerCaches, items: items, totalSize: totalSize)
    }

    /// Sum the reclaimable bytes reported by `docker system df --format json`.
    /// Returns nil when Docker isn't running or the command fails — callers
    /// should treat that as "no reclaimable info available", not as an error.
    private func reclaimableDockerSpace(dockerBin: String) -> Int64? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: dockerBin)
        task.arguments = ["system", "df", "--format", "{{.Reclaimable}}"]
        let stdoutPipe = Pipe()
        task.standardOutput = stdoutPipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            Logger.shared.log("docker system df failed: \(error.localizedDescription)", level: .warning)
            return nil
        }
        guard task.terminationStatus == 0 else { return nil }
        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }
        // Each line looks like e.g. "1.234GB (45%)" — parse the leading number.
        var total: Int64 = 0
        for line in output.split(separator: "\n") {
            let raw = line.split(separator: " ").first.map(String.init) ?? ""
            if let bytes = parseHumanBytes(raw) {
                total += bytes
            }
        }
        return total
    }

    /// Parse Docker's compact size format ("1.23GB", "456MB", "789kB") into bytes.
    private func parseHumanBytes(_ s: String) -> Int64? {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let units: [(String, Double)] = [
            ("TB", 1_000_000_000_000),
            ("GB", 1_000_000_000),
            ("MB", 1_000_000),
            ("kB", 1_000),
            ("KB", 1_000),
            ("B", 1),
        ]
        for (suffix, multiplier) in units {
            if trimmed.hasSuffix(suffix) {
                let numberPart = String(trimmed.dropLast(suffix.count))
                if let value = Double(numberPart) {
                    return Int64(value * multiplier)
                }
            }
        }
        return nil
    }
    // MARK: - Helpers

    private func scanDirectory(
        path: String,
        category: CleaningCategory,
        recursive: Bool,
        maxDepth: Int,
        excluding excludedPaths: Set<String> = []
    ) -> [CleanableItem] {
        var items: [CleanableItem] = []

        guard fileManager.fileExists(atPath: path),
              fileManager.isReadableFile(atPath: path) else { return [] }

        do {
            let contents = try fileManager.contentsOfDirectory(atPath: path)
            for item in contents {
                let fullPath = (path as NSString).appendingPathComponent(item)
                if excludedPaths.contains(normalizePath(fullPath)) {
                    continue
                }

                var isDir: ObjCBool = false
                guard fileManager.fileExists(atPath: fullPath, isDirectory: &isDir) else { continue }

                // Security: skip symlinks to prevent symlink-following attacks
                if let attrs = try? fileManager.attributesOfItem(atPath: fullPath),
                   let fileType = attrs[.type] as? FileAttributeType,
                   fileType == .typeSymbolicLink {
                    continue
                }

                if isDir.boolValue {
                    let size = directorySize(path: fullPath)
                    if size > 1024 { // Skip tiny entries
                        items.append(CleanableItem(
                            name: item,
                            path: fullPath,
                            size: size,
                            category: category,
                            isSelected: true,
                            lastModified: fileModDate(path: fullPath)
                        ))
                    }
                } else {
                    if let attrs = try? fileManager.attributesOfItem(atPath: fullPath),
                       let size = attrs[.size] as? Int64, size > 1024 {
                        items.append(CleanableItem(
                            name: item,
                            path: fullPath,
                            size: size,
                            category: category,
                            isSelected: true,
                            lastModified: attrs[.modificationDate] as? Date
                        ))
                    }
                }
            }
        } catch {
            Logger.shared.log("Cannot enumerate \(path): \(error.localizedDescription)", level: .warning)
        }

        return items
    }

    private func makeCleanupItem(name: String, path: String, category: CleaningCategory) -> CleanableItem? {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
              fileManager.isReadableFile(atPath: path) else { return nil }

        if isDirectory.boolValue {
            let size = directorySize(path: path)
            guard size > 1024 else { return nil }
            return CleanableItem(
                name: name,
                path: path,
                size: size,
                category: category,
                isSelected: true,
                lastModified: fileModDate(path: path)
            )
        }

        guard let attrs = try? fileManager.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int64,
              size > 1024 else { return nil }

        return CleanableItem(
            name: name,
            path: path,
            size: size,
            category: category,
            isSelected: true,
            lastModified: attrs[.modificationDate] as? Date
        )
    }

    private func deduplicatedItems(_ items: [CleanableItem]) -> [CleanableItem] {
        var seenPaths: Set<String> = []
        var uniqueItems: [CleanableItem] = []

        for item in items {
            let normalizedPath = normalizePath(item.path)
            if seenPaths.insert(normalizedPath).inserted {
                uniqueItems.append(item)
            }
        }

        return uniqueItems
    }

    private func normalizePath(_ path: String) -> String {
        (path as NSString).standardizingPath
    }

    private func directorySize(path: String) -> Int64 {
        var totalSize: Int64 = 0

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var count = 0
        for case let fileURL as URL in enumerator {
            count += 1
            if count > 10000 { break } // Safety limit for very large directories

            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  let isFile = values.isRegularFile, isFile,
                  let size = values.fileSize else { continue }
            totalSize += Int64(size)
        }

        return totalSize
    }

    private func fileModDate(path: String) -> Date? {
        try? fileManager.attributesOfItem(atPath: path)[.modificationDate] as? Date
    }

    // MARK: - Purgeable Space Helpers

    struct SnapshotInfo {
        let name: String
        let size: Int64
        let date: Date?
    }

    /// Get local Time Machine snapshots and their sizes
    private func getLocalSnapshots() -> [SnapshotInfo] {
        var snapshots: [SnapshotInfo] = []

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
        task.arguments = ["listlocalsnapshots", "/"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [] }

            // Parse snapshot names (format: com.apple.TimeMachine.2026-04-08-123456.local)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"

            for line in output.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty, trimmed.contains("TimeMachine") else { continue }

                // Extract date from snapshot name
                var snapshotDate: Date?
                let parts = trimmed.components(separatedBy: ".")
                for part in parts {
                    if let date = dateFormatter.date(from: part) {
                        snapshotDate = date
                        break
                    }
                }

                // Get snapshot size via tmutil
                let sizeBytes = getSnapshotSize(name: trimmed)

                if sizeBytes > 0 {
                    snapshots.append(SnapshotInfo(
                        name: trimmed,
                        size: sizeBytes,
                        date: snapshotDate
                    ))
                }
            }
        } catch {
            Logger.shared.log("tmutil listlocalsnapshots failed: \(error.localizedDescription)", level: .info)
        }

        return snapshots
    }

    /// Get size of a specific local snapshot via APFS snapshot listing
    private func getSnapshotSize(name: String) -> Int64 {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        task.arguments = ["apfs", "listSnapshots", "/", "-plist"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                  let snapshots = plist["Snapshots"] as? [[String: Any]] else {
                Logger.shared.log("Could not parse APFS snapshot plist for \(name)", level: .info)
                return 0
            }

            for snapshot in snapshots {
                if let snapshotName = snapshot["SnapshotName"] as? String,
                   snapshotName == name,
                   let dataSize = snapshot["DataSize"] as? Int64 {
                    return dataSize
                }
            }

            Logger.shared.log("Snapshot \(name) not found in APFS listing", level: .info)
        } catch {
            Logger.shared.log("diskutil apfs listSnapshots failed: \(error.localizedDescription)", level: .warning)
        }

        return 0
    }

    /// Calculate total local snapshot size from disk usage difference
    private func getLocalSnapshotSize() -> Int64 {
        // The difference between "Volume Used Space" visible to the filesystem
        // and actual container usage can indicate snapshot overhead.
        // However, without root access, we can only check if tmutil reports snapshots.

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
        task.arguments = ["listlocalsnapshots", "/"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return 0 }

            let snapshotCount = output.components(separatedBy: "\n")
                .filter { $0.contains("TimeMachine") || $0.contains("com.apple") }
                .count

            if snapshotCount == 0 { return 0 }

            // Check if system reports purgeable via newer diskutil
            // On systems that support it, "Purgeable Space" appears in diskutil info
            let diskTask = Process()
            diskTask.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
            diskTask.arguments = ["info", "-plist", "/"]
            let diskPipe = Pipe()
            diskTask.standardOutput = diskPipe
            diskTask.standardError = Pipe()
            try diskTask.run()
            diskTask.waitUntilExit()

            let diskData = diskPipe.fileHandleForReading.readDataToEndOfFile()
            if let plist = try? PropertyListSerialization.propertyList(from: diskData, format: nil) as? [String: Any],
               let purgeable = plist["APFSContainerFree"] as? Int64,
               let volumeFree = plist["FreeSpace"] as? Int64 {
                // Purgeable is roughly the difference (snapshots that can be freed)
                let purgeableEstimate = max(0, volumeFree - purgeable)
                if purgeableEstimate > 10 * 1024 * 1024 { // Only report if > 10 MB
                    return purgeableEstimate
                }
            }
        } catch {
            Logger.shared.log("Purgeable space detection failed: \(error.localizedDescription)", level: .warning)
        }

        return 0
    }
}
