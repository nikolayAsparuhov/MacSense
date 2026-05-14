# Carte de bulles

Les cercles interactifs de l'onglet Taille de Stockage. Chaque bulle représente un dossier ; l'aire est proportionnelle à la taille récursive du dossier.

## Détails

Comment la lire :

- **Cercle plus grand = dossier plus grand.** Aire bidimensionnelle, pas rayon — un dossier deux fois plus grand a environ deux fois plus d'aire visible.
- **Cliquez sur une bulle** pour entrer dans ce dossier. La carte de droite et le fil d'Ariane se mettent à jour.
- **Rail de sélection** à gauche permet de cocher des éléments pour la corbeille. Cocher ici sélectionne des dossiers entiers.

Les petits frères et sœurs sont regroupés dans une bulle « Autres éléments » pour garder la visualisation lisible. Cliquer dessus déploie la liste latérale pour montrer chaque entrée.

La disposition est recalculée à chaque changement de fil d'Ariane — sans animation entre layouts pour garder la navigation rapide.
