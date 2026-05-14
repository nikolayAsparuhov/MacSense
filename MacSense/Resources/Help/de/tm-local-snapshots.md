# Time Machine lokale Snapshots

Stündliche Festplatten-Snapshots, die Time Machine auch ohne angeschlossenes Backup-Laufwerk anlegt. Sie liegen auf deiner internen Festplatte und verbrauchen leise Speicher.

## Details

Time Machine hält ein rollendes Fenster lokaler Snapshots, um kürzliche Änderungen ohne externes Laufwerk wiederherzustellen. Jeder Snapshot ist eine Copy-on-Write-Referenz — neue Snapshots sind günstig, aber beim Bearbeiten/Löschen halten sie diese Bytes fest.

Anzeichen von Anhäufung:

- Festplatte fühlt sich voll an, Finder zeigt freien Speicher.
- „Freigebbare" Bytes sind groß.
- Nach einem großen Download gibt das Löschen den Speicher nicht frei.

MacSense ruft `tmutil thinlocalsnapshots /` auf, um sie auf Anforderung freizugeben. macOS räumt zuerst die ältesten; Time Machine-Backups auf externem Laufwerk bleiben unberührt. Bei erneutem Anschluss des externen Laufwerks rollen frische Snapshots zurück.
