# Login-Agent

Ein Prozess, den macOS bei der Anmeldung automatisch startet. Manche sind essenziell (Systemdienste, Schlüsselbund-Helfer), andere sind App-Begleiter, die du vielleicht nicht ständig brauchst.

## Details

Drei Quellen:

- **System** — von macOS gelieferte Agenten in `/System/Library/LaunchAgents`. MacSense fasst sie nie an.
- **Pro Benutzer** — launchd-Plists in `~/Library/LaunchAgents`. Häufig von Drittanbieter-Apps installiert für Hintergrund-Sync, Update-Checks oder Menüleisten-Symbole.
- **Eingebettet** — über `SMAppService` registriert (siehe „Eingebettetes Anmeldeobjekt").

Pro-Benutzer-Agenten lassen sich sicher deaktivieren oder entfernen — die zugehörige App läuft weiter, verliert aber das Hintergrundverhalten. Wenn etwas anfängt, falsch zu funktionieren, stellt die Reaktivierung des Agenten oder Neuinstallation der App es wieder her.
