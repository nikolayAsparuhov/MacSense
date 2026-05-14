# Benutzer-Cache

App-generierte Daten in `~/Library/Caches`. Apps behandeln das als Wegwerfspeicher — der Verlust verlangsamt nur den nächsten Start leicht, kaputt geht nichts.

## Details

Jede App nutzt Cache für:

- Vorgerenderte Bilder, Vorschauen und dekodierte Medien.
- Heruntergeladene Asset-Bundles, die die App neu beziehen kann.
- Suchindizes und Verläufe.

Moderne Macs sammeln über die Zeit Gigabytes an, vor allem aus Browsern, Medien-Apps und Electron-Tools. Der erste Start nach der Bereinigung ist kurz langsamer, danach normal.

MacSense überspringt aktiv genutzte Caches (gesperrte Dateien, geöffnete Datenbanken) und verschiebt den Rest in den Papierkorb, niemals direktes Löschen.
