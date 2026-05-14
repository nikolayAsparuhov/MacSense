# Cachés de desarrollo

Artefactos de compilación y paquetes descargados de herramientas de desarrollo. Se reconstruyen en el siguiente uso y suelen ocupar decenas de GB en Macs de desarrollo.

## Detalles

MacSense busca cachés en más de 30 herramientas, incluyendo:

- **Xcode** — `~/Library/Developer/Xcode/DerivedData`, simuladores archivados, soporte de dispositivos.
- **Homebrew** — `~/Library/Caches/Homebrew`.
- **Ecosistema Node** — cachés globales de `npm`, `yarn`, `pnpm`.
- **Python** — cachés de wheels de `pip`, `pipenv`, `poetry`.
- **Rust** — `~/.cargo/registry/cache`.
- **Go** — `$GOPATH/pkg/mod/cache`.
- **Docker** — imágenes huérfanas, caché de build, contenedores parados.
- **JetBrains IDEs**, **Maven**, **NuGet**, **Gradle**, y más.

Eliminarlas ralentiza la *próxima* compilación de un proyecto y luego todo vuelve a la normalidad. Los artefactos activos dentro de `node_modules` o `target/` de tus proyectos nunca se tocan — solo las cachés globales compartidas.
