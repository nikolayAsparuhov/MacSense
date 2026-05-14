# Agent d'ouverture

Un processus que macOS lance automatiquement lors de votre connexion. Certains sont essentiels (services système, assistants trousseau), d'autres sont des compagnons d'app dont vous n'avez peut-être pas besoin en permanence.

## Détails

Trois sources :

- **Système** — agents fournis par macOS dans `/System/Library/LaunchAgents`. MacSense n'y touche jamais.
- **Par utilisateur** — plists launchd dans `~/Library/LaunchAgents`. Souvent installés par des apps tierces pour la sync en arrière-plan, vérification de mises à jour ou icônes de barre de menus.
- **Intégrés** — enregistrés via `SMAppService` (voir « Ouverture intégrée »).

Les agents par utilisateur peuvent être désactivés ou supprimés sans danger — l'app parente continue de fonctionner mais perd le comportement en arrière-plan. Si quelque chose se met à mal fonctionner, réactiver l'agent ou réinstaller l'app le restaure.
