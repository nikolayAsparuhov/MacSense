# Ouverture intégrée

Une ouverture enregistrée par l'app elle-même via `SMAppService` (macOS 13+). Les outils tiers — y compris MacSense — ne peuvent pas la désactiver, modifier ou supprimer pour des raisons de sécurité.

## Détails

Apple a introduit `SMAppService` pour remplacer les anciennes APIs d'ouverture. Avantages :

- Les apps s'enregistrent comme agents d'ouverture depuis leur propre bundle.
- macOS garantit que rien d'extérieur à l'app ne peut altérer l'enregistrement.
- L'utilisateur conserve le contrôle total via Réglages du système.

Compromis : MacSense peut afficher ces enregistrements mais pas les basculer. L'action « Désactiver » ouvre **Réglages du système → Général → Ouverture** sur le bon volet pour que vous puissiez le faire.

Les ouvertures héritées enregistrées via les anciennes APIs (LSSharedFileList, plists launchd dans `~/Library/LaunchAgents`) restent gérables depuis MacSense.
