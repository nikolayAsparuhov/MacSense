# Espace purgeable

Octets que macOS considère déjà comme récupérables mais qu'il n'a pas encore évincés. Forcer une purge dit au système « j'ai besoin de cet espace maintenant » et l'oblige à libérer ces fichiers.

## Détails

APFS conserve plusieurs couches de stockage évincable :

- **Fichiers synchronisés iCloud** ayant une copie locale et une copie cloud.
- **Instantanés Time Machine locaux** (voir l'entrée dédiée).
- **Caches gérés par macOS** marqués comme évincables sous pression.

Le Finder rapporte les octets purgeables sous « Disponible » mais pas dans « Utilisé » ni « Libre ». Ils apparaissent libres pour macOS mais utilisés pour les apps qui calculent l'espace à l'ancienne. La purge les libère réellement.

MacSense appelle les mêmes routines (`diskutil apfs deleteContainer`, `tmutil thinlocalsnapshots`) que le système sous pression. Aucune perte — chaque octet purgeable a une autre copie ailleurs.
