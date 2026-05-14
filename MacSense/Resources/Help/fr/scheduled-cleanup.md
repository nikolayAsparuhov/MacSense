# Nettoyage planifié

Analyse récurrente optionnelle qui s'exécute en arrière-plan à une fréquence quotidienne, hebdomadaire ou mensuelle et publie une notification de résumé.

## Détails

Quand activé, MacSense utilise `NSBackgroundActivityScheduler` — l'API de tâches économe d'énergie de macOS — pour exécuter un Smart Scan sur les catégories que vous avez cochées. Le résultat est livré comme une seule notification :

> 4,7 Go récupérables trouvés dans 4 catégories. Ouvrez MacSense pour vérifier.

Toucher la notification ouvre MacSense sur la section Nettoyage.

Contraintes importantes :

- **Rien n'est supprimé automatiquement.** La planification notifie ; vous décidez quoi nettoyer.
- **Les analyses planifiées s'exécutent quand MacSense est ouvert ou récemment actif.** macOS peut différer les tâches en arrière-plan. Pas de LaunchAgent ni de démon — fermer l'app suspend la planification jusqu'au prochain lancement.

L'autorisation de notification est demandée une seule fois au premier lancement. Si vous l'avez refusée, la section Planification affiche un bandeau avec un raccourci vers Réglages du système.
