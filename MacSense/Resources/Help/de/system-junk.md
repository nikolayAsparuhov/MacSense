# Systemmüll

Protokolle, temporäre Dateien und Absturzberichte, die macOS oder installierte Apps außerhalb deines Benutzerordners ablegen. Sicher zu entfernen — das System erstellt neu, was es noch braucht.

## Details

Drei Eimer:

- **Diagnoseberichte** in `/Library/Logs` und `/var/log`. macOS rotiert sie automatisch.
- **Absturzberichte** unter `/Library/Application Support/CrashReporter`. Direkt nach einem Absturz nützlich, Monate später nutzlos.
- **Installations-Reste** von Paket-Installern und App-Updates.

MacSense verschiebt alles in den Papierkorb. Nichts hier enthält Dokumente oder Einstellungen — nur Systemartefakte.
