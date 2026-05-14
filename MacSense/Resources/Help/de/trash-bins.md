# Papierkorb

Inhalt von `~/.Trash` plus aller Volumen-Papierkörbe (externe Laufwerke). MacSense leert sie, damit der Speicher tatsächlich an das System zurückgegeben wird.

## Details

Eine Datei in den Papierkorb zu ziehen markiert sie nur zum Löschen — die Bytes bleiben auf der Festplatte bis zum Leeren. macOS zeigt den freien Speicher im Festplattendienstprogramm, behandelt ihn aber als belegt bis zur Bestätigung.

MacSense' Papierkorb-Sweep:

- Listet jede Datei in `~/.Trash` und auf jedem gemounteten Volume.
- Meldet die gesamte wiederherstellbare Größe.
- Beim Bereinigen werden die Dateien dauerhaft entfernt.

Das ist die einzige **nicht reversible** Aktion — einmal geleert, sind die Dateien weg. Prüfe die Liste vor dem Bestätigen.
