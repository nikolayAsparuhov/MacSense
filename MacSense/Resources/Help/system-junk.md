# System Junk

Logs, temporary files, and crash reports that macOS or installed apps drop outside your home folder. Safe to remove — the system regenerates anything it still needs.

## Details

System Junk covers three buckets:

- **Diagnostic reports** in `/Library/Logs` and `/var/log`. macOS rotates these automatically, so old entries are pure noise.
- **Crash reports** under `/Library/Application Support/CrashReporter`. Useful right after a crash, useless months later.
- **Temporary install artifacts** left behind by package installers and app updates.

MacSense moves anything it finds to the Trash. Nothing here holds user documents, preferences, or app data — only system-generated artifacts. If something the system actively needs gets removed, macOS rebuilds it on next launch.
