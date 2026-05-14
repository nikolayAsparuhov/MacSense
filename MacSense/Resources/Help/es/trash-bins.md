# Papelera

El contenido de `~/.Trash` y de las papeleras de cualquier volumen externo. MacSense las vacía para que el espacio vuelva al sistema.

## Detalles

Arrastrar a la papelera solo marca para borrar — los bytes siguen en el disco hasta que se vacía. macOS muestra el espacio recuperado pero lo trata como ocupado hasta que confirmas.

La limpieza de MacSense:

- Lista todos los archivos en `~/.Trash` y en cada volumen montado.
- Reporta el tamaño total recuperable.
- Al limpiar, los elimina permanentemente.

Es la única limpieza **no reversible** — una vez vaciada, los archivos se han ido. Revisa la lista antes de confirmar.
