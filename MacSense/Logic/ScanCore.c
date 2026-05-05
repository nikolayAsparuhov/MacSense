#include "ScanCore.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/attr.h>
#include <sys/types.h>
#include <sys/vnode.h>
#include <fcntl.h>
#include <unistd.h>
#include <pthread.h>
#include <stdbool.h>

// =====================================================================
// Multi-threaded directory walker built on `getattrlistbulk(2)`.
//
// Per Apple engineer Quinn (forums.apple.com/forums/thread/776198):
// "Build and optimize entirely on getattrlistbulk. ... For large
// performance gains, use multiple threads making multiple calls
// into getattrlistbulk simultaneously."
//
// The walker maintains a work queue of directory paths. N pthread
// workers pull from the queue, call `getattrlistbulk` on each
// directory in 128 KB batches, classify each entry, and either
// enqueue subdirs or emit final entries to the result buffer.
//
// Packages (.app, .bundle, .framework, etc.) are walked internally
// for size summation but are emitted as a single opaque entry —
// matches Finder/CleanMyMac/DaisyDisk visual model.
//
// =====================================================================

// ---------------- Package extensions -------------------------------------

static const char *kPackageExtensions[] = {
    ".app", ".bundle", ".framework", ".kext", ".dSYM", ".plugin",
    ".driver", ".lproj", ".docset", ".photoslibrary", ".xpc",
    ".component", ".mdimporter", ".saver", ".prefPane",
    NULL,
};

static bool name_is_package(const char *name) {
    size_t name_len = strlen(name);
    for (int i = 0; kPackageExtensions[i]; i++) {
        size_t ext_len = strlen(kPackageExtensions[i]);
        if (name_len > ext_len &&
            memcmp(name + name_len - ext_len, kPackageExtensions[i], ext_len) == 0) {
            return true;
        }
    }
    return false;
}

// ---------------- Skip prefixes ------------------------------------------

// Skip /System and /Library/Frameworks — both are read-only Apple-
// installed and contain hundreds of thousands of bundled framework
// internals that the user can't act on. CleanMyMac/DaisyDisk treat
// these as opaque "macOS system" buckets. Re-include via opt-in if
// the user explicitly wants them counted.
static const char *kSkipPrefixes[] = {
    "/System",
    "/System/Volumes",   // firmlink target — content already counted via /Users etc
    "/Library/Frameworks",
    "/private/var/db",
    "/private/var/folders",
    "/private/var/vm",
    "/dev",
    "/Volumes",
    "/.fseventsd",
    "/.Spotlight-V100",
    "/.DocumentRevisions-V100",
    "/.MobileBackups",
    NULL,
};

static bool path_should_skip(const char *path) {
    for (int i = 0; kSkipPrefixes[i]; i++) {
        size_t plen = strlen(kSkipPrefixes[i]);
        if (strcmp(path, kSkipPrefixes[i]) == 0) return true;
        if (strncmp(path, kSkipPrefixes[i], plen) == 0 && path[plen] == '/') return true;
    }
    return false;
}

// ---------------- Inode dedup (disabled) ---------------------------------
//
// We tried hash-set dedup by (dev, file_id) but it produced totals
// significantly under what `du -sh` reports — APFS clones each have a
// unique inode, so the dedup wouldn't catch them anyway, and `du` makes
// no attempt to dedupe either. Removing the check brings the app's
// totals in line with `du -sh /path` output, which is what users
// expect when they sanity-check the scan in Terminal.
//
// Code kept here as historical reference; not called.

// ---------------- Result buffer ------------------------------------------

struct scan_result_s {
    scan_entry_t *entries;
    size_t entry_count;
    size_t entry_capacity;

    char *paths;
    size_t paths_size;
    size_t paths_capacity;

    pthread_mutex_t mu;
};

