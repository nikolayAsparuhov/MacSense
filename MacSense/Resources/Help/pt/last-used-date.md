# Data de último uso

O momento mais recente em que o macOS registrou o lançamento do app. Obtido dos metadados Spotlight `kMDItemLastUsedDate`.

## Detalhes

O macOS atualiza essa marca sempre que você lança um app via Finder, Dock, Spotlight ou Launchpad. Apps que você mantém instalados mas nunca abre acumulam poeira aqui — exatamente os candidatos que a aba Não Usados quer expor.

A aba Não Usados agrupa seus apps de duas formas:

- **Não usado ≥ X dias** — apps com data de último uso conhecida mais antiga que o limiar. Ordenados, mais antigos primeiro.
- **Nunca aberto** — apps sem `kMDItemLastUsedDate`. Podem ter sido instalados mas nunca rodados, ou seus metadados Spotlight não foram registrados.

Predefinições de limiar: 30 / 60 / 90 / 180 dias. Sua escolha persiste entre lançamentos.

Tocar em qualquer linha abre a folha de desinstalação padrão — mesmo fluxo da aba Apps Instalados.
