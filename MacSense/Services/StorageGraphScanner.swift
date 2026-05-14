import Foundation
import Darwin

/// Storage graph scanner backed by the C `scan_run` walker, which uses
/// 8 concurrent worker threads each driving `getattrlistbulk(2)` in
/// 128 KB batches. Per Apple engineer Quinn's guidance + Healey's
/// `dumac` benchmarks, this is the fastest available approach on
/// macOS — beating `fts(3)`, `enumeratorAtURL`, and any pure POSIX
/// equivalent by 3-5× on a multi-core Mac.
///
/// Packages (.app, .bundle, .framework, .kext, .dSYM, etc.) are
/// walked internally for size summation but emitted as a single
/// opaque entry — matches Finder/CleanMyMac/DaisyDisk behavior. Cuts
/// the entry count by 60-80% on a typical Mac.
actor StorageGraphScanner {
    /// Empirical sweet spot on M-series Macs: 12 threads gets ~95%
    /// of the available speedup over 8 threads while staying under
    /// the per-volume getattrlistbulk contention ceiling. Beyond 16
    /// the gains plateau and lock contention grows.
    private static let workerThreads: Int32 = 12
    /// Hard cap on file leaves surfaced per directory in the graph.
    /// `bucketSplit` in SizeTabView only renders the top 8 + an
    /// aggregate Other; keeping more was pure memory bloat.
    private static let filesPerDirCap = 8
    private static let topKPerType = 50
    /// Bound on `report.largeFiles` so a Mac with many big media files
    /// doesn't balloon the report. Top 500 by size is plenty for the
    /// LargeFilesSheet — anything beyond is noise.
    private static let largeFilesCap = 500
    private static let largeFileMin: Int64 = 100 * 1024 * 1024
    private static let oldFileMin:   Int64 = 10  * 1024 * 1024


    func build(at rootPath: String = "/") async -> (graph: StorageNode, report: StorageReport) {
        let cutoff = Calendar.current.date(byAdding: .year, value: -1, to: Date())

        // Run the C walker on a background thread so the actor isn't
        // blocked. Builds the Swift graph inline before freeing the C
        // result so we never hold both the C buffers AND a fully
        // materialized [RawEntry] (with Swift Strings) at once — that
        // peak roughly doubles memory on a deep scan.
        return await Task.detached(priority: .userInitiated) {
            Self.scanAndBuild(at: rootPath, cutoff: cutoff)
        }.value
    }

    // MARK: - C walker bridge

    /// Lightweight view onto the C walker's output. Holds only fixed-
    /// size fields; path and name are decoded lazily from the shared
    /// paths buffer when (and only if) the entry survives into the
    /// graph or a top-K heap.
    private struct LiteEntry {
        let kind: Int32       // 0 = file, 1 = dir, 2 = package
        let parentIdx: Int32
        let size: Int64
        let mtimeSec: Int64
        let pathOffset: UInt32
        let pathLength: UInt32
        let nameOffset: UInt32
        let nameLength: UInt32
    }

    private static func scanAndBuild(at rootPath: String, cutoff: Date?) -> (graph: StorageNode, report: StorageReport) {
        guard let resultPtr = rootPath.withCString({ scan_run($0, workerThreads) }) else {
            return (emptyRoot(rootPath), emptyReport())
        }
        defer { scan_result_free(resultPtr) }

        var count: size_t = 0
        guard let entriesPtr = scan_result_entries(resultPtr, &count), count > 0 else {
            return (emptyRoot(rootPath), emptyReport())
        }
        guard let pathsPtr = scan_result_paths(resultPtr) else {
            return (emptyRoot(rootPath), emptyReport())
        }

        // Materialize lite entries (no String allocations). Roughly
        // 40 bytes per entry vs ~150 bytes when holding Swift Strings
        // for path + name on top.
        var lites: [LiteEntry] = []
        lites.reserveCapacity(count)
        for i in 0..<count {
            let e = entriesPtr[i]
            lites.append(LiteEntry(
                kind: e.kind, parentIdx: e.parent_idx,
                size: e.size, mtimeSec: e.mtime_sec,
                pathOffset: e.path_offset, pathLength: e.path_length,
                nameOffset: e.name_offset, nameLength: e.name_length
            ))
        }

        return buildGraph(lites: lites, paths: pathsPtr, rootPath: rootPath, cutoff: cutoff)
    }

    private static func decodeString(_ paths: UnsafePointer<CChar>, offset: UInt32, length: UInt32) -> String {
        let buf = UnsafeBufferPointer(start: paths.advanced(by: Int(offset)), count: Int(length))
        return String(decoding: buf.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    /// Find the last `.` byte in the name slice without allocating a
    /// Swift String. Returns the lowercase extension as a Swift String
    /// — small allocation (typically ≤4 chars, fits inline in Swift's
    /// String small-string optimization).
    private static func extensionFor(paths: UnsafePointer<CChar>, nameOffset: UInt32, nameLength: UInt32) -> String {
        let len = Int(nameLength)
        guard len > 0 else { return "" }
        let start = paths.advanced(by: Int(nameOffset))
        var dotIdx = -1
        for i in stride(from: len - 1, through: 0, by: -1) {
            if start[i] == 0x2E /* '.' */ { dotIdx = i; break }
            if start[i] == 0x2F /* '/' */ { break }
        }
        guard dotIdx >= 0, dotIdx < len - 1 else { return "" }
        let extLen = len - dotIdx - 1
        let extStart = start.advanced(by: dotIdx + 1)
        let bytes = UnsafeBufferPointer(start: extStart, count: extLen)
        let raw = String(decoding: bytes.map { UInt8(bitPattern: $0) }, as: UTF8.self)
        return raw.lowercased()
    }

    // MARK: - Swift graph builder

    private static func buildGraph(lites: [LiteEntry], paths: UnsafePointer<CChar>,
                                   rootPath: String,
                                   cutoff: Date?) -> (graph: StorageNode, report: StorageReport) {
        guard !lites.isEmpty else {
            return (emptyRoot(rootPath), emptyReport())
        }

        // Group child indices by parent.
        var childrenByParent: [Int32: [Int]] = [:]
        for i in 0..<lites.count {
            let p = lites[i].parentIdx
            if p >= 0 {
                childrenByParent[p, default: []].append(i)
            }
        }

        // Type aggregates + top-K + large list — single pass over file
        // kind entries. Path/name decode is deferred until an entry
        // actually qualifies for a heap insert; the bulk-classify
        // step uses a pointer scan to find the extension without any
        // String allocation.
        var typeSizes: [MediaType: Int64] = [:]
        var typeCounts: [MediaType: Int] = [:]
        var topByType: [MediaType: TopKHeap] = [:]
        var largeHeap = TopKHeap(cap: largeFilesCap)

        for entry in lites {
            guard entry.kind == 0 else { continue }   // file only
            let size = entry.size
            if size <= 0 { continue }
            let ext = extensionFor(paths: paths, nameOffset: entry.nameOffset, nameLength: entry.nameLength)
            let type = MediaType.classify(extension: ext)
            typeSizes[type, default: 0] += size
            typeCounts[type, default: 0] += 1

            // Top-K per type — only allocate Strings when accepted.
            if topByType[type] == nil { topByType[type] = TopKHeap(cap: topKPerType) }
            if topByType[type]!.wouldAccept(size: size) {
                let name = decodeString(paths, offset: entry.nameOffset, length: entry.nameLength)
                let path = decodeString(paths, offset: entry.pathOffset, length: entry.pathLength)
                let item = CleanableItem(
                    name: name, path: path, size: size,
                    category: .userCache, subCategory: type.label,
                    isSelected: false,
                    lastModified: Date(timeIntervalSince1970: TimeInterval(entry.mtimeSec))
                )
                topByType[type]!.insert(item)
            }

            // Large/old detection. Bounded by `largeFilesCap` via heap
            // so a media-heavy Mac doesn't balloon the report.
            let isLarge = size >= largeFileMin
            let isOld: Bool = {
                guard let cutoff, size >= oldFileMin else { return false }
                let mtime = Date(timeIntervalSince1970: TimeInterval(entry.mtimeSec))
                return mtime < cutoff
            }()
            if (isLarge || isOld), largeHeap.wouldAccept(size: size) {
                let name = decodeString(paths, offset: entry.nameOffset, length: entry.nameLength)
                let path = decodeString(paths, offset: entry.pathOffset, length: entry.pathLength)
                let item = CleanableItem(
                    name: name, path: path, size: size,
                    category: .userCache, subCategory: type.label,
                    isSelected: false,
                    lastModified: Date(timeIntervalSince1970: TimeInterval(entry.mtimeSec))
                )
                largeHeap.insert(item)
            }
        }

        // Recursively materialize StorageNodes top-down. Root is index 0.
        let graph = makeNode(index: 0, lites: lites, paths: paths, childrenByParent: childrenByParent)

        // Synthetic "System" bucket — closes the gap between the
        // walker's user-actionable total and the actual disk used (as
        // reported by the OS). The walker deliberately skips Apple-
        // installed read-only content (/System, /Library/Frameworks-
        // adjacent system caches, /private/var/{db,folders,vm}, etc.)
        // because users can't act on it. Without this bucket the
        // graph total looks suspiciously low compared to "Storage" in
        // System Settings. CleanMyMac/DaisyDisk both surface a
        // similar synthesized bucket.
        var augmentedChildren = graph.children
        var augmentedSize = graph.size
        if rootPath == "/" {
            let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/")
            let total = (attrs?[.systemSize] as? Int64) ?? 0
            let free = (attrs?[.systemFreeSize] as? Int64) ?? 0
            let diskUsed = max(0, total - free)
            let gap = diskUsed - graph.size
            if gap > 1_000_000_000 {   // >1 GB worth — worth showing
                augmentedChildren.append(StorageNode(
                    path: "<system>",
                    name: "System",
                    size: gap,
                    isDirectory: false,
                    childCount: 0,
                    children: [],
                    isAggregateOther: true
                ))
                augmentedChildren.sort { $0.size > $1.size }
                augmentedSize = graph.size + gap
            }
        }

        let rootName = rootPath == "/" ? "Macintosh HD" : (rootPath as NSString).lastPathComponent
        let displayRoot = StorageNode(
            path: graph.path, name: rootName, size: augmentedSize,
            isDirectory: true, childCount: augmentedChildren.count,
            children: augmentedChildren
        )

        let breakdowns = MediaType.allCases.map { t in
            MediaBreakdown(type: t, totalSize: typeSizes[t] ?? 0, fileCount: typeCounts[t] ?? 0)
        }
        .sorted { $0.totalSize > $1.totalSize }
        let report = StorageReport(
            totalScanned: breakdowns.reduce(0) { $0 + $1.totalSize },
            breakdowns: breakdowns,
            largeFiles: largeHeap.sortedDescending(),
            filesByType: topByType.mapValues { $0.sortedDescending() },
            scannedAt: Date()
        )
        return (displayRoot, report)
    }

    private static func makeNode(index: Int, lites: [LiteEntry],
                                 paths: UnsafePointer<CChar>,
                                 childrenByParent: [Int32: [Int]]) -> StorageNode {
        let entry = lites[index]
        let isDir = entry.kind == 1

        // Files + packages are leaves.
        if !isDir {
            let name = decodeString(paths, offset: entry.nameOffset, length: entry.nameLength)
            let path = decodeString(paths, offset: entry.pathOffset, length: entry.pathLength)
            return StorageNode(
                path: path, name: name, size: entry.size,
                isDirectory: false, childCount: 0, children: []
            )
        }

        let childIndices = childrenByParent[Int32(index)] ?? []
        var subdirNodes: [StorageNode] = []
        // Tracks file children by index so we only materialize Swift
        // String storage for the ones that survive the per-dir cap.
        var fileIndices: [(idx: Int, size: Int64)] = []

        for ci in childIndices {
            let child = lites[ci]
            if child.kind == 1 {
                subdirNodes.append(makeNode(index: ci, lites: lites, paths: paths, childrenByParent: childrenByParent))
            } else {
                fileIndices.append((ci, child.size))
            }
        }

        // Cap per-directory file fan-out + roll long tail into "Other".
        fileIndices.sort { $0.size > $1.size }
        var children: [StorageNode] = subdirNodes
        let keptFiles = fileIndices.prefix(filesPerDirCap)
        for kept in keptFiles {
            children.append(makeNode(index: kept.idx, lites: lites, paths: paths, childrenByParent: childrenByParent))
        }

        let parentPath = decodeString(paths, offset: entry.pathOffset, length: entry.pathLength)
        let parentName = decodeString(paths, offset: entry.nameOffset, length: entry.nameLength)

        if fileIndices.count > filesPerDirCap {
            let tail = fileIndices.dropFirst(filesPerDirCap)
            let tailSize = tail.reduce(0) { $0 + $1.size }
            let tailCount = tail.count
            children.append(StorageNode(
                path: parentPath + "/<other-files>",
                name: "Other files (\(tailCount))",
                size: tailSize, isDirectory: false, childCount: 0,
                children: [], isAggregateOther: true
            ))
        }
        children.sort { $0.size > $1.size }

        return StorageNode(
            path: parentPath, name: parentName, size: entry.size,
            isDirectory: true, childCount: childIndices.count,
            children: children
        )
    }

    // MARK: - Empties

    private static func emptyRoot(_ path: String) -> StorageNode {
        StorageNode(path: path, name: path, size: 0, isDirectory: true, childCount: 0, children: [])
    }

    private static func emptyReport() -> StorageReport {
        StorageReport(
            totalScanned: 0,
            breakdowns: MediaType.allCases.map { MediaBreakdown(type: $0, totalSize: 0, fileCount: 0) },
            largeFiles: [], filesByType: [:], scannedAt: Date()
        )
    }
}
