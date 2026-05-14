# Caches de développement

Artefacts de compilation et paquets téléchargés des outils dev. Reconstruits à la prochaine utilisation et occupent souvent des dizaines de Go sur les Mac de développement.

## Détails

MacSense scrute plus de 30 outils, dont :

- **Xcode** — `~/Library/Developer/Xcode/DerivedData`, simulateurs archivés, support d'appareils.
- **Homebrew** — `~/Library/Caches/Homebrew`.
- **Écosystème Node** — caches globaux `npm`, `yarn`, `pnpm`.
- **Python** — caches wheel `pip`, `pipenv`, `poetry`.
- **Rust** — `~/.cargo/registry/cache`.
- **Go** — `$GOPATH/pkg/mod/cache`.
- **Docker** — images orphelines, cache de build, conteneurs arrêtés.
- **JetBrains IDEs**, **Maven**, **NuGet**, **Gradle**, et plus.

Les supprimer ralentit la *prochaine* compilation puis tout revient à la normale. Les artefacts actifs dans `node_modules` ou `target/` de vos projets ne sont jamais touchés — seulement les caches globaux partagés.
