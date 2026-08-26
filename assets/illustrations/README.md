# Illustrations

Images fournies de l'extérieur. **Aucune n'est dessinée ici** — c'est la même
règle que le logo : une illustration approximée d'après une description n'est
pas l'illustration, et l'emplacement vaut mieux qu'un faux.

Ce dossier est déclaré dans `pubspec.yaml` (`assets/illustrations/`). Tout
fichier qu'on y dépose part dans le bundle sans autre manipulation.

## `bienvenue.png` — écran de bienvenue

| | |
| --- | --- |
| Chemin | `assets/illustrations/bienvenue.png` |
| Format | **PNG-24 avec canal alpha** |
| Dimensions | **1200 × 800 px** (rapport 3:2, paysage) |
| Fond | **transparent** |
| Poids | viser ≤ 400 Kio |

**Le fond doit être transparent** : l'écran la pose sur `AppColors.background`
(`#F7F7FB`), et un fond blanc opaque dessinerait un rectangle visible autour de
l'illustration.

**Les dimensions sont une cible, pas une contrainte.** L'écran réserve une
bande de 240 dp de haut et rend l'image en `BoxFit.contain` : un rapport de
forme différent est simplement centré dans la bande, jamais rogné ni déformé.
Un rapport très éloigné du 3:2 laissera en revanche des marges latérales.

1200 px de large couvre un écran de 3× sans rééchantillonnage visible :
l'illustration ne dépasse jamais ~360 dp de large dans la mise en page.

Pas de variantes `2.0x/` ni `3.0x/` : un seul fichier large que Flutter réduit
suffit, et trois fichiers à tenir d'accord finiraient par diverger.

## En attendant le fichier

`WelcomeScreen` porte un `errorBuilder` : sans le fichier — ou avec un fichier
illisible —, la bande affiche un aplat violet clair et un pictogramme discret.
C'est **visiblement un emplacement en attente**, et non un substitut qui se
ferait passer pour l'illustration. Rien à changer dans le code au moment de
déposer l'image.
