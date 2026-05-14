# Cache utilisateur

Données générées par les apps stockées dans `~/Library/Caches`. Les apps les considèrent comme jetables — les perdre ralentit légèrement le prochain lancement mais ne casse jamais rien.

## Détails

Chaque app utilise le cache pour :

- Images pré-rendues, vignettes et médias décodés.
- Bundles d'actifs téléchargés que l'app peut récupérer à nouveau.
- Index de recherche et historique récent.

Les Mac modernes accumulent des gigaoctets au fil du temps, surtout avec les navigateurs, apps multimédia et outils Electron. Le premier lancement après nettoyage est légèrement plus lent ; les suivants reviennent à la normale.

MacSense ignore les caches en cours d'utilisation (fichiers verrouillés, bases de données ouvertes) et déplace le reste vers la corbeille, jamais de suppression directe.
