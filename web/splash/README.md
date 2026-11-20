# Écrans de lancement d'iOS

Ces fichiers sont **générés**, jamais retouchés à la main :

```bash
flutter build web                          # ils sont photographiés depuis build/web
node tool/preparer_ecrans_de_lancement.js
```

## Pourquoi ils existent

Une application ajoutée à l'écran d'accueil en affichait **deux à la suite** :
celui qu'iOS fabrique — fond du `manifest.json`, icône à la taille qu'iOS
décide — puis celui de la page. Le logo changeait donc de taille entre les
deux, et le fond de couleur en mode sombre, le manifeste ne sachant pas
varier.

Les déclarer supprime le premier des deux : iOS affiche alors exactement ce
que la page affichera ensuite.

## Pourquoi une capture, et non un dessin

Un générateur qui redessinerait recopierait la géométrie de la page — taille
du logo, rayon des coins, couleur du fond — et deviendrait une seconde
source, qui dérive au premier changement de CSS. Ici on photographie la
**vraie page** à la taille exacte de chaque appareil : la coïncidence n'est
pas visée, elle est obtenue par construction.

Le générateur s'arrête si le logo ne s'est pas chargé. Sans ce contrôle,
l'élément restant en place, la capture serait écrite quand même et l'écran de
lancement afficherait un carré vide sans que rien ne l'ait dit.

## Ce que la liste couvre, et ce qu'elle ne couvre pas

**iOS n'accepte que des dimensions exactes.** Une taille absente retombe sur
l'écran fabriqué par le système, donc sur l'ancien défaut. Les douze iPhone en
**portrait** sont couverts, en clair et en sombre.

Sont écartés, et c'est un arbitrage :

| Écarté | Pourquoi |
| --- | --- |
| le **paysage** | on ne lance pas une application d'agenda de téléphone en paysage, et cela doublerait la liste |
| l'**iPad** | la cible n'a jamais été éprouvée, et ses tailles sont aussi nombreuses que celles des iPhone |

Une réserve qui ne se devine pas : la variante est choisie par
`prefers-color-scheme`, c'est-à-dire par le réglage **du téléphone**. Quelqu'un
qui a explicitement choisi « Clair » alors que son téléphone est en sombre
verra donc un écran de lancement sombre, puis une application claire. C'est
plus étroit que le défaut d'avant — où le fond ne correspondait *jamais* en
sombre — mais ce n'est pas nul.

`test/launch_screen_test.dart` confronte ces fichiers aux balises de
`web/index.html` : un appareil ajouté au générateur sans sa balise fait
échouer les tests, plutôt que de retomber en silence.
