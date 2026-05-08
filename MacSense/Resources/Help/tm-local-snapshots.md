# Time Machine Local Snapshots

Hourly disk-level snapshots Time Machine takes even when your backup drive isn't connected. They live on your internal drive and silently consume space.

## Details

Time Machine's modern design keeps a rolling window of local snapshots so you can restore recent changes without an external drive plugged in. Each snapshot is a copy-on-write reference, so a brand-new snapshot is cheap — but as you edit + delete files, the snapshots gradually pin those bytes in place.

Symptoms of accumulation:

- Disk feels full but Finder shows free space.
- "Purgeable" bytes are large.
- After a big download, deleting it doesn't free the space.

MacSense calls `tmutil thinlocalsnapshots /` to release them on demand. macOS evicts the oldest snapshots first; cloud-backed Time Machine destinations are unaffected. Once your external Time Machine drive reconnects, fresh snapshots roll back in.
