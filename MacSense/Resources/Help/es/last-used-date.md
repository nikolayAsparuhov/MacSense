# Fecha de último uso

El momento más reciente en que macOS registró el lanzamiento de la app. Se obtiene de los metadatos `kMDItemLastUsedDate` de Spotlight.

## Detalles

macOS actualiza esta marca cuando lanzas una app desde el Finder, el Dock, Spotlight o Launchpad. Las apps que mantienes instaladas pero nunca abres acumulan polvo aquí — exactamente las candidatas que la pestaña "Sin usar" busca.

La pestaña "Sin usar" agrupa las apps de dos formas:

- **Sin usar ≥ X días** — apps con fecha conocida más antigua que el umbral. Ordenadas, la más antigua primero.
- **Nunca abierta** — apps sin `kMDItemLastUsedDate`. Pueden estar instaladas pero sin lanzarse, o sin metadato registrado.

Umbrales preestablecidos: 30 / 60 / 90 / 180 días. Tu elección persiste entre arranques.

Tocar cualquier fila abre la hoja estándar de desinstalación — el mismo flujo que la pestaña Apps Instaladas.
