# Corbeille

Le contenu de `~/.Trash` plus les corbeilles de chaque volume monté. MacSense les vide pour que l'espace soit réellement rendu au système.

## Détails

Glisser un fichier vers la corbeille le marque seulement pour suppression — les octets restent sur le disque jusqu'au vidage. macOS affiche l'espace libéré dans Utilitaire de disque mais le considère comme utilisé tant que vous n'avez pas confirmé.

Le balayage MacSense :

- Liste tous les fichiers dans `~/.Trash` et sur chaque volume monté.
- Indique la taille totale récupérable.
- Lors du nettoyage, supprime les fichiers définitivement.

C'est la seule limpieza **non réversible** — une fois la corbeille vidée, les fichiers ont disparu. Vérifiez la liste avant de confirmer.
