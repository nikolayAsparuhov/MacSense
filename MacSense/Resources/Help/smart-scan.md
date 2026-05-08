# Smart Scan

A single button that scans every cleanup category and totals the recoverable space, so you can see the impact before deciding what to clean.

## Details

Smart Scan walks each category in sequence — System Junk, User Cache, Trash, Purgeable Space, Developer Caches — and aggregates results. It's read-only; nothing is deleted by the scan itself.

Once the scan finishes, the Cleanup view shows a card per category with:

- **Recoverable size** for that category.
- **One-click Clean** that moves files to the Trash.
- **Detail sheet** for inspecting individual items before cleaning.

Smart Scan also feeds the optional **Scheduled Scan** — when scheduled, MacSense runs the same logic in the background and posts a summary notification.
