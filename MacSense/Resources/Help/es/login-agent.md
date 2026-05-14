# Agente de inicio

Un proceso que macOS arranca automáticamente al iniciar sesión. Algunos son esenciales (servicios del sistema, ayudantes del llavero), otros son acompañantes de apps que quizás no necesites siempre.

## Detalles

Los agentes de inicio vienen de tres fuentes:

- **Sistema** — agentes integrados en `/System/Library/LaunchAgents`. MacSense nunca los toca.
- **Por usuario** — plists de launchd en `~/Library/LaunchAgents`. A menudo instalados por apps de terceros para sincronización en segundo plano, comprobaciones de actualización o ítems de barra de menús.
- **Incrustados** — registrados vía `SMAppService` (ver "Ítem de inicio incrustado").

Los agentes por usuario pueden desactivarse o eliminarse de forma segura — la app sigue funcionando pero pierde el comportamiento en segundo plano que el agente proporcionaba. Si algo falla, reactivar el agente o reinstalar la app lo restaura.
