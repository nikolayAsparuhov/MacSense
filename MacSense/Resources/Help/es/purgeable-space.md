# Espacio purgable

Bytes que macOS ya considera recuperables pero aún no ha desalojado. Forzar una purga le indica "necesito este espacio ahora" y los libera.

## Detalles

APFS mantiene varias capas de almacenamiento desalojable suave:

- **Archivos sincronizados con iCloud** que tienen copia local y en la nube.
- **Instantáneas locales de Time Machine** (ver entrada dedicada).
- **Cachés gestionadas por macOS** marcadas como desalojables ante presión de disco.

El Finder reporta los bytes purgables como "Disponible" pero no los muestra en "Usado" o "Libre". Aparecen libres para macOS pero usados para apps que calculan espacio a la antigua. Purgarlos los libera realmente.

MacSense usa las mismas rutas (`diskutil apfs deleteContainer`, `tmutil thinlocalsnapshots`) que el sistema bajo presión de disco. Sin pérdida de datos — cada byte purgable tiene otra copia en algún sitio.
