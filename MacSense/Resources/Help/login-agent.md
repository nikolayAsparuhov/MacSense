# Login Agent

A process macOS starts automatically when you log in. Some are essential (system services, keychain helpers), others are app companions you may not need running constantly.

## Details

Login agents come from three sources:

- **System** — macOS-bundled agents in `/System/Library/LaunchAgents`. MacSense never touches these.
- **Per-user** — launchd plists in `~/Library/LaunchAgents`. Often installed by third-party apps to provide background sync, update checks, or menu-bar items.
- **Embedded** — registered by an app via `SMAppService` (see "Embedded Login Item").

Per-user agents can be disabled or removed safely — the parent app continues to work but loses any background behavior the agent provided. If something starts misbehaving, re-enabling the agent or reinstalling the app restores it.
