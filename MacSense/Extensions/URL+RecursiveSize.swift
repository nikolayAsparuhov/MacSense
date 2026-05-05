import Foundation
import Darwin

extension URL {
    /// Sum of bytes for this URL on disk, recursing into directories.
    ///
    /// Uses POSIX `opendir` + `readdir` + `lstat` directly — far faster
    /// than `FileManager.enumerator` + `URLResourceValues`, which walks
    /// the same tree but pays Foundation overhead per file. On a tree
    /// the size of `/Users` (millions of files) the difference is 3-10×.
    ///
    /// Sums `st_blocks * 512` (allocated bytes on disk) rather than
    /// `st_size` (logical EOF). Without this, sparse files like
    /// OrbStack's `data.img.raw` report their virtual ceiling (8 TiB)
    /// instead of the few GB they actually occupy — making OrbStack and
    /// any other VM-host app explode in the Installed Apps total. This
    /// matches `du` and the C walker (which uses ATTR_FILE_ALLOCSIZE).
    ///
    /// Hidden entries (`.foo`) are skipped to match Finder's mental
    /// model. Symlinks are not followed (`lstat`, not `stat`) — du-style
    /// walk. SIP-protected paths silently return 0 because `opendir`
    /// returns NULL on EACCES; the inaccessible subtree contributes
    /// nothing rather than aborting the whole walk.
    func recursiveAllocatedSize() -> Int64 {
        var total: Int64 = 0
        var st = stat()
        guard lstat(path, &st) == 0 else { return 0 }
        if (st.st_mode & S_IFMT) == S_IFREG { return Int64(st.st_blocks) * 512 }
        if (st.st_mode & S_IFMT) != S_IFDIR { return 0 }

        // Iterative DFS; keeps stack memory bounded for deep trees.
        var stack: [String] = [path]
        while let cur = stack.popLast() {
            guard let dir = opendir(cur) else { continue }
            defer { closedir(dir) }
            while let entPtr = readdir(dir) {
                let ent = entPtr.pointee
                let name: String = withUnsafePointer(to: ent.d_name) { tuplePtr in
                    tuplePtr.withMemoryRebound(to: CChar.self, capacity: Int(ent.d_namlen) + 1) {
                        String(cString: $0)
                    }
                }
                if name.isEmpty || name == "." || name == ".." { continue }
                if name.hasPrefix(".") { continue }

                let child = cur + "/" + name
                // Fast-path on dirent's d_type to skip a stat for dirs;
                // for regular files we still need lstat for st_blocks
                // (d_type doesn't carry size information).
                switch Int32(ent.d_type) {
                case Int32(DT_REG):
                    var fs = stat()
                    if lstat(child, &fs) == 0 {
                        total += Int64(fs.st_blocks) * 512
                    }
                case Int32(DT_DIR):
                    stack.append(child)
                case Int32(DT_LNK):
                    // Skip symlinks — du-style walk.
                    continue
                default:
                    var fs = stat()
                    guard lstat(child, &fs) == 0 else { continue }
                    let mode = fs.st_mode & S_IFMT
                    if mode == S_IFREG { total += Int64(fs.st_blocks) * 512 }
                    else if mode == S_IFDIR { stack.append(child) }
                }
            }
        }
        return total
    }
}
