# Freigebbarer Speicher

Bytes, die macOS bereits als wiederverwertbar betrachtet, aber noch nicht entfernt hat. Eine Purge sagt dem System „ich brauche jetzt diesen Speicher" und zwingt es, diese Dateien zu räumen.

## Details

APFS hält mehrere Schichten weich-räumbaren Speichers:

- **iCloud-synchronisierte Dateien** mit lokaler und Cloud-Kopie.
- **Time Machine lokale Snapshots** (siehe eigenen Eintrag).
- **macOS-verwaltete Caches** als räumbar markiert bei Speicherdruck.

Der Finder meldet freigebbare Bytes als „Verfügbar", zeigt sie aber nicht in „Belegt" oder „Frei". Sie erscheinen für macOS frei, für Apps, die Speicher altmodisch berechnen, jedoch belegt. Eine Purge gibt sie wirklich frei.

MacSense ruft dieselben Pfade (`diskutil apfs deleteContainer`, `tmutil thinlocalsnapshots`) auf, die das System unter Druck nutzt. Kein Datenverlust — jedes freigebbare Byte hat woanders eine andere Kopie.
