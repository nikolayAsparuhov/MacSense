# Embedded Login Item

A login item registered by the app itself via `SMAppService` (macOS 13+). Third-party tools — including MacSense — cannot disable, modify, or delete these for security reasons.

## Details

Apple introduced `SMAppService` to replace the older legacy login-item APIs. The benefits:

- Apps register themselves as login agents from inside their own bundle.
- macOS guarantees nothing outside the app can tamper with the registration.
- The user retains full control through System Settings.

The trade-off: tools like MacSense can show you these registrations but can't toggle them. The "Disable" affordance opens **System Settings → General → Login Items** at the right pane so you can flip the switch yourself.

Legacy login items registered through old APIs (LSSharedFileList, launchd plists in `~/Library/LaunchAgents`) remain manageable from MacSense.
