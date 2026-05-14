# Caches de desenvolvimento

Artefatos de build e pacotes baixados de ferramentas de desenvolvimento. Reconstroem na próxima utilização e rotineiramente ocupam dezenas de gigabytes em máquinas de devs.

## Detalhes

O MacSense procura caches em mais de 30 ferramentas, incluindo:

- **Xcode** — `~/Library/Developer/Xcode/DerivedData`, simuladores arquivados, suporte a dispositivos.
- **Homebrew** — `~/Library/Caches/Homebrew`.
- **Ecossistema Node** — caches globais `npm`, `yarn`, `pnpm`.
- **Python** — caches de wheels `pip`, `pipenv`, `poetry`.
- **Rust** — `~/.cargo/registry/cache`.
- **Go** — `$GOPATH/pkg/mod/cache`.
- **Docker** — imagens órfãs, cache de build, contêineres parados.
- **JetBrains IDEs**, **Maven**, **NuGet**, **Gradle**, e mais.

Removê-los desacelera o *próximo* build de um projeto e depois tudo volta ao normal. Artefatos ativos dentro de `node_modules` ou `target/` dos seus projetos nunca são tocados — apenas os caches globais compartilhados.
