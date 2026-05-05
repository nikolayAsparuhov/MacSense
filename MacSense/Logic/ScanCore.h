#ifndef SCAN_CORE_H
#define SCAN_CORE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Single entry produced by the walker. Kind: 0 = file, 1 = directory,
/// 2 = opaque package (.app, .bundle, .framework, .kext, .dSYM, etc.
/// The walker computes the package's recursive size but does not emit
/// any of its internal entries — matching CleanMyMac/DaisyDisk and
/// what Finder visually presents).
typedef struct {
    int32_t kind;
    int32_t parent_idx;     // index into entries[], -1 for roots
    int64_t size;            // logical bytes; for dirs this is the
                             // recursive total
    int64_t mtime_sec;       // unix epoch seconds
    uint32_t path_offset;    // byte offset into paths buffer
    uint32_t path_length;    // length excluding NUL terminator
    uint32_t name_offset;    // byte offset into paths buffer (inside path)
    uint32_t name_length;
    uint32_t child_count;    // number of immediate children (for dirs)
    uint32_t reserved;
} scan_entry_t;

typedef struct scan_result_s scan_result_t;

/// Walks the subtree rooted at `root_path` using N concurrent worker
/// threads, each calling `getattrlistbulk` on its assigned directory.
/// Returns a result handle; entries + paths buffer are accessible via
/// the accessor functions below. Caller must free with
/// `scan_result_free`.
///
/// Skips configured prefixes internally (Volumes, .fseventsd, etc.).
/// Hidden entries (`.foo`) are skipped.
scan_result_t *scan_run(const char *root_path, int n_threads);

/// Returns pointer to entries[] and writes its count to `*count_out`.
/// Pointer remains valid until `scan_result_free` is called.
const scan_entry_t *scan_result_entries(const scan_result_t *result, size_t *count_out);

/// Returns pointer to packed UTF-8 paths buffer. Each entry's path is
/// at `paths[entry.path_offset]`, length `entry.path_length`. NOT
/// NUL-terminated within the buffer — use the length.
const char *scan_result_paths(const scan_result_t *result);

/// Frees all memory associated with the result.
void scan_result_free(scan_result_t *result);

#ifdef __cplusplus
}
#endif

#endif /* SCAN_CORE_H */
