<div align="center">

# MacSense

**Free, native macOS optimizer that cleans junk, tames startup items, profiles performance, and visualizes disk usage — all in one glossy SwiftUI app.**

<img src="docs/screenshots/hero.png" alt="MacSense hero screenshot" width="820" />

[Download](https://github.com/nikolayAsparuhov/MacSense/releases/latest) · [Quickstart](#-quickstart) · [Features](#-features-at-a-glance) · [Screenshots](#-screenshots) · [FAQ](#-faq) · [Changelog](CHANGELOG.md)

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/macOS-13%2B-blue.svg)](#)
[![Universal](https://img.shields.io/badge/binary-universal%20(Intel%20%2B%20Apple%20Silicon)-blueviolet.svg)](#)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![CI](https://github.com/nikolayAsparuhov/MacSense/actions/workflows/build.yml/badge.svg)](https://github.com/nikolayAsparuhov/MacSense/actions)

</div>

---

One native app for the four things you actually open a Mac utility for: clean junk, manage startup apps, watch live performance, visualize disk usage. No subscription. No telemetry. No background daemon. Open it when you need it, close it when you don't.

## ✨ Why MacSense

<table>
<tr>
<td width="50%">

### 🆓 Free + open source
<sub>MIT-licensed. No upsells, no analytics, no account.</sub>

</td>
<td width="50%">

### 🔒 Local only
<sub>Everything runs on your Mac. The only network call is one optional public-IP lookup.</sub>

</td>
</tr>
<tr>
<td>

### 🧹 Real cleanup
<sub>Dev caches for 30+ tools (npm, pip, Cargo, NuGet, Maven, Go, …), system junk, Docker, purgeable space, Time Machine snapshots.</sub>

</td>
<td>

### 📊 Honest visualizations
<sub>Bubble-map storage explorer, live CPU/memory/disk/network meters, top processes, login-item audit.</sub>

</td>
</tr>
<tr>
<td>

### 🛡️ Safe by default
<sub>Every uninstall path is checked against an allowlist of scan roots and re-checked the moment before deletion. Files go to the Trash by default. Embedded login items can't be corrupted.</sub>

</td>
<td>

### ⚡️ Native SwiftUI
<sub>No Electron, no helper daemon. Universal binary, ~80 MB. Idle RAM bounded by aggressive cleanup on tab switch.</sub>

</td>
</tr>
<tr>
<td>

### 🌍 9 languages
<sub>English, German, Spanish, French, Hindi, Portuguese, Russian, Chinese (Simplified), Bengali. Help drawer localized.</sub>

</td>
<td>

### 🖥 Intel + Apple Silicon
<sub>Universal binary built and tested on both architectures. Runs on any Mac with macOS 13 Ventura or newer.</sub>

</td>
</tr>
</table>

## 📦 Requirements

- macOS 13 Ventura or newer
- ~80 MB disk space
- Intel or Apple Silicon Mac

## 🚀 Quickstart

1. Download the latest **`MacSense.dmg`** from [Releases](https://github.com/nikolayAsparuhov/MacSense/releases/latest).
2. Open the DMG, drag `MacSense.app` into `/Applications`.
3. Launch from Launchpad or Spotlight.

The DMG is signed with a Developer ID Application certificate and notarized by Apple — Gatekeeper opens it on first launch without warnings.

Verify the download (optional):

```bash
shasum -a 256 MacSense.dmg
# compare against the SHA-256 listed on the Releases page
```

No services to install. No permissions granted up front — MacSense asks for Full Disk Access only when you scan a path that needs it.

## 🎯 First Steps

When the app opens you land on **Cleanup**. From there:

1. Click **Smart Scan** to see what every category is holding.
2. Switch to **Storage** and run a scan to get the bubble map of your disk.
3. Open **Applications → Installed Apps** to find big or unused apps and uninstall them with all their leftover files.
4. Visit **Performance** for live system stats, then click "Scan" in the Network card to discover devices on your LAN.

Nothing scans automatically. You decide what to look at.

## 📸 Screenshots

<table>
<tr>
<td><img src="docs/screenshots/cleanup.png" alt="Cleanup" /></td>
<td><img src="docs/screenshots/storage-bubbles.png" alt="Storage bubble map" /></td>
</tr>
<tr>
<td align="center"><sub><b>Cleanup</b> — categories with size + recoverable totals</sub></td>
<td align="center"><sub><b>Storage</b> — bubble explorer, click to drill into folders</sub></td>
</tr>
<tr>
<td><img src="docs/screenshots/performance.png" alt="Performance" /></td>
<td><img src="docs/screenshots/applications.png" alt="Applications" /></td>
</tr>
<tr>
<td align="center"><sub><b>Performance</b> — live CPU, memory, disk, network, battery, thermal</sub></td>
<td align="center"><sub><b>Applications</b> — installed apps + login items, one-click uninstall</sub></td>
</tr>
<tr>
<td><img src="docs/screenshots/dev-caches.png" alt="Developer caches" /></td>
<td><img src="docs/screenshots/network-scan.png" alt="Network scan" /></td>
</tr>
<tr>
<td align="center"><sub><b>Developer caches</b> — 30+ ecosystems, grouped by tool</sub></td>
<td align="center"><sub><b>Network scan</b> — discover every device on your LAN with IP, MAC, hostname</sub></td>
</tr>
</table>

## 🏠 Who is it for

<table>
<tr>
<td width="33%" align="center">

### 👨‍💻 Developers
<sub>Wipe gigabytes of npm/Cargo/Maven/NuGet/pip caches. See where Xcode DerivedData is hiding.</sub>

</td>
<td width="33%" align="center">

### 🎨 Creators
<sub>Find huge old video / Photoshop / Logic exports across all drives in seconds.</sub>

</td>
<td width="33%" align="center">

### 🖥 Power users
<sub>Audit login items the App Store hides. Kill runaway processes. Check Wi-Fi RSSI.</sub>

</td>
</tr>
</table>

## 📋 Features at a glance

### 🧹 Cleanup
System junk · User caches · Trash bins · Purgeable space · iCloud offloaded · Time Machine snapshots · Docker images · Xcode DerivedData/Archives/Simulators · 30+ dev tool caches (npm, Yarn, pnpm, Bun, pip, Poetry, Conda, Cargo, Go, NuGet, Maven, Gradle, Composer, SwiftPM, pub, Hex, Cabal, Coursier, ccache, Bazel, Vagrant, Terraform, Pulumi, AWS SAM, …)

### 📊 Storage
Bubble-map drill-down · Per-folder sizes · Large + old file finder · By-media-type breakdown · Multi-select delete

### 📱 Applications
Installed-app inventory with combined size (bundle + caches + prefs + containers) · One-click uninstall with a per-file reason and confidence dot · Allowlist path validation before every delete · Excluded-items list with the rule that dropped each one · Safety verdict + confirmation for risky removals · Quits the app and boots out its launch agents first · Trash or permanent mode · Path-level JSON uninstall log · Login items audit (User + System) · Toggle / disable / delete launch agents

### ⚡ Performance
Live CPU / memory / disk / network / battery / thermal · Top processes table with kill action · Network device scan · Wi-Fi + Ethernet diagnostics · Flush DNS

<details>
<summary><b>🛠 Build from source</b></summary>

Requirements:

- macOS 13 (Ventura) or newer
- Xcode 15 or newer
- (Optional) [`xcodegen`](https://github.com/yonaskolb/XcodeGen) — only needed if you edit `project.yml`

```bash
git clone https://github.com/nikolayAsparuhov/MacSense.git
cd MacSense
open MacSense.xcodeproj
# ⌘R in Xcode
```

Or from the command line:

```bash
xcodebuild -project MacSense.xcodeproj -scheme MacSense \
           -configuration Debug -destination 'platform=macOS' build
open build/Build/Products/Debug/MacSense.app
```

Universal binary build settings (`ARCHS = arm64 x86_64`) produce a single app that runs natively on both Apple Silicon and Intel.

### Building a signed DMG

See [`scripts/build-dmg.sh`](scripts/build-dmg.sh). Requires a Developer ID Application certificate; falls back to ad-hoc signed for local testing.

```bash
./scripts/build-dmg.sh
```

</details>

## ❓ FAQ

<details>
<summary><b>Is MacSense signed and notarized?</b></summary>

Yes. Release DMGs are signed with a Developer ID Application certificate and notarized by Apple. Gatekeeper accepts them without warnings. The DMG signature can be verified with `codesign --verify --verbose /Applications/MacSense.app` and `spctl -a -t open --context context:primary-signature MacSense.dmg`.

</details>

<details>
<summary><b>Why does MacSense ask for Full Disk Access?</b></summary>

System junk, user caches, and Time Machine snapshot scanning all touch directories that macOS protects behind TCC. Without Full Disk Access you can still use Storage, Performance, and Applications — only the deep cleanup categories will show empty results. MacSense never reads file contents, only sizes and modification dates.

</details>

<details>
<summary><b>Does MacSense send any data off my Mac?</b></summary>

No analytics, no crash reporters, no account, no telemetry. The single outbound call the app ever makes is an opt-in public-IP lookup against `api.ipify.org` (with `ifconfig.me`, `icanhazip.com`, `ipv4.icanhazip.com` as fallbacks) — you control when it runs. Disable your network and everything else works fully offline.

</details>

<details>
<summary><b>Can MacSense break my system?</b></summary>

Cleanup actions move files to the Trash — you can restore anything until you empty the bin. Uninstalls go through a path validator that only permits strict descendants of the ~50 locations the scanner searches, and refuses filesystem roots, your home folder, every mounted volume, and config folders like `~/.ssh` and `~/.aws` outright; every path is re-validated in the moment before it is deleted. Permanent deletion is opt-in per uninstall and covers your own files only — anything needing an administrator password still goes to the Trash, because MacSense never runs `rm` as root. Login items registered through SMAppService (Apple's recommended API) cannot be removed by third-party apps; MacSense stops and disables the job, and tells you macOS may still list it until it prunes its own database.

</details>

<details>
<summary><b>Why isn't dev cache X listed?</b></summary>

The dev-cache catalog is data-driven and lives in `MacSense/Models/CleaningCategory.swift`. PRs adding new tools are welcome — include the install path, default cache location, and one screenshot of the category populated with real data.

</details>

## 🔒 Privacy + safety

MacSense never uploads your files, scan results, app inventory, or system metrics. The single network call the app makes is an opt-in public-IP lookup against `api.ipify.org` (with `ifconfig.me`, `icanhazip.com`, `ipv4.icanhazip.com` as fallbacks). Disable your network and the rest of the app still works fully offline.

Destructive actions:
- Files move to the Trash by default; permanent deletion is opt-in per uninstall and never runs as root
- Every uninstall path must be a strict descendant of a scanned location, and is re-checked immediately before deletion
- Running apps are quit and their launch agents booted out before any file is removed; if a process won't quit, nothing is deleted
- Login items registered via SMAppService cannot be removed by third-party apps (macOS restriction); MacSense stops and disables the job and surfaces the residual entry
- Confirmation dialog before every risky or permanent delete, listing what was flagged
- Each uninstall is recorded path by path in `~/Library/Application Support/tech.veraio.macsense/uninstall-log.json`

See [SECURITY.md](SECURITY.md) for the responsible-disclosure policy.

## 🤝 Contributing

PRs welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) before submitting.

Quick rules:

- Build must be warning-free (`xcodebuild ... | grep -E "warning:|error:"` returns nothing)
- New features need at least one screenshot in the PR
- Stick to the existing `GlossyCard` / `Theme.Palette` design system

## 📄 License

[MIT](LICENSE) — do whatever you want, just don't blame us if it eats your homework.

## 💬 Support

- [Open an issue](https://github.com/nikolayAsparuhov/MacSense/issues) for bugs and feature requests
- [Discussions](https://github.com/nikolayAsparuhov/MacSense/discussions) for questions and ideas
- [Releases](https://github.com/nikolayAsparuhov/MacSense/releases) for version history and SHA-256 checksums
- [Changelog](CHANGELOG.md) for what changed between versions
- Star the repo if MacSense saved you some disk ⭐
