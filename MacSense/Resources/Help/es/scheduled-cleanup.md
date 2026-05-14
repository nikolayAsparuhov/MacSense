# Limpieza programada

Escaneo recurrente opcional que se ejecuta en segundo plano a una frecuencia diaria, semanal o mensual y publica una notificación con el resumen.

## Detalles

Cuando se activa, MacSense usa `NSBackgroundActivityScheduler` — la API de tareas eficientes de macOS — para ejecutar un Smart Scan sobre las categorías que has marcado. El resultado se entrega como una notificación:

> Encontrado 4,7 GB recuperables en 4 categorías. Abre MacSense para revisar.

Tocar la notificación abre MacSense en la sección Limpieza.

Restricciones importantes:

- **Nada se elimina automáticamente.** El programa notifica; tú decides qué (si algo) limpiar.
- **Las programaciones se ejecutan mientras MacSense está abierto o ha estado activo recientemente.** macOS puede retrasar las tareas en segundo plano. No hay LaunchAgent ni demonio; cerrar la app pausa la programación hasta el siguiente arranque.

El permiso de notificaciones se pide una sola vez al primer arranque. Si lo denegaste antes, la sección Programación muestra un aviso con un acceso a Ajustes del Sistema.
