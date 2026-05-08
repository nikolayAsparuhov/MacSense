# Last Used Date

The most recent moment macOS recorded the app being launched. Pulled from Spotlight's `kMDItemLastUsedDate` metadata.

## Details

macOS updates this timestamp whenever you launch an app via Finder, Dock, Spotlight, or Launchpad. Apps you keep installed but never open accumulate dust here — exactly the candidates the Unused tab is designed to surface.

The Unused tab buckets your apps two ways:

- **Unused for ≥ X days** — apps with a known last-used date older than the threshold. Sorted oldest first.
- **Never opened** — apps with no `kMDItemLastUsedDate`. They may have been installed but never run, or their Spotlight metadata wasn't recorded for some reason.

Threshold presets: 30 / 60 / 90 / 180 days. Your choice persists across launches.

Tapping any row opens the standard uninstall sheet — same flow as the Installed Apps tab.
