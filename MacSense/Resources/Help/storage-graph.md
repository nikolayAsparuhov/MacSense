# Storage Graph

A folder-by-folder map of your disk, with each item sized by its on-disk allocation. Lets you drill down to whatever's eating space without guessing.

## Details

The Storage section builds a tree of every folder under `/`, computes recursive sizes, and presents two views:

- **Size tab** — interactive bubble map. Larger circles = bigger folders. Click to drill into a folder; the breadcrumb at the top tracks your path.
- **Type tab** — files grouped by media type (video, audio, archives, screenshots, …) so you can see, for instance, that 30 GB of your disk is video files.

The first scan takes ~30 seconds because every byte under your home folder is walked. After that, MacSense caches a snapshot to disk so subsequent visits show data immediately while a refresh runs in the background.

Files are never moved or deleted from the graph view — it's read-only inspection. Use the Cleanup section's category sheets when you want to actually trash something.
