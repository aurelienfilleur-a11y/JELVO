# Icônes de Jelvo — fichiers attendus

Ces fichiers sont **fournis**, pas générés. Les emplacements sont déjà câblés
dans `web/manifest.json`, `web/index.html` et `web/jelvo_push_sw.js` : déposer
les images aux noms exacts ci-dessous suffit, il n'y a aucun code à toucher.

## Ce qu'il faut déposer

| Fichier | Taille | Où il sert | Contrainte |
| --- | --- | --- | --- |
| `Icon-180.png` | 180 × 180 | icône de l'écran d'accueil **iOS** | **opaque**, carrée, sans coins arrondis |
| `Icon-192.png` | 192 × 192 | manifeste, vignette des notifications | fond opaque conseillé |
| `Icon-512.png` | 512 × 512 | manifeste, écran de lancement | fond opaque conseillé |
| `Icon-maskable-192.png` | 192 × 192 | manifeste, `purpose: maskable` | logo dans les **80 % centraux** |
| `Icon-maskable-512.png` | 512 × 512 | manifeste, `purpose: maskable` | logo dans les **80 % centraux** |
| `Icon-badge-96.png` | 96 × 96 | silhouette Android de la barre d'état | **monochrome sur fond transparent** |
| `../favicon.png` | 32 × 32 | onglet du navigateur | lisible en tout petit |

Format : PNG dans tous les cas.

## Les trois contraintes qui ne se devinent pas

**Les icônes masquables ne sont pas les mêmes images en plus petit.** Le
système les rogne, souvent en cercle : ce qui dépasse des 80 % centraux est
perdu. Il faut donc la même image avec **plus de marge autour**, et un fond
qui couvre tout le carré — un fond transparent laisserait apparaître un
disque de couleur système.

**iOS ne respecte pas la transparence** : il compose sur du noir. Un logo
livré sur fond transparent donnerait un logo sur fond noir sur l'écran
d'accueil. `Icon-180.png` doit porter son fond. iOS applique par ailleurs
lui-même les coins arrondis : les pré-arrondir donne un double arrondi.

**Le badge Android ne garde que l'alpha.** Le système en fait une silhouette
blanche : une icône en couleur y devient un carré plein. Il faut une forme
pleine unie sur fond transparent.

## Après le dépôt, sur iPhone

Remplacer les fichiers ne suffit pas à voir l'icône changer : **iOS fige
l'icône de l'application installée**. Il faut retirer Jelvo de l'écran
d'accueil puis le réinstaller — ce qui **détruit l'abonnement push** et
oblige à réactiver les notifications dans Profil → Paramètres.
