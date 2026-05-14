# User Login Items

Apps and helpers that start automatically when you log into your Mac. Owned by your user account, so disabling or removing them only affects your session.

## Details

User login items come from two places:

- **launchd plists** in `~/Library/LaunchAgents` — usually installed by third-party apps to provide background sync, update checks, or menu-bar items.
- **`SMAppService` registrations** declared inside an app bundle (macOS 13+). MacSense surfaces these but cannot toggle them — use System Settings → General → Login Items.

Most user login items are safe to disable: the parent app keeps working, just without the auto-start behavior. If something starts misbehaving, re-enabling the agent or reopening the app restores it.
