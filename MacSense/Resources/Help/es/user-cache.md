# Caché de usuario

Datos generados por las apps que viven en `~/Library/Caches`. Las apps los tratan como almacenamiento desechable — perderlos solo ralentiza el siguiente arranque, nunca rompe nada.

## Detalles

Cada app usa caché para:

- Imágenes pre-renderizadas, miniaturas y medios decodificados.
- Paquetes de recursos descargados que la app puede volver a obtener.
- Índices de búsqueda y búsquedas recientes.

Los Mac modernos acumulan gigabytes con el tiempo, sobre todo de navegadores, apps multimedia y herramientas Electron. El primer arranque tras la limpieza es algo más lento; los siguientes vuelven a la normalidad.

MacSense omite las cachés en uso activo (archivos bloqueados, bases de datos abiertas) y mueve el resto a la papelera, nunca elimina directamente.
