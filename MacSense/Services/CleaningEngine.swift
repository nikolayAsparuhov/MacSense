import Foundation

actor CleaningEngine {
    private let fileManager = FileManager.default

    struct CleaningResult {
        var freedSpace: Int64 = 0
        var itemsCleaned: Int = 0
        var errors: [String] = []
    }

    // MARK: - Public API

    func cleanItems(_ items: [CleanableItem], progressHandler: @Sendable (Double) -> Void) async -> CleaningResult {
        var result = CleaningResult()

        // Purgeable items are processed as one batch so we run the expensive
        // `tmutil` / `diskutil` calls only once, and so the freed-space delta
        // is measured around the entire purge rather than per-item (which
        // would credit the first item with everything and leave the rest
        // reporting zero).
        let purgeable = items.filter { $0.category == .purgeableSpace }
        // The "Reclaimable" virtual entry that scanDockerCache surfaces uses
        // the docker binary path as its sentinel — that path is outside the
        // safe-delete allow-list, so the file-deletion path silently skips
        // it. We treat it specially: invoke `docker system prune -af` and
        // measure the free-space delta. Identified by category + name prefix.
        let dockerPrune = items.filter {
            $0.category == .developerCaches && $0.subCategory == "Docker" && $0.name.hasPrefix("Reclaimable")
        }
        let fileBased = items.filter {
            $0.category != .purgeableSpace &&
            !($0.category == .developerCaches && $0.subCategory == "Docker" && $0.name.hasPrefix("Reclaimable"))
        }
        let total = max(1, purgeable.count + dockerPrune.count + fileBased.count)
        var processed = 0

        if !purgeable.isEmpty {
            let snapshotNames = purgeable
                .map(\.path)
                .filter { $0 != "/" && $0.contains("TimeMachine") }
            let purged = await purgePurgeableSpace(snapshotNames: snapshotNames)
            result.freedSpace += purged
            if purged > 0 {
                result.itemsCleaned += purgeable.count
            } else {
                // macOS chose not to release these bytes — happens when the
                // purgePurgeable call needs root (no privilege escalation),
                // or the kernel decides the bytes are still useful (no disk
                // pressure). Surface so the UI can tell the user the truth
                // instead of silently reporting "cleaned" while the next
                // scan re-finds the same purgeable bucket.
                result.errors.append("Purgeable space could not be released. macOS frees these bytes automatically under disk pressure, or run `sudo diskutil apfs purgePurgeable /` from Terminal to force it now.")
            }
            processed += purgeable.count
            progressHandler(Double(processed) / Double(total))
        }

        if let dockerItem = dockerPrune.first {
            // dockerItem.path holds the absolute path to the docker binary.
            let beforeFree = getCurrentFreeSpace()
            let success = await runDockerPrune(dockerBin: dockerItem.path)
            let afterFree = getCurrentFreeSpace()
            if success {
                result.freedSpace += max(0, afterFree - beforeFree)
                result.itemsCleaned += dockerPrune.count
            } else {
                result.errors.append("docker system prune failed — is Docker Desktop running?")
            }
            processed += dockerPrune.count
            progressHandler(Double(processed) / Double(total))
        }

        Logger.shared.log("cleanItems: starting fileBased loop, count=\(fileBased.count)", level: .info)
        for item in fileBased {
            processed += 1
            progressHandler(Double(processed) / Double(total))

            do {
                let itemURL = URL(fileURLWithPath: item.path)
                guard fileManager.fileExists(atPath: item.path) else {
                    Logger.shared.log("clean skip[missing]: \(item.path)", level: .warning)
                    result.errors.append("Missing: \(item.name) (\(item.path))")
                    continue
                }

                // Security: resolve symlinks, validate the real path, delete
                // through the resolved URL. Deleting through the unresolved
                // path lets an attacker-at-same-UID swap a component to a
                // symlink after the check and have us follow it.
                let resolvedURL = itemURL.resolvingSymlinksInPath()
                let resolved = resolvedURL.path

                let pathAccepted = isSafeToDelete(resolvedPath: resolved)
                guard pathAccepted else {
                    let msg = "Skipped (not on allow-list): \(item.path) -> \(resolved)"
                    Logger.shared.log("clean skip[allowlist]: \(item.path) resolved=\(resolved)", level: .warning)
                    result.errors.append(msg)
                    continue
                }

                // Narrow the TOCTOU window: re-resolve right before the delete
                // and require the resolved path to still match. Any concurrent
                // swap between check and delete aborts the operation.
                let reResolved = URL(fileURLWithPath: item.path).resolvingSymlinksInPath().path
                guard reResolved == resolved else {
                    let msg = "Aborting delete: path resolution changed for \(item.path)"
                    Logger.shared.log(msg, level: .warning)
                    result.errors.append(msg)
                    continue
                }

                try fileManager.removeItem(at: resolvedURL)
                Logger.shared.log("clean ok: \(resolved) freed=\(item.size)", level: .info)
                result.freedSpace += item.size
                result.itemsCleaned += 1
            } catch {
                Logger.shared.log("clean fail: \(item.path) error=\(error.localizedDescription)", level: .error)
                result.errors.append("\(item.name): \(error.localizedDescription)")
            }
        }
        Logger.shared.log("cleanItems: done freedSpace=\(result.freedSpace) cleaned=\(result.itemsCleaned) errors=\(result.errors.count)", level: .info)

        return result
    }

    func cleanCategory(_ result: CategoryResult, progressHandler: @Sendable (Double) -> Void) async -> CleaningResult {
        let selectedItems = result.items.filter { $0.isSelected }
        return await cleanItems(selectedItems, progressHandler: progressHandler)
    }

    // MARK: - Purgeable Space

    /// Reclaim purgeable disk space.
    ///
    /// - parameter snapshotNames: Local Time Machine snapshot names (e.g.
    ///   `com.apple.TimeMachine.2025-10-01-123456.local`) selected by the user
    ///   for explicit deletion. Each is deleted via
    ///   `tmutil deletelocalsnapshots <YYYY-MM-DD-HHMMSS>` before we ask the
    ///   kernel to thin remaining snapshots and release other purgeable space.
    ///
    /// Why three steps: `diskutil apfs purgePurgeable /` alone only frees
    /// what macOS already considers freeable AT THAT MOMENT — typically
    /// nothing unless under disk pressure. We need the explicit
    /// `deletelocalsnapshots` and `thinlocalsnapshots / <bytes> 4` (urgency 4
    /// = highest) to actually evict TM snapshots on demand.
    func purgePurgeableSpace(snapshotNames: [String] = []) async -> Int64 {
        let beforeFree = getCurrentFreeSpace()

        // 1. Explicit per-snapshot deletion for the rows the user selected.
        for name in snapshotNames {
            guard let date = Self.snapshotDate(from: name) else {
                Logger.shared.log("Unparseable snapshot name, skipped: \(name)", level: .warning)
                continue
            }
            runProcess(
                executable: "/usr/bin/tmutil",
                arguments: ["deletelocalsnapshots", date],
                label: "tmutil deletelocalsnapshots \(date)"
            )
        }

        // 2. Aggressive thin of any remaining local snapshots.
        //    Args: <volume> <purge_amount_bytes> <urgency 1-4>.
        //    1TB request + urgency 4 effectively means "evict everything you can".
        runProcess(
            executable: "/usr/bin/tmutil",
            arguments: ["thinlocalsnapshots", "/", "1000000000000", "4"],
            label: "tmutil thinlocalsnapshots /"
        )

        // 3. Ask APFS to release any other purgeable bytes (iCloud
        //    offloadable, system caches the kernel decides are evictable).
        runProcess(
            executable: "/usr/sbin/diskutil",
            arguments: ["apfs", "purgePurgeable", "/"],
            label: "diskutil apfs purgePurgeable /"
        )

        let afterFree = getCurrentFreeSpace()
        return max(0, afterFree - beforeFree)
    }

    /// Runs `docker system prune -af` to remove unused images, stopped
    /// containers, networks, and build cache. Does NOT pass `--volumes` —
    /// that's destructive of user data and the wrong default.
    ///
    /// Returns true if the binary executed cleanly (exit 0). False means
    /// Docker Desktop isn't running, the binary doesn't exist, or prune
    /// itself errored.
    private func runDockerPrune(dockerBin: String) async -> Bool {
        guard fileManager.fileExists(atPath: dockerBin) else {
            Logger.shared.log("docker binary not found at \(dockerBin)", level: .warning)
            return false
        }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: dockerBin)
        task.arguments = ["system", "prune", "-af"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus != 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let msg = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                Logger.shared.log("docker prune exited \(task.terminationStatus): \(msg)", level: .warning)
                return false
            }
            return true
        } catch {
            Logger.shared.log("docker prune spawn failed: \(error.localizedDescription)", level: .warning)
            return false
        }
    }

    private func runProcess(executable: String, arguments: [String], label: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = arguments
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus != 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                Logger.shared.log("\(label) exited \(task.terminationStatus): \(output)", level: .warning)
            }
        } catch {
            Logger.shared.log("\(label) failed to launch: \(error.localizedDescription)", level: .error)
        }
    }

    /// Extract the `YYYY-MM-DD-HHMMSS` date string from a snapshot name like
    /// `com.apple.TimeMachine.2025-10-01-123456.local` — that date string is
    /// the argument tmutil's `deletelocalsnapshots` accepts.
    private static func snapshotDate(from snapshotName: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"\d{4}-\d{2}-\d{2}-\d{6}"#) else { return nil }
        let range = NSRange(snapshotName.startIndex..., in: snapshotName)
        guard let match = regex.firstMatch(in: snapshotName, range: range),
              let r = Range(match.range, in: snapshotName) else { return nil }
        return String(snapshotName[r])
    }

    // MARK: - Trash

    func emptyTrash() async -> Int64 {
        let home = fileManager.homeDirectoryForCurrentUser.path
        let trashPath = "\(home)/.Trash"
        var totalFreed: Int64 = 0

        do {
            let contents = try fileManager.contentsOfDirectory(atPath: trashPath)
            for item in contents {
                let fullPath = (trashPath as NSString).appendingPathComponent(item)
                if let attrs = try? fileManager.attributesOfItem(atPath: fullPath) {
                    totalFreed += (attrs[.size] as? Int64) ?? 0
                }
                try fileManager.removeItem(atPath: fullPath)
            }
        } catch {
            Logger.shared.log("Trash cleanup incomplete: \(error.localizedDescription)", level: .warning)
        }

        return totalFreed
    }

    // MARK: - Helpers

    /// Validates that a resolved path is safe to delete.
    /// Prevents symlink attacks where a link in ~/Library/Caches points to ~/.ssh.
    /// Downloads, Documents, and Desktop are intentionally NOT whole-subtree
    /// allow-listed - scanLargeFiles emits per-file items instead, so those
    /// deletions can still happen through the explicit per-item flow.
    private func isSafeToDelete(resolvedPath: String) -> Bool {
        let home = fileManager.homeDirectoryForCurrentUser.path
        var allowedRoots = [
            "\(home)/Library/Caches",
            "\(home)/Library/Logs",
            "\(home)/Library/Saved Application State",
            "\(home)/Library/HTTPStorages",
            "\(home)/Library/WebKit",
            "\(home)/Library/Containers",
            "\(home)/Library/Group Containers",
            "\(home)/Library/Application Support",
            "\(home)/Library/Preferences",
            "\(home)/Library/LaunchAgents",
            "\(home)/Library/Mail Downloads",
            "\(home)/Library/Developer",
            "\(home)/.Trash",
            "/Library/Caches",
            "/Library/Logs",
            "/private/var/log",
            "/private/var/tmp",
            "/tmp",
            // Homebrew prefix-relative cache roots — covered explicitly so
            // the catalog/Brew scanner can clean Homebrew's download cache
            // when it lives under a non-default prefix.
            "/opt/homebrew/Library/Caches",
            "/usr/local/Homebrew/Library/Caches",
        ]
        // Append every dev-cache root from the catalog. The catalog is the
        // source of truth for what we offer to clean; if it lists a path,
        // the cleaner must be allowed to delete inside it (or to delete
        // the root itself, e.g. `~/.npm`).
        for tool in DevCacheCatalog.all {
            allowedRoots.append(contentsOf: tool.paths)
        }
        // Accept either an exact root match (delete the cache dir itself)
        // or a strict subpath (delete inside it). The trailing-"/" guard
        // on the subpath check still blocks siblings like "/tmpfoo".
        let normalized = (resolvedPath as NSString).standardizingPath
        return allowedRoots.contains { root in
            let normalizedRoot = (root as NSString).standardizingPath
            if normalized == normalizedRoot { return true }
            let rootWithSeparator = normalizedRoot.hasSuffix("/") ? normalizedRoot : normalizedRoot + "/"
            return normalized.hasPrefix(rootWithSeparator)
        }
    }

    /// Allow a single-file delete under Downloads/Documents/Desktop when it
    /// was explicitly surfaced by a scanner (e.g. scanLargeFiles). Whole-subtree
    /// deletion of those roots remains blocked.
    func isExplicitSingleFileDeletable(resolvedPath: String) -> Bool {
        let home = fileManager.homeDirectoryForCurrentUser.path
        let perFileRoots = [
            "\(home)/Downloads/",
            "\(home)/Documents/",
            "\(home)/Desktop/",
        ]
        let normalized = (resolvedPath as NSString).standardizingPath
        return perFileRoots.contains { normalized.hasPrefix($0) }
    }

    private func getCurrentFreeSpace() -> Int64 {
        do {
            let attrs = try fileManager.attributesOfFileSystem(forPath: "/")
            return (attrs[.systemFreeSize] as? Int64) ?? 0
        } catch {
            Logger.shared.log("Cannot read filesystem attributes: \(error.localizedDescription)", level: .warning)
            return 0
        }
    }
}
