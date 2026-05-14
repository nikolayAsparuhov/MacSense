# Benutzer-Anmeldeobjekte

Apps und Helfer, die automatisch beim Anmelden starten. Sie gehören zu deinem Benutzerkonto, also wirken Deaktivieren oder Entfernen nur auf deine Sitzung.

## Details

Benutzer-Anmeldeobjekte stammen aus zwei Quellen:

- **launchd-Plists** in `~/Library/LaunchAgents` — meist von Drittanbieter-Apps für Hintergrund-Sync, Update-Checks oder Menüleisten-Symbole installiert.
- **`SMAppService`-Registrierungen** im App-Bundle (macOS 13+). MacSense zeigt sie an, kann sie aber nicht umschalten — verwende Systemeinstellungen → Allgemein → Anmeldeobjekte.

Die meisten lassen sich gefahrlos deaktivieren: die Eltern-App funktioniert weiter, nur ohne Auto-Start. Bei Fehlverhalten stellt die Reaktivierung des Agenten oder Wiederöffnen der App es wieder her.
