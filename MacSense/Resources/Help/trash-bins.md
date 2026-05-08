# Trash Bins

The contents of `~/.Trash` plus any volume-level Trashes (external drives). MacSense empties them so the space is actually returned to the system.

## Details

Dragging a file to the Trash only marks it for deletion — the bytes stay on disk until the Trash is emptied. macOS shows the recovered space in Disk Utility but treats it as in-use until you confirm.

MacSense's Trash sweep:

- Lists every file in `~/.Trash` and on each mounted volume.
- Reports the total recoverable size.
- On clean, removes the files permanently.

Unlike the other categories, this is the only place where MacSense's clean is **not reversible** — once Trash is emptied, the files are gone. Always glance at the list before confirming.
