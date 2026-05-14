# Smart Scan

Un seul bouton qui analyse toutes les catégories de nettoyage et totalise l'espace récupérable, pour voir l'impact avant de décider quoi nettoyer.

## Détails

Smart Scan parcourt chaque catégorie en séquence — Fichiers système, Cache utilisateur, Corbeille, Espace purgeable, Caches dev — et agrège les résultats. C'est en lecture seule ; rien n'est supprimé par l'analyse elle-même.

Une fois terminée, la vue Nettoyage affiche une carte par catégorie avec :

- **Taille récupérable** pour cette catégorie.
- **Nettoyage en un clic** qui déplace les fichiers vers la corbeille.
- **Feuille de détail** pour inspecter les éléments avant nettoyage.

Smart Scan alimente aussi l'**Analyse planifiée** optionnelle — une fois planifiée, MacSense exécute la même logique en arrière-plan et publie une notification de résumé.
