# Icônes de Jelvo — fichiers attendus

Ces fichiers sont **fournis**, pas générés. Les emplacements sont déjà câblés
dans `web/manifest.json`, `web/index.html` et `web/jelvo_push_sw.js` : déposer
les images aux noms exacts ci-dessous suffit, il n'y a aucun code à toucher.

Le fichier maître est le monogramme **jv** blanc sur fond indigo dégradé, à
coins arrondis. **Deux des sept fichiers ne veulent pas ces coins** — voir
« Trois variantes », plus bas.

## Ce qu'il faut déposer

| Fichier | Taille | Variante | Où il sert |
| --- | --- | --- | --- |
| `web/icons/Icon-180.png` | 180 × 180 | **B — carré plein** | écran d'accueil iOS |
| `web/icons/Icon-192.png` | 192 × 192 | A — le maître | manifeste, vignette de notification |
| `web/icons/Icon-512.png` | 512 × 512 | A — le maître | manifeste, écran de lancement |
| `web/icons/Icon-maskable-192.png` | 192 × 192 | **B — carré plein, logo réduit** | manifeste, `purpose: maskable` |
| `web/icons/Icon-maskable-512.png` | 512 × 512 | **B — carré plein, logo réduit** | manifeste, `purpose: maskable` |
| `web/icons/Icon-badge-96.png` | 96 × 96 | **C — silhouette** | barre d'état Android |
| `web/favicon.png` | 32 × 32 | A — le maître | onglet du navigateur |

Format : PNG dans tous les cas.

## Trois variantes

### A — le maître, tel quel

Coins arrondis compris, transparence autorisée autour d'eux. Simple
redimensionnement. Quatre fichiers sur sept.

### B — carré plein, sans coins arrondis

Le dégradé indigo va **jusqu'aux quatre bords**, et le fichier est **opaque**.
Deux raisons distinctes, qui tombent sur les mêmes fichiers :

- **iOS applique son propre masque** — un carré à coins super-elliptiques.
  Lui donner une image déjà arrondie produit un **double arrondi** : on voit
  l'angle du masque système déborder autour de l'angle du logo. Et iOS **ne
  respecte pas la transparence** : ce qui est transparent devient noir.
- **Les icônes masquables sont rognées** par le système, souvent en cercle.
  Un fond qui s'arrête avant le bord laisse apparaître un liseré, ou un
  disque de couleur système.

**Les deux `maskable` demandent en plus un logo plus petit** : tout ce qui
compte doit tenir dans les **80 % centraux** — un cercle centré de 154 px pour
le 192, de 410 px pour le 512. En pratique, le `jv` occupe environ 60 % de la
largeur au lieu de 75 % dans le maître. **Ce n'est donc pas un
redimensionnement du maître**, c'est un recadrage plus large.

Le point du `j` compte dans la zone sûre : c'est la partie la plus haute du
monogramme, et c'est elle qui se fera rogner en premier.

### C — silhouette monochrome sur fond transparent

**Android ne garde que l'alpha** du badge et en fait une silhouette blanche.
Une icône en couleur y devient un carré plein. Il faut donc le `jv` seul —
point du `j` compris — en pixels opaques, **sans aucun fond**.

C'est le seul fichier vraiment facultatif : sans lui, Android affiche son
propre symbole, et iOS ignore le badge de toute façon.

## Où la transparence est nécessaire, et où elle nuit

| Fichier | Transparence |
| --- | --- |
| `Icon-badge-96.png` | **obligatoire** — c'est elle qui porte la forme |
| `Icon-192`, `Icon-512`, `favicon` | tolérée autour des coins arrondis |
| `Icon-180`, les deux `maskable` | **à proscrire** — iOS compose sur du noir, le masque révèle le vide |

## Après le dépôt, sur iPhone

Remplacer les fichiers ne suffit pas à voir l'icône changer : **iOS fige
l'icône de l'application installée**. Il faut retirer Jelvo de l'écran
d'accueil puis le réinstaller — ce qui **détruit l'abonnement push** et
oblige à réactiver les notifications dans Profil → Paramètres.

## Hors périmètre pour l'instant

`ios/Runner/Assets.xcassets/AppIcon.appiconset/` et
`android/app/src/main/res/mipmap-*/` portent les icônes des **applications
natives**, qui ont leurs propres jeux de tailles. Seule la cible web est
compilée et vérifiée aujourd'hui ; ces dossiers restent ceux du gabarit
Flutter.