static scan_result_t *result_new(void) {
    scan_result_t *r = calloc(1, sizeof(*r));
    r->entry_capacity = 4096;
    r->entries = malloc(r->entry_capacity * sizeof(scan_entry_t));
    r->paths_capacity = 64 * 1024;
    r->paths = malloc(r->paths_capacity);
    pthread_mutex_init(&r->mu, NULL);
    return r;
}

void scan_result_free(scan_result_t *r) {
    if (!r) return;
    pthread_mutex_destroy(&r->mu);
    free(r->entries);
    free(r->paths);
    free(r);
}

const scan_entry_t *scan_result_entries(const scan_result_t *r, size_t *count_out) {
    *count_out = r->entry_count;
    return r->entries;
}

const char *scan_result_paths(const scan_result_t *r) {
    return r->paths;
}

// Append path bytes to the paths buffer, return offset.
static uint32_t result_intern_path(scan_result_t *r, const char *path, size_t len) {
    if (r->paths_size + len > r->paths_capacity) {
        size_t new_cap = r->paths_capacity * 2;
        while (r->paths_size + len > new_cap) new_cap *= 2;
        r->paths = realloc(r->paths, new_cap);
        r->paths_capacity = new_cap;
    }
    uint32_t offset = (uint32_t)r->paths_size;
    memcpy(r->paths + offset, path, len);
    r->paths_size += len;
    return offset;
}

// Reserve an entry slot, return its index. Caller fills fields.
static int32_t result_alloc_entry(scan_result_t *r) {
    if (r->entry_count >= r->entry_capacity) {
        r->entry_capacity *= 2;
        r->entries = realloc(r->entries, r->entry_capacity * sizeof(scan_entry_t));
    }
    int32_t idx = (int32_t)r->entry_count;
    r->entry_count++;
    memset(&r->entries[idx], 0, sizeof(scan_entry_t));
    return idx;
}

// ---------------- Work queue ---------------------------------------------

typedef enum {
    WALK_NORMAL = 0,        // emit entries + enqueue subdirs
    WALK_LEAF_SUM = 1,      // sum sizes only, accumulate into target_idx
} walk_kind_t;

typedef struct {
    char *path;
    int32_t parent_idx;     // normal: parent entry idx; leaf: target entry idx
    int parent_path_len;
    walk_kind_t kind;
} work_item_t;

typedef struct {
    work_item_t *items;
    size_t head, tail, capacity;
    int pending;
    int done;
    pthread_mutex_t mu;
    pthread_cond_t cv;
} work_queue_t;

static void wq_init(work_queue_t *q, size_t cap) {
    q->items = malloc(cap * sizeof(work_item_t));
    q->head = q->tail = 0;
    q->capacity = cap;
    q->pending = 0;
    q->done = 0;
    pthread_mutex_init(&q->mu, NULL);
    pthread_cond_init(&q->cv, NULL);
}

static void wq_destroy(work_queue_t *q) {
    free(q->items);
    pthread_mutex_destroy(&q->mu);
    pthread_cond_destroy(&q->cv);
}

static void wq_grow_locked(work_queue_t *q) {
    size_t new_cap = q->capacity * 2;
    work_item_t *nb = malloc(new_cap * sizeof(work_item_t));
    size_t n = q->tail - q->head;
    for (size_t i = 0; i < n; i++) {
        nb[i] = q->items[(q->head + i) % q->capacity];
    }
    free(q->items);
    q->items = nb;
    q->head = 0;
    q->tail = n;
    q->capacity = new_cap;
}

static void wq_push(work_queue_t *q, const char *path, int32_t parent_idx, int parent_path_len) {
    pthread_mutex_lock(&q->mu);
    if (q->tail - q->head >= q->capacity) {
        wq_grow_locked(q);
    }
    work_item_t *it = &q->items[q->tail % q->capacity];
    it->path = strdup(path);
    it->parent_idx = parent_idx;
    it->parent_path_len = parent_path_len;
    it->kind = WALK_NORMAL;
    q->tail++;
    q->pending++;
    pthread_cond_signal(&q->cv);
    pthread_mutex_unlock(&q->mu);
}

