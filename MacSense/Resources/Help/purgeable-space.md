# Purgeable Space

Bytes macOS already considers reclaimable but hasn't yet evicted. Triggering a purge tells the system "I need this space now" and forces it to drop those files.

## Details

APFS keeps several layers of soft-evictable storage:

- **iCloud-synced files** that have a local copy plus a cloud copy.
- **Time Machine local snapshots** (see the dedicated entry for those).
- **macOS-managed caches** the OS marks as evictable when disk pressure rises.

Finder reports purgeable bytes under "Available" but doesn't show them in the obvious "Used" or "Free" sections. They appear free to macOS but used to apps that try to compute available space the old way. Purging makes the bytes actually free.

MacSense calls the same `diskutil apfs deleteContainer` / `tmutil thinlocalsnapshots` paths the system would use under disk pressure, but on demand. No data loss — every purgeable byte has another copy somewhere (cloud, Time Machine destination, or it's regenerable cache).
