# Polices

## `NotoColorEmoji.ttf` — le repli des emojis

Le web ne garantit **aucune** police d'emojis. Selon la machine, un cœur tapé au
clavier iPhone s'affichait en rouge, en noir et blanc, ou pas du tout : le
moteur prenait le premier glyphe qu'il trouvait, et sur beaucoup de Linux c'est
un contour monochrome. Le rendu était donc incohérent d'un poste à l'autre, et
d'un emoji à l'autre sur le même poste.

La police est déclarée dans `pubspec.yaml` sous la famille `NotoColorEmoji`, et
`AppTypography` la pose en `fontFamilyFallback` sur **tous** ses styles.

### Le repli ne suffit pas

Il n'est consulté que pour les caractères qu'Inter ne couvre **pas** — or Inter
en couvre trente-sept, dont `❤ ⚠ ☀ ⬆ ♥ © ® ™ ‼ ⁉`, les flèches et `⬜`. Pour
ceux-là Inter gagne, le repli n'est jamais atteint, et le glyphe sorti est
noir : c'est le défaut du « cœur du clavier iPhone qui apparaît en cœur noir ».
Le sélecteur `U+FE0F` n'y change rien, la résolution de police se faisant
caractère par caractère.

Le texte saisi par quelqu'un passe donc par `EmojiText`
(`lib/core/widgets/emoji_text.dart`), qui donne la police d'emojis en police
**principale** aux suites concernées. Le repli, lui, reste utile pour tout le
reste.

### Quelle variante, et pourquoi

Noto Color Emoji existe en deux encodages, et l'écart de poids est le double :

| Variante | Table | Brut | gzip |
| --- | --- | --- | --- |
| bitmap | `CBDT`/`CBLC` | 10,18 Mio | **9,43 Mio** |
| **vectorielle (retenue)** | `COLR`/`CPAL` | 4,76 Mio | **2,69 Mio** |

Le bitmap embarque une image PNG par emoji : déjà compressé, il ne gagne rien à
la compression du serveur. La variante COLRv1 est un tracé vectoriel, que gzip
réduit encore de moitié. **C'est 2,69 Mio contre 9,43 Mio sur le fil**, pour un
rendu que rien ne distingue à la taille d'une bulle.

Le rendu en couleur a été **constaté**, pas supposé : un test rend « ❤️🎉👍 » et
vérifie que l'image produite contient de vraies teintes — rouge `#FF2F2F`,
jaune — et non des gris. Une police monochrome ne produirait que `r = g = b`.

La variante servie par Google Fonts (`fonts.gstatic.com`) pèse 23,95 Mio : c'est
la même COLRv1, non optimisée. Celle du dépôt `googlefonts/noto-emoji` est la
bonne.

### Un sous-ensemble ne conviendrait pas

C'est la question qu'on se pose en voyant le poids, et la réponse est **non**,
pour une raison de fond : le texte concerné est **saisi par les utilisateurs**.
Sous-ensembler suppose de connaître à l'avance les emojis employés — or
quelqu'un tape 🫠 et obtient un carré vide, sans que rien ne l'ait annoncé. Le
défaut serait exactement celui qu'on corrige, en plus sournois : intermittent.

Deux pistes qui, elles, tiennent :

- **ne pas embarquer sur mobile.** iOS et Android ont déjà une police d'emojis
  système : les 4,76 Mio n'y servent à rien. Flutter ne sait pas exclure un
  asset par plateforme, il faudrait un chargement à l'exécution
  (`FontLoader`) réservé au web. C'est le vrai gain restant ;
- **servir la police depuis le réseau sur le web**, comme `google_fonts` le
  fait déjà pour Inter. Cela retire le poids du bundle mais rend le rendu
  dépendant d'un aller-retour, et le premier affichage montrerait le défaut
  qu'on vient de corriger.

Les deux sont des arbitrages, pas des oublis. La police embarquée est le
comportement le plus prévisible, et c'est celui qui est livré.
