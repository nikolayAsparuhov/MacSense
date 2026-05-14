# Graphe de stockage

Une carte dossier par dossier de votre disque, où chaque élément est dimensionné par son allocation réelle sur disque. Permet de localiser ce qui mange l'espace sans deviner.

## Détails

La section Stockage construit un arbre de chaque dossier sous `/`, calcule les tailles récursives et présente deux vues :

- **Onglet Taille** — carte de bulles interactive. Cercles plus grands = dossiers plus grands. Cliquez pour entrer ; le fil d'Ariane suit votre chemin.
- **Onglet Type** — fichiers groupés par type (vidéo, audio, archives, captures…) pour voir, par exemple, que 30 Go de votre disque sont des vidéos.

La première analyse prend ~30 secondes car chaque octet sous votre dossier personnel est parcouru. MacSense met ensuite en cache un instantané sur disque pour que les visites suivantes affichent les données instantanément pendant qu'un rafraîchissement tourne en arrière-plan.

Les fichiers ne sont jamais déplacés ni supprimés depuis la vue graphe — c'est une inspection en lecture seule. Utilisez les feuilles de catégorie de Nettoyage pour réellement envoyer quelque chose à la corbeille.
