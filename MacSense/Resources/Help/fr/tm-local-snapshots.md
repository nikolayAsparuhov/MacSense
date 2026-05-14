# Instantanés Time Machine locaux

Instantanés horaires au niveau disque que Time Machine prend même quand votre disque de sauvegarde est débranché. Ils résident sur votre disque interne et consomment silencieusement de l'espace.

## Détails

Time Machine maintient une fenêtre glissante d'instantanés locaux pour restaurer des changements récents sans disque externe. Chaque instantané est une référence copy-on-write, donc créer un nouvel est peu coûteux — mais à mesure que vous éditez et supprimez, ils figent ces octets.

Symptômes d'accumulation :

- Le disque semble plein mais le Finder affiche de l'espace libre.
- Les octets « Purgeables » sont importants.
- Après un gros téléchargement, le supprimer ne libère pas l'espace.

MacSense exécute `tmutil thinlocalsnapshots /` pour les libérer à la demande. macOS éviste les plus anciens en premier ; les sauvegardes Time Machine sur disque externe sont intactes. À la reconnexion du disque externe, de nouveaux instantanés se créent.