/// Enqueue a leaf-sum walk (used for opaque packages — workers walk
/// the package internally, summing sizes onto entries[target_idx]).
static void wq_push_leaf(work_queue_t *q, const char *path, int32_t target_idx) {
    pthread_mutex_lock(&q->mu);
    if (q->tail - q->head >= q->capacity) {
        wq_grow_locked(q);
    }
    work_item_t *it = &q->items[q->tail % q->capacity];
    it->path = strdup(path);
    it->parent_idx = target_idx;
    it->parent_path_len = 0;
    it->kind = WALK_LEAF_SUM;
    q->tail++;
    q->pending++;
    pthread_cond_signal(&q->cv);
    pthread_mutex_unlock(&q->mu);
}

static bool wq_pop(work_queue_t *q, work_item_t *out) {
    pthread_mutex_lock(&q->mu);
    while (q->head == q->tail && !q->done) {
        if (q->pending == 0) {
            q->done = 1;
            pthread_cond_broadcast(&q->cv);
            pthread_mutex_unlock(&q->mu);
            return false;
        }
        pthread_cond_wait(&q->cv, &q->mu);
    }
    if (q->done && q->head == q->tail) {
        pthread_mutex_unlock(&q->mu);
        return false;
    }
    *out = q->items[q->head % q->capacity];
    q->head++;
    pthread_mutex_unlock(&q->mu);
    return true;
}

static void wq_task_done(work_queue_t *q) {
    pthread_mutex_lock(&q->mu);
    q->pending--;
    if (q->pending == 0 && q->head == q->tail) {
        q->done = 1;
        pthread_cond_broadcast(&q->cv);
    }
    pthread_mutex_unlock(&q->mu);
}

// ---------------- Per-directory walk -------------------------------------

// Walks a single directory using getattrlistbulk in 128 KB batches.
// For each child:
//   - regular file → emit entry, accumulate size into running totals
//     for the parent entry (caller does this after worker returns)
//   - directory → enqueue OR if name matches package, walk subtree
//     synchronously and emit single opaque entry
typedef struct {
    int64_t total_size;
    int64_t mtime_sec;
    uint32_t child_count;
} dir_walk_summary_t;

/// Single-directory leaf-sum walk. Used inside opaque packages.
/// Walks ONE directory level: sums regular file sizes, and pushes
/// each subdir back onto the work queue with the same target_idx so
/// other workers pick them up. Final accumulator is added to
/// entries[target_idx].size under a single lock acquisition.
///
/// Was previously a synchronous recursive `package_size()` —
/// blocked one worker for the whole subtree. With ~95k packages on
/// a typical Mac (Library + Applications), parallelizing the walks
/// across the worker pool is a substantial wall-clock win.
static void leaf_walk_dir(scan_result_t *result, work_queue_t *queue,
                          const char *path, int32_t target_idx) {
    int fd = open(path, O_RDONLY);
    if (fd < 0) return;
    struct attrlist alist = {0};
    alist.bitmapcount = ATTR_BIT_MAP_COUNT;
    alist.commonattr = ATTR_CMN_RETURNED_ATTRS | ATTR_CMN_NAME |
                       ATTR_CMN_OBJTYPE | ATTR_CMN_MODTIME;
    alist.fileattr = ATTR_FILE_ALLOCSIZE;
    char buf[128 * 1024];
    int64_t total_size = 0;
    int64_t max_mtime = 0;

    while (1) {
        int retcount = getattrlistbulk(fd, &alist, buf, sizeof(buf), 0);
        if (retcount <= 0) break;
        char *entry_start = buf;
        for (int i = 0; i < retcount; i++) {
            uint32_t length = *(uint32_t*)entry_start;
            char *p = entry_start + sizeof(uint32_t);
            attribute_set_t returned = *(attribute_set_t*)p;
            p += sizeof(attribute_set_t);
            const char *name = NULL;
            fsobj_type_t obj_type = 0;
            struct timespec mts = {0};
            off_t size = 0;
            if (returned.commonattr & ATTR_CMN_NAME) {
                attrreference_t ref = *(attrreference_t*)p;
                name = p + ref.attr_dataoffset;
                p += sizeof(attrreference_t);
            }
            if (returned.commonattr & ATTR_CMN_OBJTYPE) {
                obj_type = *(fsobj_type_t*)p;
                p += sizeof(fsobj_type_t);
            }
            if (returned.commonattr & ATTR_CMN_MODTIME) {
                mts = *(struct timespec*)p;
                p += sizeof(struct timespec);
            }
            if (returned.fileattr & ATTR_FILE_ALLOCSIZE) {
                size = *(off_t*)p;
                p += sizeof(off_t);
            }
            if (obj_type == VREG) {
                total_size += size;
                if (mts.tv_sec > max_mtime) max_mtime = mts.tv_sec;
            } else if (obj_type == VDIR && name && strcmp(name, ".") && strcmp(name, "..")) {
                char child[4096];
                int wrote = snprintf(child, sizeof(child), "%s/%s", path, name);
                if (wrote > 0 && wrote < (int)sizeof(child)) {
                    wq_push_leaf(queue, child, target_idx);
                }
            }
            entry_start += length;
        }
    }
    close(fd);

    // Single lock acquisition at end. Atomic add wouldn't work
    // through realloc — entries[] may have been resized.
    pthread_mutex_lock(&result->mu);
    result->entries[target_idx].size += total_size;
    if (max_mtime > result->entries[target_idx].mtime_sec) {
        result->entries[target_idx].mtime_sec = max_mtime;
    }
    pthread_mutex_unlock(&result->mu);
}

