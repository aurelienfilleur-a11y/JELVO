# Illustrations

Images fournies de l'extérieur. **Aucune n'est dessinée ici** — c'est la même
règle que le logo : une illustration approximée d'après une description n'est
pas l'illustration, et l'emplacement vaut mieux qu'un faux.

Ce dossier est déclaré dans `pubspec.yaml` (`assets/illustrations/`), en entier
plutôt que fichier par fichier : tout ce qu'on y dépose part dans le bundle
sans autre manipulation, là où une déclaration nominative s'oublie et laisse
une image absente en silence. Le prix est que ce README y part aussi — quelques
kilo-octets, contre une panne qui ne se voit qu'à l'écran.

## `bienvenue.png` — écran de bienvenue

| | |
| --- | --- |
| Chemin | `assets/illustrations/bienvenue.png` |
| Format | **PNG-24 avec canal alpha** |
| Dimensions | **1200 × 800 px** (rapport 3:2, paysage) |
| Fond | **transparent** |

**Le fond doit être transparent** : l'écran la pose sur `AppColors.background`
(`#F7F7FB`), et un fond blanc opaque dessinerait un rectangle visible autour de
l'illustration. Le fichier livré l'est bien — 45 % de ses pixels sont
totalement transparents, et ses quatre coins aussi.

**Les dimensions sont une cible, pas une contrainte.** L'écran réserve une
bande de 240 dp de haut et rend l'image en `BoxFit.contain` : un rapport de
forme différent est simplement centré dans la bande, jamais rogné ni déformé.

1200 px de large couvre un écran de 3× sans rééchantillonnage visible :
l'illustration ne dépasse jamais ~390 dp de large dans la mise en page.

Pas de variantes `2.0x/` ni `3.0x/` : un seul fichier large que Flutter réduit
suffit, et trois fichiers à tenir d'accord finiraient par diverger.

### La coupe du bas commande la mise en page

Le sujet est **coupé net au bord inférieur du cadre**, à mi-cuisse — il n'y a
ni marge ni dégradé de ce côté (la boîte englobante du contenu touche `y =
hauteur`). La maquette masque cette coupe en faisant chevaucher la carte des
arguments.

D'où deux choix dans `WelcomeScreen`, qui ne sont pas décoratifs :

- **aucun espace entre l'illustration et la carte** — la coupe disparaît
  derrière son bord supérieur, au lieu de flotter au-dessus d'un vide ;
- **l'illustration va d'un bord à l'autre**, hors de la marge d'écran, la
  marge transparente du fichier (10 % à gauche, 8 % à droite) lui donnant déjà
  son air.

Une illustration de remplacement qui aurait, elle, une marge basse laisserait
un vide sous les pieds. C'est le genre de détail à revérifier en changeant de
fichier.

### Le poids : ce qui est là, et pourquoi

Le fichier pèse **876 Kio**, là où l'original annoncé en pesait 259. L'écart ne
vient pas du dépôt : la copie reçue avait été rééchantillonnée en 1536 × 1024
et réencodée en chemin, et il n'y a pas de retour en arrière — 456 000 couleurs
distinctes, contre ce qu'un rendu 3D propre en compte.

Ce qui est déposé est la réduction fidèle de cette copie en 1200 × 800, en
**alpha prémultiplié** : les zones transparentes du fichier portent du
quasi-noir, et un rééchantillonnage naïf aurait bordé les personnages d'un
liseré sombre.

**Rien n'a été quantifié ni retouché**, c'est la règle des avatars et du logo.
Mesuré au passage, pour mémoire : 6 bits par canal tomberait à 560 Kio et 5
bits à 428 Kio, pour un écart maximal de 2 et 4 sur 255 une fois composité —
invisible, mais ce n'est pas au dépôt d'en décider.

**Remplacer ce fichier par l'original de 259 Kio est strictement meilleur** :
même image, trois fois plus légère. Il suffit de l'écrire par-dessus.

## Si le fichier venait à manquer

`WelcomeScreen` porte un `errorBuilder` : sans le fichier — ou avec un fichier
illisible —, la bande affiche un aplat violet clair et un pictogramme discret.
C'est **visiblement un emplacement en attente**, et non un substitut qui se
ferait passer pour l'illustration.

Ce repli ne casse rien et ne se voit pas en CI : un test vérifie donc que le
fichier est bien là, et qu'il fait bien 1200 × 800.
