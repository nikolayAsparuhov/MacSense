# Basura del sistema

Registros, archivos temporales e informes de errores que macOS o las apps instaladas dejan fuera de tu carpeta personal. Es seguro eliminarlos — el sistema regenera lo que necesite.

## Detalles

Cubre tres tipos:

- **Informes de diagnóstico** en `/Library/Logs` y `/var/log`. macOS los rota automáticamente.
- **Informes de errores** en `/Library/Application Support/CrashReporter`. Útiles justo después del fallo, inútiles meses después.
- **Restos de instalaciones** dejados por instaladores de paquetes y actualizaciones.

MacSense mueve todo a la papelera. Nada aquí contiene tus documentos ni preferencias — solo archivos generados por el sistema.
