# Fichiers système

Journaux, fichiers temporaires et rapports de plantage que macOS ou les apps installées laissent en dehors de votre dossier personnel. Suppression sans risque — le système régénère ce dont il a besoin.

## Détails

Trois sources :

- **Rapports de diagnostic** dans `/Library/Logs` et `/var/log`. macOS les fait tourner automatiquement.
- **Rapports de plantage** dans `/Library/Application Support/CrashReporter`. Utiles juste après un crash, inutiles des mois plus tard.
- **Restes d'installation** laissés par les installateurs et les mises à jour.

MacSense déplace tout vers la corbeille. Rien ici ne contient vos documents ni vos préférences — seulement des artefacts générés par le système.
