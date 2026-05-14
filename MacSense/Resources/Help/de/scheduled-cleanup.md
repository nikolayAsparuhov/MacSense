# Geplante Bereinigung

Ein optionaler wiederkehrender Scan, der im Hintergrund täglich, wöchentlich oder monatlich läuft und eine Zusammenfassungs-Mitteilung sendet.

## Details

Wenn aktiviert, nutzt MacSense `NSBackgroundActivityScheduler` — macOS' energiefreundliche Task-API — um einen Smart Scan über die ausgewählten Kategorien laufen zu lassen. Das Ergebnis kommt als einzelne Mitteilung:

> 4,7 GB wiederherstellbar in 4 Kategorien gefunden. Öffne MacSense, um zu prüfen.

Tippen auf die Mitteilung öffnet MacSense in der Cleanup-Sektion.

Wichtige Einschränkungen:

- **Nichts wird automatisch gelöscht.** Der Zeitplan benachrichtigt; du entscheidest, ob (und was) bereinigt wird.
- **Zeitpläne laufen, während MacSense geöffnet oder kürzlich aktiv war.** macOS kann Hintergrundaufgaben verzögern. Kein LaunchAgent, kein Daemon — Beenden der App pausiert den Zeitplan bis zum nächsten Start.

Die Benachrichtigungserlaubnis wird einmal beim ersten Start abgefragt. Bei vorher abgelehnter Erlaubnis zeigt der Zeitplan-Bereich ein Banner mit Verknüpfung zu Systemeinstellungen.
