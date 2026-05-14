# Letzter Verwendungszeitpunkt

Der jüngste Moment, zu dem macOS den Start der App registriert hat. Aus den Spotlight-Metadaten `kMDItemLastUsedDate` gezogen.

## Details

macOS aktualisiert diesen Zeitstempel, wenn du eine App über Finder, Dock, Spotlight oder Launchpad startest. Apps, die du installiert behältst aber nie öffnest, sammeln hier Staub — genau die Kandidaten, die der Tab „Unbenutzt" finden soll.

Der Tab Unbenutzt gruppiert Apps zweifach:

- **Unbenutzt ≥ X Tage** — Apps mit bekanntem Datum älter als die Schwelle. Älteste zuerst sortiert.
- **Nie geöffnet** — Apps ohne `kMDItemLastUsedDate`. Sie können installiert sein, ohne je gestartet worden zu sein, oder ihre Spotlight-Metadaten wurden nicht erfasst.

Voreinstellungen: 30 / 60 / 90 / 180 Tage. Deine Wahl bleibt über Neustarts erhalten.

Tippen auf eine Zeile öffnet das Standard-Deinstallations-Sheet — derselbe Ablauf wie der Tab Installierte Apps.
