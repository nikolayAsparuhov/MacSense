# Eingebettetes Anmeldeobjekt

Ein Anmeldeobjekt, das die App selbst über `SMAppService` (macOS 13+) registriert. Drittanbieter-Tools — auch MacSense — können diese aus Sicherheitsgründen nicht deaktivieren, ändern oder löschen.

## Details

Apple führte `SMAppService` ein, um die alten Anmeldeobjekt-APIs zu ersetzen. Vorteile:

- Apps registrieren sich aus ihrem eigenen Bundle als Login-Agenten.
- macOS garantiert, dass nichts außerhalb der App die Registrierung manipulieren kann.
- Die Nutzerin behält volle Kontrolle über Systemeinstellungen.

Der Kompromiss: Tools wie MacSense können diese Registrierungen anzeigen, aber nicht umschalten. Die Aktion „Deaktivieren" öffnet **Systemeinstellungen → Allgemein → Anmeldeobjekte** im richtigen Bereich.

Alte Anmeldeobjekte (LSSharedFileList, launchd-Plists in `~/Library/LaunchAgents`) bleiben über MacSense verwaltbar.
