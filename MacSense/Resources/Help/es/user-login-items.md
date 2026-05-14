# Ítems de inicio de usuario

Apps y ayudantes que se inician automáticamente cuando inicias sesión en tu Mac. Pertenecen a tu cuenta de usuario, así que desactivarlos o eliminarlos solo afecta a tu sesión.

## Detalles

Los ítems de inicio de usuario provienen de dos sitios:

- **Plists de launchd** en `~/Library/LaunchAgents` — habitualmente instalados por apps de terceros para sincronización en segundo plano, comprobación de actualizaciones o ítems de barra de menús.
- **Registros `SMAppService`** declarados dentro de un bundle de app (macOS 13+). MacSense los muestra pero no puede alternarlos — usa Ajustes del Sistema → General → Ítems de inicio.

La mayoría son seguros de desactivar: la app principal sigue funcionando, solo sin el comportamiento de auto-inicio. Si algo empieza a fallar, reactivar el agente o reabrir la app lo restaura.
