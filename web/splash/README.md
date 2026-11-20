# Écrans de lancement d'iOS

Deux fichiers, **générés**, jamais retouchés à la main :

```bash
node tool/preparer_ecrans_de_lancement.js
```

Aucun prérequis : rien n'est compilé, rien n'est servi, rien n'est
photographié.

## Deux fichiers, et non deux par modèle

La version précédente en portait **vingt-quatre** : l'écran de lancement de la
page photographié à la taille exacte de douze iPhone. Cela n'a pas tenu, pour
une raison qui était dans l'approche et non dans la liste — Apple sort des
tailles chaque année, et **une taille absente retombe en silence sur ce que le
système décide**. Une liste de modèles est en retard par construction.

Ce qui a permis de s'en passer, c'est de **ne plus dessiner le logo ici**.

## Le logo n'est dessiné qu'à un seul endroit

C'est tout le correctif. Le logo apparaissait deux fois — une fois par iOS au
lancement, une fois par le voile de la page — à deux tailles, d'où le saut. Les
captures par modèle essayaient de faire **coïncider** ces deux tailles ; il
suffit qu'il n'y en ait qu'une.

Le voile de `web/index.html` est désormais le seul à porter le logo, et il
garde la plus grande des deux tailles (96 px). Ces deux fichiers ne sont qu'un
**aplat** de la couleur de fond.

| | Avant | Après |
| --- | --- | --- |
| fichiers | 24 | 2 |
| poids | 2,5 Mio | 30 Kio |
| dépend d'une liste de modèles | oui | **non** |
| endroits qui dessinent le logo | 2 | **1** |

## Pourquoi un aplat suffit là où il fallait une taille exacte

**Un aplat n'a pas de géométrie.** iOS peut l'étirer, le rogner ou le centrer :
cela ne se voit pas. Il ne reste donc qu'une *proportion* à viser, et non une
taille — celle des iPhone depuis l'iPhone X, que les dimensions du générateur
reprennent (1320 × 2868). Sur un écran d'une autre proportion, le pire cas est
une bande de quelques pixels, à comparer à l'écran blanc d'avant.

**Rien ne dépend de ces fichiers.** Si iOS refusait une image sans requête de
taille — le point que la documentation d'Apple ne tranche pas —, on retombe sur
son écran à lui, c'est-à-dire sur le comportement d'aujourd'hui pour tout
appareil absent de l'ancienne liste. Le logo resterait unique de toute façon :
c'est le voile qui le porte. Leur seul rôle est d'épargner le blanc que Safari
affiche sinon pendant que la page charge.

Les deux teintes sont **lues dans `web/index.html`**, qui les tient déjà de
`JelvoColors`. Les recopier dans le générateur en ferait une troisième source,
et c'est toujours la troisième qui dérive.

## Sur un iPhone, remplacer les fichiers ne suffit pas

**iOS fige les métadonnées de l'application installée.** Il faut retirer
l'icône de l'écran d'accueil et réinstaller — ce qui **détruit l'abonnement
push** et oblige à réactiver les notifications, exactement comme pour l'icône
elle-même (voir `web/icons/README.md`).

C'est la première chose à vérifier si le logo saute encore : une application
installée avant ce changement ne l'a jamais lu.

## Ce qui ne se règle pas ici

La **transition d'ouverture d'iOS** — l'icône de l'écran d'accueil qui grandit
jusqu'au cadre de l'application — appartient au système. Elle existe pour
toute application, native comprise, et aucune page ne peut s'en abstraire.

`test/launch_screen_test.dart` confronte ces fichiers aux balises de
`web/index.html`, et contrôle qu'aucune balise ne porte de dimension — le
contrôle négatif qui empêche la liste de modèles de revenir.
