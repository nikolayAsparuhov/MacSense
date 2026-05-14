# Entwickler-Caches

Build-Artefakte und heruntergeladene Pakete von Entwicklungstools. Werden bei der nächsten Verwendung neu erstellt und belegen auf Entwickler-Macs oft Dutzende GB.

## Details

MacSense durchsucht über 30 Tools, darunter:

- **Xcode** — `~/Library/Developer/Xcode/DerivedData`, archivierte Simulatoren, Geräteunterstützung.
- **Homebrew** — `~/Library/Caches/Homebrew`.
- **Node-Ökosystem** — globale Caches `npm`, `yarn`, `pnpm`.
- **Python** — Wheel-Caches `pip`, `pipenv`, `poetry`.
- **Rust** — `~/.cargo/registry/cache`.
- **Go** — `$GOPATH/pkg/mod/cache`.
- **Docker** — verwaiste Images, Build-Cache, gestoppte Container.
- **JetBrains IDEs**, **Maven**, **NuGet**, **Gradle**, weitere.

Das Entfernen verlangsamt den *nächsten* Build eines Projekts; danach ist alles normal. Aktive Build-Artefakte in `node_modules` oder `target/` deiner Projekte werden nie angetastet — nur die geteilten globalen Caches.
