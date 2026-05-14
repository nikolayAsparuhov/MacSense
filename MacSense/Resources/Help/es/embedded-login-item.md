# Ítem de inicio incrustado

Un ítem de inicio registrado por la propia app vía `SMAppService` (macOS 13+). Las herramientas de terceros — incluida MacSense — no pueden desactivarlos, modificarlos ni eliminarlos por motivos de seguridad.

## Detalles

Apple introdujo `SMAppService` para reemplazar las APIs antiguas de ítems de inicio. Beneficios:

- Las apps se registran como agentes de inicio desde su propio bundle.
- macOS garantiza que nada externo pueda alterar el registro.
- El usuario mantiene control total a través de Ajustes del Sistema.

El compromiso: herramientas como MacSense pueden mostrarte estos registros pero no alternarlos. La acción "Desactivar" abre **Ajustes del Sistema → General → Ítems de inicio** en el panel correcto para que tú lo cambies.

Los ítems heredados registrados por APIs antiguas (LSSharedFileList, plists de launchd en `~/Library/LaunchAgents`) siguen siendo gestionables desde MacSense.
