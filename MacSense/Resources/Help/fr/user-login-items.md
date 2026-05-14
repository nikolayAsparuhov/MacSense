# Ouvertures utilisateur

Apps et assistants qui démarrent automatiquement à votre connexion. Possédés par votre compte utilisateur, donc les désactiver ou les supprimer n'affecte que votre session.

## Détails

Les ouvertures utilisateur viennent de deux sources :

- **Plists launchd** dans `~/Library/LaunchAgents` — généralement installés par des apps tierces pour la sync en arrière-plan, vérification de mises à jour ou icônes de barre de menus.
- **Enregistrements `SMAppService`** déclarés dans le bundle d'une app (macOS 13+). MacSense les affiche mais ne peut pas les basculer — utilisez Réglages du système → Général → Ouverture.

La plupart sont sans risque à désactiver : l'app parente continue de fonctionner, juste sans le comportement de démarrage automatique. Si quelque chose se met à mal fonctionner, réactiver l'agent ou rouvrir l'app le restaure.
