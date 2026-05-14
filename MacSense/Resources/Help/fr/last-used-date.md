# Date de dernière utilisation

Le moment le plus récent où macOS a enregistré le lancement de l'app. Tiré des métadonnées Spotlight `kMDItemLastUsedDate`.

## Détails

macOS met à jour cette date à chaque lancement via Finder, Dock, Spotlight ou Launchpad. Les apps installées mais jamais ouvertes accumulent de la poussière ici — exactement les candidates que l'onglet Inutilisées cible.

L'onglet Inutilisées regroupe vos apps de deux façons :

- **Inutilisées ≥ X jours** — apps avec une date connue plus ancienne que le seuil. Triées de la plus ancienne à la plus récente.
- **Jamais ouvertes** — apps sans `kMDItemLastUsedDate`. Elles peuvent avoir été installées sans jamais être lancées, ou les métadonnées Spotlight n'ont pas été enregistrées.

Préréglages : 30 / 60 / 90 / 180 jours. Votre choix persiste entre les lancements.

Toucher une ligne ouvre la feuille de désinstallation standard — même flux que l'onglet Apps installées.
