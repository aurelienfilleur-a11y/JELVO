# Icônes de Jelvo

Les sept fichiers sont **découpés dans le logo fourni**, jamais dessinés :

```bash
python3 tool/preparer_icones.py
```

La source est `tool/logo/jelvo-icone-source.png` — monogramme `jv` blanc sur
fond indigo dégradé, carré, 1254 × 1254. **Changer le logo, c'est remplacer
ce fichier et relancer la commande.** Rien d'autre à toucher : les sept
emplacements sont câblés dans `web/manifest.json`, `web/index.html` et
`web/jelvo_push_sw.js`.

| Fichier | Taille | Où il sert |
| --- | --- | --- |
| `Icon-180.png` | 180 × 180 | écran d'accueil iOS (`apple-touch-icon`) |
| `Icon-192.png` | 192 × 192 | manifeste, vignette de notification |
| `Icon-512.png` | 512 × 512 | manifeste, écran de lancement |
| `Icon-maskable-192.png` | 192 × 192 | manifeste, `purpose: maskable` |
| `Icon-maskable-512.png` | 512 × 512 | manifeste, `purpose: maskable` |
| `Icon-badge-96.png` | 96 × 96 | barre d'état Android — silhouette |
| `../favicon.png` | 32 × 32 | onglet du navigateur — **recadré à 62 %** |

## Le recentrage, et pourquoi il n'altère pas le tracé

Dans le fichier fourni, le monogramme n'était **pas centré** : marges de 333
à gauche contre 366 à droite, 357 en haut contre 375 en bas. Il est donc
décalé de 16 px vers la gauche et de 9 px vers le haut.

Le script le remet d'aplomb, et deux choix de méthode s'imposaient :

- **la translation est entière**, jamais sous-pixellaire. Un décalage de 16,5
  px aurait demandé un rééchantillonnage, c'est-à-dire une altération du
  tracé. Il reste donc un pixel d'écart résiduel — 349 contre 350 —, parce
  que le jeu à répartir est impair. C'est le prix à payer pour ne pas toucher
  au dessin, et il est invisible ;
- **le dégradé est prolongé, pas recopié.** La bande libérée est remplie par
  une droite des moindres carrés ajustée sur soixante-quatre colonnes.
  Prolonger depuis deux pixels voisins, comme au premier essai, multiplie
  leur écart par la distance : le bruit du dégradé, invisible à l'échelle du
  pixel, devenait une bande claire de dix-sept pixels le long du bord. Le
  raccord actuel s'écarte de 1 à 3 niveaux sur 255, contre 0 à 2 entre deux
  colonnes voisines du dégradé d'origine.

## Le favicon est le seul recadré

À 32 px, le cadrage d'origine ne laisse que **quatorze pixels** au monogramme,
le reste étant du fond : le `jv` y devient une tache. Le favicon est donc
découpé dans les **62 % centraux** du maître avant réduction. C'est un
recadrage, pas une déformation ni un redessin, et c'est le seul format où le
manque de place se voit.

## Les masquables sont la même image, et c'est vérifié

Une icône masquable est rognée par le système, souvent en cercle : tout ce
qui compte doit tenir dans les **80 % centraux**. C'est en général une image
distincte, avec plus de marge.

Ici, non : le monogramme du fichier fourni a une demi-diagonale de **380 px**
pour un rayon sûr de **502 px**. Il tient déjà, largement. Les deux fichiers
`maskable` sont donc le même rendu que les autres.

**Le script le contrôle à chaque exécution** et s'arrête si ce n'est plus
vrai. Une source recadrée plus serré demanderait de vraies variantes, et
mieux vaut un échec net qu'une icône dont le point du `j` se fait rogner.

## Ce que le format impose ailleurs

- **iOS ne respecte pas la transparence** — il compose sur du noir — et pose
  lui-même les coins arrondis. La source est carrée et opaque : c'est
  exactement ce qu'il faut, et une source déjà arrondie donnerait un double
  arrondi.
- **Le badge Android ne garde que l'alpha.** Une icône en couleur y devient
  un carré plein. `Icon-badge-96.png` est donc la silhouette du monogramme,
  blanche sur fond transparent, extraite du même fichier par seuillage de la
  luminance — l'anticrénelage des bords est conservé.

## Après le dépôt, sur iPhone

Remplacer les fichiers ne suffit pas à voir l'icône changer : **iOS fige
l'icône de l'application installée**. Il faut retirer Jelvo de l'écran
d'accueil puis le réinstaller — ce qui **détruit l'abonnement push** et
oblige à réactiver les notifications dans Profil → Paramètres.

## Hors périmètre

`ios/Runner/Assets.xcassets/AppIcon.appiconset/` et
`android/app/src/main/res/mipmap-*/` portent les icônes des **applications
natives**, qui ont leurs propres jeux de tailles. Seule la cible web est
compilée et vérifiée ; ces dossiers restent ceux du gabarit Flutter.