// Legacy synchronous package walker — kept for reference, no longer
// called. The queue-based `leaf_walk_dir` above replaces it.
static void package_size(const char *root, int64_t *out_size, int64_t *out_mtime) {
    typedef struct { char *path; } pkg_frame_t;
    pkg_frame_t *stack = malloc(sizeof(pkg_frame_t) * 64);
    size_t stack_size = 0, stack_cap = 64;
    stack[stack_size++].path = strdup(root);

    struct attrlist alist = {0};
    alist.bitmapcount = ATTR_BIT_MAP_COUNT;
    alist.commonattr = ATTR_CMN_RETURNED_ATTRS | ATTR_CMN_NAME |
                       ATTR_CMN_OBJTYPE | ATTR_CMN_MODTIME;
    // ATTR_FILE_ALLOCSIZE = on-disk allocated bytes (st_blocks * 512).
    // Matches `du`. Critical for sparse files (e.g. OrbStack/Parallels
    // disk images): a 1 GB sparse `.img` may report 1 TB logical size
    // via ATTR_FILE_TOTALSIZE while only consuming a few hundred MB
    // physically. We want disk usage, not logical size.
    alist.fileattr = ATTR_FILE_ALLOCSIZE;
    char buf[128 * 1024];

    while (stack_size > 0) {
        pkg_frame_t cur = stack[--stack_size];
        int fd = open(cur.path, O_RDONLY);
        if (fd < 0) { free(cur.path); continue; }
        while (1) {
            int retcount = getattrlistbulk(fd, &alist, buf, sizeof(buf), 0);
            if (retcount <= 0) break;
            char *entry_start = buf;
            for (int i = 0; i < retcount; i++) {
                uint32_t length = *(uint32_t*)entry_start;
                char *p = entry_start + sizeof(uint32_t);
                attribute_set_t returned = *(attribute_set_t*)p;
                p += sizeof(attribute_set_t);
                const char *name = NULL;
                fsobj_type_t obj_type = 0;
                struct timespec mts = {0};
                off_t size = 0;
                if (returned.commonattr & ATTR_CMN_NAME) {
                    attrreference_t ref = *(attrreference_t*)p;
                    name = p + ref.attr_dataoffset;
                    p += sizeof(attrreference_t);
                }
                if (returned.commonattr & ATTR_CMN_OBJTYPE) {
                    obj_type = *(fsobj_type_t*)p;
                    p += sizeof(fsobj_type_t);
                }
                if (returned.commonattr & ATTR_CMN_MODTIME) {
                    mts = *(struct timespec*)p;
                    p += sizeof(struct timespec);
                }
                if (returned.fileattr & ATTR_FILE_ALLOCSIZE) {
                    size = *(off_t*)p;
                    p += sizeof(off_t);
                }
                if (obj_type == VREG) {
                    *out_size += size;
                    if (mts.tv_sec > *out_mtime) *out_mtime = mts.tv_sec;
                } else if (obj_type == VDIR && name && strcmp(name, ".") && strcmp(name, "..")) {
                    char child[4096];
                    int wrote = snprintf(child, sizeof(child), "%s/%s", cur.path, name);
                    if (wrote > 0 && wrote < (int)sizeof(child)) {
                        if (stack_size >= stack_cap) {
                            stack_cap *= 2;
                            stack = realloc(stack, sizeof(pkg_frame_t) * stack_cap);
                        }
                        stack[stack_size++].path = strdup(child);
                    }
                }
                entry_start += length;
            }
        }
        close(fd);
        free(cur.path);
    }
    free(stack);
}

