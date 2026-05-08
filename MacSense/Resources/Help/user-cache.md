# User Cache

App-generated data that lives under `~/Library/Caches`. Apps treat this as throwaway storage — losing it slows the next launch slightly but never breaks anything.

## Details

Every app uses cache space for:

- Pre-rendered images, thumbnails, and decoded media.
- Downloaded asset bundles that the app can re-fetch.
- Search indexes and recent-history lookups.

Modern Macs accumulate gigabytes here over time, especially from browsers, media apps, and Electron-based tools. The first launch after a clean is briefly slower because the app rebuilds what it needs — every subsequent launch is back to normal.

MacSense skips caches that are clearly in active use (locked files, currently-open databases) and trashes the rest. Files go to the Trash, never delete-in-place.
