# Speicher-Graph

Eine ordnerweise Karte deiner Festplatte, in der jedes Element nach seiner Belegung skaliert ist. Damit findest du, was Speicher frisst, ohne zu raten.

## Details

Die Speicher-Sektion baut einen Baum über jeden Ordner unter `/`, berechnet rekursive Größen und bietet zwei Ansichten:

- **Tab Größe** — interaktive Bubble-Karte. Größere Kreise = größere Ordner. Klick zum Hineinzoomen; die Brotkrume oben zeigt den Pfad.
- **Tab Typ** — Dateien gruppiert nach Medientyp (Video, Audio, Archive, Screenshots…), damit du z. B. siehst, dass 30 GB deiner Festplatte Videodateien sind.

Der erste Scan dauert ~30 Sekunden, weil jedes Byte unter deinem Benutzerordner durchlaufen wird. MacSense cached danach einen Snapshot auf Festplatte, sodass spätere Besuche sofort Daten zeigen, während ein Refresh im Hintergrund läuft.

Dateien werden aus der Graph-Ansicht nie verschoben oder gelöscht — sie ist read-only. Nutze die Kategorie-Sheets im Cleanup, wenn du tatsächlich etwas löschen willst.