static void worker_walk_dir(scan_result_t *result, work_queue_t *queue,
                            const char *path, int32_t parent_idx) {
    int fd = open(path, O_RDONLY);
    if (fd < 0) return;
    struct attrlist alist = {0};
    alist.bitmapcount = ATTR_BIT_MAP_COUNT;
    alist.commonattr = ATTR_CMN_RETURNED_ATTRS | ATTR_CMN_NAME |
                       ATTR_CMN_OBJTYPE | ATTR_CMN_MODTIME;
    // ATTR_FILE_ALLOCSIZE = on-disk allocated bytes (st_blocks * 512).
    // Matches `du`. Critical for sparse files (e.g. OrbStack/Parallels
    // disk images): a 1 GB sparse `.img` may report 1 TB logical size
    // via ATTR_FILE_TOTALSIZE while only consuming a few hundred MB
    // physically. We want disk usage, not logical size.
    alist.fileattr = ATTR_FILE_ALLOCSIZE;
    char buf[128 * 1024];

    int64_t latest_mtime = 0;
    uint32_t child_count = 0;

    // Per-call local buffers for file emits. We accumulate every
    // regular file's path + size + mtime here, then take the global
    // result mutex ONCE at the end of the dir walk to bulk-emit them.
    // Was previously locking per-file (millions of lock acquisitions
    // on a typical Mac). Bulk emit drops that to one per directory
    // (~hundreds of thousands), measurably faster under 8-thread
    // contention.
    typedef struct {
        char path[512];
        uint16_t path_len;
        uint16_t name_len;
        int64_t size;
        int64_t mtime_sec;
    } local_file_t;
    local_file_t *local_files = malloc(sizeof(local_file_t) * 256);
    size_t local_cap = 256, local_count = 0;

    while (1) {
        int retcount = getattrlistbulk(fd, &alist, buf, sizeof(buf), 0);
        if (retcount <= 0) break;
        char *entry_start = buf;
        for (int i = 0; i < retcount; i++) {
            uint32_t length = *(uint32_t*)entry_start;
            char *p = entry_start + sizeof(uint32_t);
            attribute_set_t returned = *(attribute_set_t*)p;
            p += sizeof(attribute_set_t);
            const char *name = NULL;
            uint32_t name_len = 0;
            fsobj_type_t obj_type = 0;
            struct timespec mts = {0};
            off_t size = 0;
            if (returned.commonattr & ATTR_CMN_NAME) {
                attrreference_t ref = *(attrreference_t*)p;
                name = p + ref.attr_dataoffset;
                name_len = ref.attr_length > 0 ? ref.attr_length - 1 : 0;
                p += sizeof(attrreference_t);
            }
            if (returned.commonattr & ATTR_CMN_OBJTYPE) {
                obj_type = *(fsobj_type_t*)p;
                p += sizeof(fsobj_type_t);
            }
            if (returned.commonattr & ATTR_CMN_MODTIME) {
                mts = *(struct timespec*)p;
                p += sizeof(struct timespec);
            }
            if (returned.fileattr & ATTR_FILE_ALLOCSIZE) {
                size = *(off_t*)p;
                p += sizeof(off_t);
            }

            // Skip only "." and ".." (already not returned by
            // getattrlistbulk, but defensive). We DO walk hidden
            // entries (e.g. ~/.docker, ~/.cache, ~/.gradle) — on dev
            // machines these can hold tens of GB and excluding them
            // gave totals well below what `du` and Finder report.
            if (!name || (name[0] == '.' && (name[1] == '\0' ||
                                              (name[1] == '.' && name[2] == '\0')))) {
                entry_start += length;
                continue;
            }

            char child_path[4096];
            int child_path_len;
            // Avoid producing "//foo" when scanning from the root —
            // double-slashes break the skip-prefix check downstream.
            if (path[0] == '/' && path[1] == '\0') {
                child_path_len = snprintf(child_path, sizeof(child_path),
                                          "/%s", name);
            } else {
                child_path_len = snprintf(child_path, sizeof(child_path),
                                          "%s/%s", path, name);
            }
            if (path_should_skip(child_path)) {
                entry_start += length;
                continue;
            }

            child_count++;

            if (obj_type == VREG) {
                if (mts.tv_sec > latest_mtime) latest_mtime = mts.tv_sec;
                if (child_path_len < (int)sizeof(((local_file_t*)0)->path)) {
                    if (local_count >= local_cap) {
                        local_cap *= 2;
                        local_files = realloc(local_files,
                                              sizeof(local_file_t) * local_cap);
                    }
                    local_file_t *lf = &local_files[local_count++];
                    memcpy(lf->path, child_path, child_path_len);
                    lf->path_len = (uint16_t)child_path_len;
                    lf->name_len = (uint16_t)name_len;
                    lf->size = size;
                    lf->mtime_sec = mts.tv_sec;
                }
            } else if (obj_type == VDIR) {
                if (name_is_package(name)) {
                    int64_t pkg_size = 0;
                    int64_t pkg_mtime = mts.tv_sec;
                    package_size(child_path, &pkg_size, &pkg_mtime);
                    if (pkg_mtime > latest_mtime) latest_mtime = pkg_mtime;
                    pthread_mutex_lock(&result->mu);
                    int32_t idx = result_alloc_entry(result);
                    uint32_t poff = result_intern_path(result, child_path, child_path_len);
                    scan_entry_t *e = &result->entries[idx];
                    e->kind = 2;
                    e->parent_idx = parent_idx;
                    e->size = pkg_size;
                    e->mtime_sec = pkg_mtime;
                    e->path_offset = poff;
                    e->path_length = (uint32_t)child_path_len;
                    e->name_offset = poff + (uint32_t)(child_path_len - name_len);
                    e->name_length = name_len;
                    e->child_count = 0;
                    pthread_mutex_unlock(&result->mu);
                } else {
                    pthread_mutex_lock(&result->mu);
                    int32_t idx = result_alloc_entry(result);
                    uint32_t poff = result_intern_path(result, child_path, child_path_len);
                    scan_entry_t *e = &result->entries[idx];
                    e->kind = 1;
                    e->parent_idx = parent_idx;
                    e->size = 0;            // filled later via post-pass
                    e->mtime_sec = mts.tv_sec;
                    e->path_offset = poff;
                    e->path_length = (uint32_t)child_path_len;
                    e->name_offset = poff + (uint32_t)(child_path_len - name_len);
                    e->name_length = name_len;
                    e->child_count = 0;
                    pthread_mutex_unlock(&result->mu);
                    wq_push(queue, child_path, idx, child_path_len);
                }
            }
            entry_start += length;
        }
    }
    close(fd);

    // Bulk-flush all locally-accumulated file emits + the parent
    // metadata update under a SINGLE global lock acquisition. Was
    // previously locking per-file (millions of contended acquisitions
    // across 8 worker threads).
    if (parent_idx >= 0 || local_count > 0) {
        pthread_mutex_lock(&result->mu);
        for (size_t li = 0; li < local_count; li++) {
            local_file_t *lf = &local_files[li];
            int32_t idx = result_alloc_entry(result);
            uint32_t poff = result_intern_path(result, lf->path, lf->path_len);
            scan_entry_t *e = &result->entries[idx];
            e->kind = 0;
            e->parent_idx = parent_idx;
            e->size = lf->size;
            e->mtime_sec = lf->mtime_sec;
            e->path_offset = poff;
            e->path_length = lf->path_len;
            e->name_offset = poff + (uint32_t)(lf->path_len - lf->name_len);
            e->name_length = lf->name_len;
            e->child_count = 0;
        }
        if (parent_idx >= 0) {
            result->entries[parent_idx].child_count += child_count;
            if (latest_mtime > result->entries[parent_idx].mtime_sec) {
                result->entries[parent_idx].mtime_sec = latest_mtime;
            }
        }
        pthread_mutex_unlock(&result->mu);
    }
    free(local_files);
}

