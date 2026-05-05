# Changelog

All notable changes will be documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); MacSense follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Initial public release.

## [1.0.0] — 2026-05-05

### Added
- **Cleanup** with categories for system junk, user caches, trash, purgeable space, Docker, Xcode, and 30+ dev-tool caches (npm, Yarn, pnpm, Bun, pip, Poetry, Conda, Cargo, Go, NuGet, Maven, Gradle, Composer, SwiftPM, pub, Hex, Cabal, Coursier, ccache, Bazel, Vagrant, Terraform, Pulumi, AWS SAM, …)
- **Storage** bubble-map explorer with multi-select delete + large/old file finder + by-media-type breakdown
- **Applications** installed-app inventory with combined size + one-click uninstall + login-items audit (User and System scopes, SMAppService support)
- **Performance** live CPU / memory / disk / network / battery / thermal meters, top processes table with kill action, network device scan, Wi-Fi + Ethernet diagnostics, public IP, DNS flush
- Sidebar with status dots driven by section state
- Hero landing per section with explicit-opt-in scan model — nothing scans automatically
- Cached snapshot revealed after 5–10 s on subsequent storage scans (instant feel, real scan continues in background)
- ESC + sidebar-tap dismissal for all inline modals

### Notes
- Wi-Fi SSID and BSSID may show as "—" without macOS Location Services granted to MacSense
- Login items registered via SMAppService can only be toggled by their parent app or in System Settings → Login Items (macOS restriction)
