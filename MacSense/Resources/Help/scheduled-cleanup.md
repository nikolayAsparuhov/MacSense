# Scheduled Cleanup

An opt-in recurring scan that runs in the background at a daily, weekly, or monthly cadence and posts a summary notification.

## Details

When enabled, MacSense uses `NSBackgroundActivityScheduler` — macOS's energy-friendly task API — to run a Smart Scan over the categories you've ticked. The result is delivered as a single notification:

> Found 4.7 GB recoverable across 4 categories. Open MacSense to review.

Tapping the notification opens MacSense to the Cleanup section.

Important constraints:

- **Nothing is deleted automatically.** The schedule notifies; you decide what (if anything) to clean.
- **Schedules run while MacSense is open or recently active.** macOS may delay background tasks under heavy load. There's no LaunchAgent or daemon — closing the app fully pauses the schedule until next launch.

Notification permission is requested once on first launch. If you previously denied it, the Schedule section shows a banner with a shortcut to System Settings.