// ---------------- Worker thread loop -------------------------------------

typedef struct {
    scan_result_t *result;
    work_queue_t *queue;
} worker_args_t;

static void *worker_thread(void *arg) {
    worker_args_t *wa = (worker_args_t *)arg;
    work_item_t item;
    while (wq_pop(wa->queue, &item)) {
        if (item.kind == WALK_LEAF_SUM) {
            leaf_walk_dir(wa->result, wa->queue, item.path, item.parent_idx);
        } else {
            worker_walk_dir(wa->result, wa->queue, item.path, item.parent_idx);
        }
        free(item.path);
        wq_task_done(wa->queue);
    }
    return NULL;
}

// ---------------- Public entry point -------------------------------------

scan_result_t *scan_run(const char *root_path, int n_threads) {
    if (n_threads < 1) n_threads = 1;
    if (n_threads > 32) n_threads = 32;

    scan_result_t *result = result_new();

    // Emit the root directory entry (parent_idx = -1).
    size_t root_len = strlen(root_path);
    int32_t root_idx = result_alloc_entry(result);
    uint32_t root_poff = result_intern_path(result, root_path, root_len);
    scan_entry_t *root_e = &result->entries[root_idx];
    root_e->kind = 1;
    root_e->parent_idx = -1;
    root_e->size = 0;
    root_e->mtime_sec = 0;
    root_e->path_offset = root_poff;
    root_e->path_length = (uint32_t)root_len;
    root_e->name_offset = root_poff;
    root_e->name_length = (uint32_t)root_len;
    root_e->child_count = 0;

    work_queue_t queue;
    wq_init(&queue, 4096);
    wq_push(&queue, root_path, root_idx, (int)root_len);

    pthread_t *threads = malloc(sizeof(pthread_t) * n_threads);
    worker_args_t wa = { .result = result, .queue = &queue };
    for (int i = 0; i < n_threads; i++) {
        pthread_create(&threads[i], NULL, worker_thread, &wa);
    }
    for (int i = 0; i < n_threads; i++) {
        pthread_join(threads[i], NULL);
    }
    free(threads);
    wq_destroy(&queue);

    // Post-pass: roll subdir sizes up to ancestors. Iterate entries
    // bottom-up — we know parents always appear before their children
    // in entries[] because dirs are emitted before they're enqueued.
    // Walking the array right-to-left, when we hit a child, its
    // own size + child contributions are already finalized; add to
    // parent.
    for (size_t i = result->entry_count; i > 0; i--) {
        scan_entry_t *e = &result->entries[i - 1];
        if (e->parent_idx >= 0) {
            result->entries[e->parent_idx].size += e->size;
        }
    }

    return result;
}
