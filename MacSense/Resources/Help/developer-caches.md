# Developer Caches

Build artifacts and downloaded packages from dev tools. These rebuild on next use and routinely take tens of gigabytes on developer machines.

## Details

MacSense looks for caches across 30+ tools, including:

- **Xcode** — `~/Library/Developer/Xcode/DerivedData`, archived simulators, device support.
- **Homebrew** — `~/Library/Caches/Homebrew`.
- **Node ecosystem** — `npm`, `yarn`, `pnpm` global caches.
- **Python** — `pip`, `pipenv`, `poetry` wheel caches.
- **Rust** — `~/.cargo/registry/cache`.
- **Go** — `$GOPATH/pkg/mod/cache`.
- **Docker** — dangling images, build cache, stopped containers.
- **JetBrains IDEs**, **Maven**, **NuGet**, **Gradle**, plus more.

Removing these slows the *next* build of a project (the tool re-downloads / re-compiles what it needs) and then everything is back to normal. Active build artifacts inside `node_modules` or `target/` directories of your projects are never touched — only the shared global caches.
