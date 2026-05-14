# Instantáneas locales de Time Machine

Instantáneas horarias a nivel de disco que Time Machine toma incluso cuando tu disco de respaldo está desconectado. Viven en tu disco interno y consumen espacio silenciosamente.

## Detalles

Time Machine mantiene una ventana rotativa de instantáneas locales para restaurar cambios recientes sin disco externo. Cada instantánea es una referencia copy-on-write, así que una nueva es barata — pero a medida que editas y borras archivos, fija esos bytes en su sitio.

Síntomas de acumulación:

- El disco se siente lleno pero el Finder muestra espacio libre.
- Los bytes "Purgables" son grandes.
- Tras una descarga grande, borrarla no libera el espacio.

MacSense ejecuta `tmutil thinlocalsnapshots /` para liberarlas a demanda. macOS desaloja primero las más viejas; las copias de Time Machine en disco externo no se ven afectadas. Al reconectar tu disco externo, vuelven a generarse instantáneas frescas.
