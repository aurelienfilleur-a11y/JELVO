# CLAUDE.md — Jelvo

Application Flutter de gestion d'emploi du temps personnel et de groupe.
Cibles : **web**, **iOS**, **Android**. Interface et code en **français**.

---

## Commandes

```bash
flutter pub get                  # dépendances
flutter run -d chrome            # lancer sur le web
flutter test                     # tests (widget tests dans test/)
flutter analyze                  # analyse statique — doit rester vide
dart format .                    # formatage — vérifié en CI
flutter build web --release --base-href /jelvo/

supabase/verification/rejouer.sh # compile et appelle le SQL — voir plus bas
supabase/verification/appliquer.sh --essai   # ce qui serait appliqué en base
supabase/verification/essai_connexion.sh     # éprouve le nettoyage de l'URL
```

Deux workflows tournent sur `main` :

| Workflow | Déclencheur | Rôle |
| --- | --- | --- |
| `deploy-web.yml` | push et pull request | format, analyse, tests, build, publication |
| `migrations-supabase.yml` | push sur `main` touchant `supabase/` | applique les migrations, relève le schéma |

`deploy-web.yml` exécute `dart format --set-exit-if-changed`, `flutter
analyze`, `flutter test` puis `flutter build web`. Ces quatre commandes doivent
passer avant tout push sur `main`.

**Et il faut lire leur vrai code de sortie.** `commande | tail -3` renvoie
celui de `tail`, jamais celui de la commande : un `dart format` en échec y
paraît vert. C'est arrivé — le formatage a été annoncé comme passé, et la CI
l'a démenti trente secondes plus tard. Capturer le code avant de filtrer.

### Les migrations s'appliquent toutes seules

`supabase/migrations.txt` liste les fichiers à appliquer, **dans l'ordre**.
C'est la source unique : `appliquer.sh` (base réelle) et `rejouer.sh` (base
jetable) la lisent tous les deux, pour qu'aucun ordre ne puisse diverger de
l'autre.

À chaque push sur `main`, `migrations-supabase.yml` applique ce qui doit
l'être, puis recommite `supabase/schema_actuel.sql`. Il n'y a plus rien à
coller dans l'éditeur SQL du projet.

Trois points à connaître :

- **Un fichier est rejoué dès que son empreinte change**, pas seulement quand
  il est nouveau. C'est ce qui permet de corriger un fichier sur place — la
  tranche 3 l'a été deux fois — plutôt que d'empiler des correctifs. La
  contrepartie est une contrainte réelle : **une migration doit rester
  idempotente**. Un `insert` nu ou un `alter table add column` sans
  `if not exists` casserait au second passage.
- **Le job ne tourne jamais sur une pull request.** Le dépôt est public : un
  job déclenché par une PR exécuterait du code proposé par n'importe qui, et
  lui donner `SUPABASE_DB_URL` reviendrait à publier la chaîne de connexion.
  Conséquence assumée : une migration n'est éprouvée contre la vraie base
  qu'après fusion, et le filet d'avant fusion reste `verification/`.
- La table de suivi vit dans le schéma `jelvo_migrations`, pas dans `public` :
  `public` est exposé par PostgREST, et l'historique des migrations n'a rien à
  faire dans l'API.

#### « Migrations en échec » ne veut pas dire « migrations non appliquées »

Le job fait **deux choses** que rien ne relie : il applique le SQL, puis il
recommite l'instantané du schéma. La seconde peut échouer seule, et c'est
arrivé dès la première fusion suivant la protection de `main` — la tranche 5c
s'est appliquée intégralement, et le job est tout de même ressorti en rouge :

```
OK    tranche5c_notifications_push.sql
…
remote: error: GH013: Repository rule violations found for refs/heads/main.
remote: - Required status check "Compiler la version web" is expected.
```

**Une règle de protection s'applique à toute poussée, pas seulement aux
fusions.** Le workflow pousse un commit direct, qui n'a aucune vérification à
présenter : GitHub le refuse. La règle qui rend l'auto-merge armable est donc
exactement celle qui empêche le relevé du schéma d'atteindre `main`.

##### L'application GitHub Actions ne peut pas être contournée ici

La réponse évidente — inscrire **`github-actions` dans la Bypass list** — est
**impossible sur ce dépôt**, et il a fallu trois passages pour l'établir.
L'API refuse en `422` :

```
Actor GitHub Actions integration must be part of the ruleset source
or owner organization
```

Une application n'entre dans une Bypass list que si elle appartient au
propriétaire du ruleset. `JELVO` est un dépôt de **compte personnel** : il n'a
pas d'organisation propriétaire, donc aucune application n'est jamais « la
sienne ». La documentation générale de GitHub cite pourtant « GitHub Apps »
parmi les acteurs éligibles — elle décrit le cas d'une organisation, et ne le
dit pas.

Le seul acteur inscriptible est le **rôle** : `RepositoryRole` `#5`,
l'administrateur (`#2` maintien, `#4` écriture). `OrganizationAdmin` échoue
comme l'application ; `DeployKey` n'est pas accepté par l'API malgré ce que
suggère le type énuméré.

**Un rôle désigne une personne, pas un automate**, et c'est toute la
conséquence : le workflow doit pousser avec un **jeton personnel** appartenant
à un administrateur, secret `JETON_POUSSEE_SCHEMA`, permission *Contents* en
écriture et rien d'autre. `checkout` le reçoit par `token:`, ce qui remplace
`GITHUB_TOKEN` dans les identifiants persistés.

Les deux moitiés sont nécessaires et **aucune ne suffit seule** : sans le
rôle, la poussée est refusée ; sans le jeton, elle est faite par
`github-actions[bot]`, qui n'a pas ce rôle.

Deux effets de bord à connaître :

- **une poussée faite avec un jeton personnel déclenche les workflows**, là où
  celle de `GITHUB_TOKEN` n'en déclenche aucun. C'est le `[skip ci]` du
  message de commit qui empêche la boucle — il n'était qu'un confort, il
  devient nécessaire ;
- le contournement vaut pour **toutes** les poussées de cet administrateur,
  pull requests comprises. Si l'auto-merge cessait d'être armable, ce serait
  la cause à examiner en premier, et le workflow jetable sait retirer l'acteur
  aussi bien que l'ajouter.

Ce qui se code, en revanche, c'est de ne pas mentir sur le coupable. L'étape
distingue désormais ce refus, l'annonce en toutes lettres — « les migrations
SONT appliquées » —, et l'instantané part en **pièce jointe du job** pour ne
pas être perdu. Le premier diagnostic avait conclu à une migration ratée et
au SQL absent de la base ; il était faux, et il l'était parce que l'échec
brut ne nommait que la dernière commande.

**Règle** : lire le journal jusqu'à la ligne `OK <fichier>` avant de conclure
qu'une migration n'est pas passée. Le rouge du job ne désigne pas l'étape qui
compte.

#### Trois échecs différents, un seul rouge

Le job peut échouer à trois endroits, et **le rouge ne dit pas lequel** :

| Où | Ce qui est vrai | Ce qu'il faut faire |
| --- | --- | --- |
| connexion refusée | **rien n'est appliqué** | régénérer `SUPABASE_DB_URL` |
| une migration | ce qui précède l'est, pas la suite | corriger le SQL |
| publication de l'instantané | **tout est appliqué** | rôle `#5` en Bypass list **et** `JETON_POUSSEE_SCHEMA` |

**Règle** : chercher les lignes `OK <fichier>` avant de conclure. Aucune ligne
`OK` du tout signifie que la base n'a rien reçu.

Le cas s'est produit le 21 août : `password authentication failed for user
"postgres"`, treize secondes de job, aucune migration appliquée — et comme
les trois échecs précédents n'avaient porté que sur l'instantané, le premier
réflexe a été de conclure pareil. La colonne `profiles.avatar_preset` est
restée absente en production pendant que l'application l'écrivait déjà.

D'où une étape **« Éprouver la connexion »** avant toute application, qui
transforme le `FATAL` de libpq en une phrase actionnable, et un résumé qui
distingue « aucune migration appliquée » de « seul l'instantané est refusé ».

#### La chaîne de connexion est épurée avant usage

`verification/connexion.sh` retire les blancs de début et de fin du secret,
contrôle qu'il commence par `postgresql://` — ou `postgres://`, synonyme
accepté par libpq —, et pose un `::add-mask::` sur la valeur nettoyée.

Ce n'est pas de la précaution abstraite : un secret collé depuis un téléphone
emporte volontiers un saut de ligne final, invisible dans le champ de saisie
et masqué dans les journaux. libpq le prend au pied de la lettre et répond

```
FATAL: database "postgres\n" does not exist
```

message qui désigne la base plutôt que le presse-papiers, et envoie chercher
le défaut du mauvais côté.

Deux points de méthode :

- **Le masque doit être reposé.** Celui de GitHub porte sur la valeur
  *enregistrée* du secret ; dès qu'on en retire le saut de ligne, la chaîne
  manipulée n'est plus celle-là et n'est plus masquée d'office.
- **Le nettoyage est signalé, jamais silencieux.** Le secret reste fautif au
  passage suivant, et son propriétaire doit pouvoir le corriger à la source.

Le fichier est **sourcé** par `appliquer.sh` et par le workflow, qui republie
la valeur propre dans `GITHUB_ENV` pour l'extraction du schéma. Une seconde
implémentation aurait fini par diverger — et c'est précisément l'étape
d'extraction qui aurait continué d'échouer.

`essai_connexion.sh` éprouve les douze cas sans base de données, y compris
qu'une valeur refusée ne fuite pas dans les messages.

### `supabase/schema_actuel.sql` fait foi

Instantané du schéma **réel**, relevé après chaque application : types
énumérés, tables et colonnes — les `not null` sans valeur par défaut y sont
signalées —, contraintes, politiques RLS, fonctions, déclencheurs, privilèges.

**Le lire avant d'écrire une insertion.** C'est ce fichier qui remplace la
devinette, et la devinette a coûté `invitations.type` puis plusieurs jours de
diagnostic. Il est généré par `verification/extraire_schema.sql`, par
introspection du catalogue plutôt que par `pg_dump` — lequel refuse de tourner
contre un serveur plus récent que lui, et la version de PostgreSQL de Supabase
n'est pas celle du runner GitHub.

### Le SQL n'est vérifié par aucune de ces commandes

**Une CI verte ne dit rien des fichiers de `supabase/`.** La chaîne Flutter ne
lit pas ce dossier : les quatre commandes ci-dessus passeraient sur un fichier
SQL vide comme sur un fichier qui ne se parse pas.

Le SQL est désormais appliqué automatiquement — mais **après** fusion, et par
un autre workflow. Une migration fautive passe donc toujours la revue : elle
n'échoue qu'une fois sur `main`. Le seul filet d'avant fusion reste celui-ci.

Le coût s'est déjà payé deux fois : `invitations.type` oubliée (`23502`), puis
`articles_de_tache` livrée avec un `position` non cité (`42601`), une erreur
purement syntaxique qu'un simple parseur aurait vue.

D'où `supabase/verification/rejouer.sh` : il monte un cluster PostgreSQL
jetable, y pose le décor minimal de `supabase/verification/schema_factice.sql`
— tables, types et `auth.uid()` factices —, rejoue tous les fichiers de
`supabase/` dans l'ordre, puis lance `verification/fumee.sql`, qui **appelle**
les vingt fonctions des tranches 3 et 3b. **À lancer avant de livrer une
migration.**

Les deux étapes ne font pas double emploi : `create function` ne vérifie que la
syntaxe du corps, et les instructions d'une fonction plpgsql ne sont préparées
qu'au premier appel. Le rejeu seul passait au vert sur des `case` qui faisaient
échouer toute création de tâche (voir « Toute valeur d'énumération écrite porte
une conversion explicite »).

Ce qu'il ne prouve **toujours pas** : le schéma réel. Son décor est recopié de
cette même documentation — la connaissance faillible qui avait laissé passer
`invitations.type`. Les colonnes obligatoires, les contraintes et les valeurs
d'énumération restent à vérifier contre le projet, et c'est l'objet de la
PARTIE A de `supabase/diagnostic_taches_evenements.sql` (voir « Le schéma
initial fait autorité »).

### Fusion automatique des pull requests — **opérante depuis le 18 août 2026**

L'auto-merge fonctionne, et cela a été **constaté de bout en bout** sur la
PR #27 : armée à 18:20:44 alors que la vérification était encore
`in_progress` et la PR `blocked`, fusionnée seule à 18:22:59, sans aucun appel
de fusion.

Ce qui a manqué pendant plusieurs tranches — au prix de deux PR restées
ouvertes dix-sept heures avec une CI verte — n'était pas « Allow auto-merge »
dans les réglages, qui était coché depuis le début. C'était la **règle de
protection sur `main`** déclarant au moins une vérification obligatoire, en
l'occurrence « Compiler la version web ».

La raison est contre-intuitive : GitHub refuse d'armer l'auto-merge sur une
pull request **déjà fusionnable**. S'il n'y a rien à attendre, il n'y a rien à
automatiser, et l'API répond

```
Pull request Protected branch rules not configured for this branch
```

C'est donc la vérification obligatoire qui, en rendant la PR temporairement
non fusionnable, la rend éligible. Sans elle, l'auto-merge n'est pas
« désactivé » : il est **inarmable**, ce qui ne se voit qu'en lisant le refus
de l'API.

> **La règle a un effet de bord ailleurs**, décrit sous « Les migrations
> s'appliquent toutes seules » : elle refuse aussi les poussées directes du
> workflow des migrations.

Deux façons de garder la main :

| Signal | Effet |
| --- | --- |
| étiquette **`arbitrage-requis`** sur la PR | l'auto-merge n'est pas activé, la PR attend |
| PR ouverte en **brouillon** | GitHub n'auto-fusionne jamais un brouillon |

L'étiquette se pose dès l'ouverture, jamais après coup : une PR déjà
auto-fusionnée ne se rattrape pas. Sont concernées les livraisons dont le
choix, et non l'exécution, mérite un avis — un arbitrage de produit, une
migration destructrice, un changement de dépendance.

L'auto-merge natif reste préféré à un workflow maison pour une raison
précise : une fusion faite par `GITHUB_TOKEN` **ne déclenche aucun workflow en
aval**. Le déploiement des pages et l'application des migrations ne
partiraient pas.

Version de Flutter attendue : **3.44.8** (Dart 3.12). Elle est épinglée dans
`env.FLUTTER_VERSION` du workflow ; toute montée de version doit y être
répercutée.

---

## Architecture

Découpage **feature-first** : on regroupe par domaine métier, pas par type de
fichier. Une feature est autonome et ne connaît que `core` et `data`.

```
lib/
├── main.dart                 # point d'entrée, ProviderScope, MaterialApp.router
├── core/                     # design system + utilitaires, aucune logique métier
│   ├── core.dart             # barrel : le seul import dont un écran a besoin
│   ├── theme/                # couleurs, typo, espacements, rayons, ombres, ThemeData
│   ├── utils/                # AppDates (formatage fr_FR)
│   └── widgets/              # composants réutilisables (voir plus bas)
├── data/                     # infrastructure partagée, sans connaissance métier
│   ├── clock.dart            # Clock / SystemClock / FixedClock
│   ├── in_memory_collection.dart  # collection observable indexée par id
│   ├── app_config.dart       # configuration de compilation (--dart-define)
│   ├── supabase_providers.dart    # supabaseClientProvider
│   └── data_providers.dart   # clockProvider, nowProvider
├── features/<feature>/
│   ├── models/               # classes immuables du domaine (== sur l'id)
│   ├── repository/           # interface abstraite + implémentation en mémoire
│   ├── providers/            # providers Riverpod : état et dérivations
│   ├── screens/              # écrans complets
│   └── widgets/              # widgets propres à la feature
└── router/                   # GoRouter, coque et barre de navigation

supabase/                     # SQL à exécuter sur le projet Supabase
```

Features existantes : `auth`, `onboarding`, `profile`, `home`, `groups`,
`calendar`, `contacts`, `notifications`, `tasks`, `availability`, `chat`,
`create`.

`lib/l10n/` porte les fichiers ARB et la classe `AppTexts` générée.

### Sens des dépendances

```
features ──> data ──> (rien)
   │
   └───────> core ──> (rien)
```

- `core` et `data` **ne doivent jamais** importer une feature.
- Une feature peut importer une autre feature, mais uniquement ses `models` et
  ses `providers` — jamais son `repository` ni ses `widgets` privés.
- `home` est volontairement un agrégateur : il compose `calendar`, `tasks` et
  `groups` sans posséder de dépôt.

### Couches d'une feature

1. **Model** — immuable (`@immutable`), `copyWith`, `==`/`hashCode` sur l'`id`
   seul. Pas de sérialisation pour l'instant (données en mémoire).
2. **Repository** — une `abstract interface class` + une implémentation
   `InMemory…` adossée à `InMemoryCollection`. Les données de démonstration
   vivent dans un `static` de l'implémentation. Brancher une API se fera en
   ajoutant une implémentation, sans toucher aux providers ni aux écrans.
3. **Providers** — le dépôt est exposé par un `Provider` surchargeable en test ;
   la liste brute par un `StreamProvider` ; les vues filtrées/triées par des
   `Provider` dérivés. Les écritures passent par un objet d'actions
   (ex. `taskActionsProvider`), jamais par le dépôt directement depuis un widget.
4. **Screen / Widgets** — `ConsumerWidget` par défaut, `ConsumerStatefulWidget`
   seulement si un `TextEditingController` ou un `FocusNode` est nécessaire.

---

## Design system

Toutes les valeurs visuelles viennent de `core/theme`. **Aucun `Color(0x…)`,
aucune taille de police et aucun rayon littéral ne doit apparaître ailleurs.**

### Couleurs — `AppColors`

| Jeton           | Valeur    | Usage                                  |
| --------------- | --------- | -------------------------------------- |
| `primary`       | `#5B2EFF` | actions principales, sélection         |
| `primaryDark`   | `#3D1DB8` | états pressés, dégradés                |
| `midnight`      | `#12122B` | texte principal, titres                |
| `textSecondary` | `#6B6B85` | texte secondaire, légendes             |
| `background`    | `#F7F7FB` | fond d'écran                           |
| `surface`       | `#FFFFFF` | cartes, feuilles, barres               |
| `success`       | `#22A06B` | confirmé, terminé                      |
| `warning`       | `#F5A623` | en attente, échéance proche            |
| `danger`        | `#E5484D` | conflit, action destructive            |
| `border`        | `#ECECF4` | traits, contours de champs             |

Les variantes `…Soft` (`primarySoft`, `successSoft`, …) servent aux fonds
teintés des pastilles et vignettes.

### Typographie — `AppTypography` (police **Inter** via `google_fonts`)

| Style     | Taille | Graisse       | Équivalent `TextTheme` |
| --------- | ------ | ------------- | ---------------------- |
| `h1`      | 28     | bold (700)    | `headlineLarge`        |
| `h2`      | 22     | bold (700)    | `headlineMedium`       |
| `h3`      | 17     | semibold(600) | `titleMedium`          |
| `body`    | 15     | regular (400) | `bodyMedium`           |
| `caption` | 13     | regular (400) | `bodySmall`            |
| `button`  | 16     | semibold(600) | `labelLarge`           |

`bodyMuted` est la variante de `body` en `textSecondary`.

### Rayons — `AppRadii`

Cartes **16** · boutons **14** · champs **12** · bottom sheets **24** (coins
hauts uniquement) · pastilles `pill`.

### Espacements — `AppSpacing`

Échelle **4 / 8 / 12 / 16 / 24 / 32** (`xs`, `sm`, `md`, `lg`, `xl`, `xxl`).
Marge d'écran : **16** (`screenMargin`, `screenHorizontal`, `screenAll`).
Utiliser `AppSpacing.gapMd` plutôt que `SizedBox(height: 12)`.

### Icônes — fournies, jamais dessinées ici

**Le logo de Jelvo est un fichier fourni. Il ne se reconstruit pas.** Un
monogramme redessiné d'après une description a été livré une fois, puis
retiré : ce n'était pas le logo, c'en était une approximation, et une
approximation de logo est un faux. Les emplacements sont câblés, les images
viennent du dehors.

Le logo vit dans `tool/logo/jelvo-icone-source.png`, et
`tool/preparer_icones.py` y **découpe** les sept fichiers — recentrage,
réductions, extraction de la silhouette du badge. Aucune forme n'est
reconstruite. Changer de logo, c'est remplacer la source et relancer.

Le fichier fourni n'était pas centré — 333 px de marge à gauche contre 366 à
droite. Deux choix ont guidé la correction, tous deux consignés dans
`web/icons/README.md` :

- **la translation est entière**, jamais sous-pixellaire : un décalage de
  16,5 px aurait demandé un rééchantillonnage, donc une altération du tracé.
  Il reste un pixel d'écart, le jeu à répartir étant impair ;
- **le favicon est recadré à 62 %** avant réduction, et lui seul : à 32 px, le
  cadrage d'origine ne laissait que quatorze pixels au monogramme, le reste
  étant du fond. C'est un recadrage, pas une déformation ;
- **le dégradé est prolongé par une droite des moindres carrés** ajustée sur
  soixante-quatre colonnes. Prolonger depuis deux pixels voisins multiplie
  leur écart par la distance : le bruit du dégradé devenait une bande claire
  de dix-sept pixels le long du bord.

`web/icons/README.md` porte la liste exacte — sept fichiers, leurs tailles et
leurs contraintes. Trois de ces contraintes ne se devinent pas :

- **une icône masquable est rognée**, souvent en cercle : tout ce qui compte
  doit tenir dans les 80 % centraux, fond compris. **Le script le contrôle à
  chaque exécution et s'arrête si ce n'est plus vrai** ;
- **les cadrages diffèrent selon l'usage, et ce n'est pas un oubli.** Les
  icônes ordinaires sont recadrées à 80 % — le monogramme y flottait au
  milieu d'une grande zone violette —, les masquables gardent le cadrage du
  maître. Après rognage par le système, le monogramme occupe **la même part
  visible des deux côtés** : 555 px pour 1003 px utiles. Les agrandir aussi
  les ferait déborder ;
- **iOS ne respecte pas la transparence** — il compose sur du noir — et pose
  lui-même les coins arrondis ; `Icon-180.png` doit donc être opaque et
  carrée ;
- **le badge Android ne garde que l'alpha** : une icône en couleur y devient
  un carré plein, il faut une silhouette monochrome sur fond transparent.

**Sur iPhone, remplacer les fichiers ne suffit pas à voir l'icône changer** :
iOS fige celle de l'application installée. Il faut retirer l'icône de l'écran
d'accueil et réinstaller — ce qui **détruit l'abonnement push** et oblige à
réactiver les notifications.

### Avatars prédéfinis

Quatre-vingt-treize illustrations rondes vivent dans `assets/avatars/`,
**embarquées** et non servies depuis Supabase : elles sont fixes et
identiques pour tout le monde. Le profil ne retient que **l'identifiant du
fichier**.

`lib/features/profile/models/avatar_catalog.dart` est **généré** par
`tool/lister_avatars.py`, et `test/avatar_catalog_test.dart` confronte la
liste au contenu réel du dossier — un fichier ajouté sans régénérer fait
échouer les tests plutôt que d'ouvrir un trou dans la galerie.

**La numérotation a des trous** : `p1_10`, `p2_08` et `p2_12` n'existent pas.
93 fichiers, pas 96 — rien ne doit reconstruire un identifiant depuis un
intervalle.

#### `preset:` — pourquoi aucune signature SQL n'a changé

Onze fonctions de lecture renvoyaient déjà un champ `avatar_url`. Changer les
colonnes de sortie d'un `returns table` impose un `drop function` — `create
or replace` le refuse —, soit onze suppressions en production pour un gain
nul côté appelant.

À la place, **l'expression change, pas la déclaration** :

```sql
coalesce('preset:' || p.avatar_preset, p.avatar_url)
```

**La colonne `profiles.avatar_url` ne contient toujours que des URL** ; c'est
le *champ de sortie* du même nom qui devient « l'avatar à afficher ». La
distinction est subtile et mérite d'être connue avant de lire l'une pour
l'autre.

Côté Dart, une seule règle et **un seul endroit** qui la connaît :
`AvatarData.assetPourAvatar`. C'est ce qui a permis d'ajouter les avatars
prédéfinis sans toucher aux dix écrans qui construisent un `AvatarData`.
`AvatarImage` est le seul widget qui rend un avatar — prédéfini, photo, puis
initiales, dans cet ordre.

Pour son **propre** profil, lu directement dans la table plutôt que par une
fonction, c'est `Profile.avatarAAfficher` qui compose la même valeur.

#### La colonne s'ajoute avant tout le reste

`colonne_avatar_predefini.sql` est **en tête de `migrations.txt`**, avant
`email_pour_pseudo.sql`. Plusieurs fonctions de lecture sont en `language
sql`, dont PostgreSQL **valide le corps à la création** : les créer avant la
colonne les ferait échouer. Un fichier nommé « tranche » aurait suggéré une
place chronologique qu'il ne peut pas occuper.

#### Le dernier choisi l'emporte

Un profil a une photo **ou** un avatar prédéfini. La règle est tenue par
l'écriture, qui pose l'un et vide l'autre dans la **même** instruction —
`choisirAvatarPredefini` et `updateAvatar` écrivent les deux colonnes. Sans
cela, la lecture préférerait l'avatar et une photo fraîchement téléversée
resterait invisible.

#### Le poids, et pourquoi les fichiers ne sont pas retouchés

Les 93 PNG pèsent **9,5 Mio** (256 × 256, ~100 Kio pièce, 27 000 couleurs).
Mesuré : la recompression sans perte ne gagne rien (9,3 Mio), une palette de
64 couleurs tomberait à 1,4 Mio mais **abîme le bord détouré**, et une
réduction à 5 bits par canal donnerait 4,9 Mio sans perte visible.

Rien n'a été retouché : ce sont les fichiers livrés, et la galerie utilise un
`GridView.builder`, qui ne charge que les vignettes visibles. Les 9,5 Mio ne
partent donc jamais d'un coup. Si l'application native devait maigrir, la
réduction à 5 bits est la piste, et elle tient en une passe de script.

### Ombres — `AppShadows`

Toujours **très douces, opacité ≤ 0,06**. `card` au repos, `raised` pour un
élément mis en avant, `overlay` pour la barre et les feuilles, `accent` pour le
halo violet du bouton central. Ne pas utiliser l'`elevation` Material.

### Composants — `core/widgets`

| Composant                     | Rôle                                              |
| ----------------------------- | ------------------------------------------------- |
| `PrimaryButton`               | action principale, violet plein, état `isLoading` |
| `SecondaryButton`             | action secondaire, contour, variante destructive  |
| `AppTextField`                | champ avec libellé, aide et erreur sous le champ  |
| `GroupCard`                   | carte de groupe : vignette, membres, activité     |
| `EventCard`                   | carte d'événement : accent, horaire, statut       |
| `TaskRow`                     | ligne de tâche avec case à cocher personnalisée   |
| `AvatarStack`                 | avatars superposés + compteur « +N »              |
| `SectionHeader`               | titre de section H3 + action « Tout voir »        |
| `EmptyState`                  | état vide : icône, titre, message, action         |
| `StatusDot`                   | pastille de statut (`StatusTone`), option `filled`|
| `NavBadge`                    | compteur rouge posé sur une icône, masqué à zéro  |
| `AppCard`                     | conteneur de base des cartes (surface + ombre)    |
| `AppScreen` / `AppScreenAction` | gabarit d'écran d'onglet (en-tête H1 + slivers) |
| `CoverBanner`                 | photo de couverture, repli d'accent, nom en surimpression |
| `TaskRow.badge`               | pastille après le titre d'une tâche — sa priorité |
| `AvatarStack.extraCount`      | personnes à compter dans le « +N » au-delà des avatars reçus |
| `AppCard.clipContent`         | rogne au rayon de la carte, pour un enfant qui va d'un bord à l'autre |
| `InvitationHeader`            | auteur, ce qu'il demande, depuis quand            |
| `InvitationDetailRow`         | ligne icône / libellé / valeur d'une carte d'invitation |
| `InvitationActions`           | refus en contour à gauche, accord en plein à droite |
| `OptionRow` / `OptionIcon`    | ligne de réglage : icône, libellé, aide, valeur violette |
| `ExpandableOptions`           | carte « Plus d'options » qui se replie sur son contenu |
| `PersonAvatarRow` / `PersonPickerSheet` | rangée d'avatars sélectionnables, et la liste complète avec recherche |

**Les composants de `core/widgets` ne connaissent pas le domaine** : ils
prennent des `String`, `IconData`, `Color` et `AvatarData`, jamais un `Group` ou
un `CalendarEvent`. La conversion domaine → composant se fait dans les widgets
de feature (voir `avatarsForContactIdsProvider`).

---

## Navigation

`GoRouter` + Riverpod (`routerProvider` dans `router/app_router.dart`).

- `StatefulShellRoute.indexedStack` avec **quatre branches** : `/` (Accueil),
  `/groupes`, `/calendrier`, `/contacts`. Chaque onglet garde son historique et
  sa position de défilement.
- Le bouton central **[+]** n'est pas un onglet mais une action, empilée sur le
  navigateur racine (`parentNavigatorKey: _rootNavigatorKey`), ce qui recouvre
  la barre de navigation. Il est **contextuel** — `AppShell._createAction`.
  L'écran ouvert dit déjà ce que l'on veut créer ; le demander serait une
  question de trop. Son infobulle nomme l'action, l'icône seule ne disant pas
  ce qui va s'ouvrir.
- La barre est un widget maison (`AppBottomNav`) et non un `NavigationBar` :
  le bouton central ne rentre pas dans le modèle « un index par destination ».
- Naviguer avec `context.goNamed(AppRoutes.calendar)` / `pushNamed`, jamais avec
  une chaîne littérale. Les chemins vivent dans `router/app_routes.dart`.
- Le détail d'un groupe (`/groupes/:id`) vit **dans la branche Groupes** : la
  barre de navigation reste visible. Création, modification, invitations, QR et
  scanner sont empilés sur le navigateur racine et la recouvrent. `/groupes/nouveau`
  est déclaré **avant** `/groupes/:id`, sans quoi « nouveau » passerait pour un
  identifiant.
- Sur le web, une URL inconnue affiche `_RouteErrorScreen`. Le workflow copie
  `index.html` en `404.html` pour que l'accès direct à `/calendrier` fonctionne
  sur GitHub Pages.

### Le « + » se règle sur la route, pas sur l'onglet

`AppShell` reçoit `location: state.uri.path` — le chemin **réellement
affiché** — et non le seul `navigationShell.currentIndex`. La distinction n'est
pas théorique : une branche peut empiler plusieurs écrans sans changer
d'onglet. Depuis `/groupes/<id>` on est toujours dans l'onglet Groupes, et un
« + » indexé sur l'onglet y proposait donc de créer *un groupe de plus* — sans
issue vers les tâches et les événements de ce groupe.

| Écran affiché | Action du « + » |
| --- | --- |
| `/groupes/<id>` | feuille « Ajouter au groupe » → événement ou tâche **dans ce groupe** |
| Accueil, liste des groupes | création de groupe |
| Calendrier | `/creer` |
| Contacts | ajout de contact |

`AppRoutes.groupIdIn(location)` extrait l'identifiant et écarte
`/groupes/nouveau`, qui est un écran de création et non un groupe. La règle
vaut pour la suite : **un nouvel écran empilé dans une branche doit se demander
si le « + » a encore le bon sens à cet endroit.**

Le contexte se transmet ensuite par l'URL — `/creer?type=task&groupe=<id>`,
clés dans `AppRoutes.createKindParam` et `createGroupParam`. Un `extra` aurait
suffi sur mobile mais se perd au rafraîchissement du web ; l'URL, elle, reste
rechargeable. `CreateScreen` pré-remplit sans verrouiller : les deux champs
restent modifiables.

Le « + » n'est jamais le **seul** chemin. Les sections « À venir » et « Tâches
prioritaires » de l'écran de groupe portent chacune un « Ajouter » sous leur
contenu, et leurs états vides une action pleine. Une fonctionnalité qui n'est
atteignable que par un bouton d'icône dans une barre est, en pratique,
intestable.

Ce « Ajouter » a changé de place et non de rôle : l'en-tête de section porte
désormais « Voir tout », qui ouvre la liste complète. Les deux ne se
remplacent pas — l'un crée, l'autre déplie —, et supprimer le premier aurait
laissé la création au seul « + ».

### Liens externes et stratégie d'URL

L'application **n'appelle pas `usePathUrlStrategy()`** : Flutter web place donc
les routes **après le fragment**. Une URL partagée hors de l'application doit
porter le `#` — `AppConfig.inviteUrl` s'en charge :

```
https://…/JELVO/#/rejoindre/<jeton>
```

Sans lui, GitHub Pages ne trouve pas le chemin, sert `404.html` (une copie
d'`index.html`), et l'application démarre avec un fragment vide : GoRouter voit
`/`, affiche l'accueil, **sans message ni erreur**. Le jeton disparaît en
silence — panne d'autant plus pénible qu'elle ne laisse aucune trace.

Les chemins internes (`AppRoutes.*Path`, `context.goNamed`) restent **sans
`#`** : GoRouter raisonne en chemins, c'est la couche web qui ajoute le
fragment. Le `#` ne concerne que les liens sortants.

Le jour où le site aura son propre domaine, passer en stratégie par chemin
donnera des liens plus propres et fera disparaître ce `#`.

### Garde d'authentification

`routerProvider` combine `refreshListenable: ref.watch(authRefreshProvider)` et
un `redirect` qui lit `authStatusProvider` de façon **synchrone** :

- session absente → tout chemin hors `AppRoutes.publicPaths` renvoie vers
  `/connexion`, ou vers `/bienvenue` à la toute première ouverture ;
- session présente → un chemin public renvoie vers `/`.

`AuthRefreshNotifier` est un `ChangeNotifier` alimenté par un `ref.listen` :
GoRouter ne sait pas observer un provider, il faut ce pont. Le statut est un
`Notifier` et non un `StreamProvider` parce qu'une redirection ne peut pas
attendre un `AsyncValue`.

---

## Écran de bienvenue

`/bienvenue` (feature `onboarding`) présente l'application **avant toute
authentification**, à quelqu'un qui n'a pas encore de compte : il précède donc
l'écran de connexion, et non l'inscription. « Commencer » mène à `/connexion`,
d'où l'on crée un compte ou l'on se connecte.

**Une seule page, pas de carrousel** : ni points de pagination, ni « Passer ».
Trois arguments tiennent sur un écran, et un « Passer » posé à côté d'un
« Commencer » demande de choisir entre deux boutons qui font la même chose —
sortir de là.

### Le drapeau ne peut pas vivre en base

L'écran s'affiche à quelqu'un **sans compte** : il n'existe aucune ligne
`profiles` où écrire « déjà vu », et rien à lire au démarrage. C'est donc une
mémoire d'appareil, et elle l'est doublement à raison — une application
installée sur l'écran d'accueil a son propre stockage, et y revoir la
présentation une fois est le comportement juste.

`OnboardingStorage` reprend la brique de `SessionPersistence` : un
`LocalStorage` de gotrue détourné en booléen, sous la clé
`jelvo-bienvenue-vue`. L'usage est détourné, mais il évite une dépendance de
plus pour un seul `bool` — c'est déjà l'arbitrage rendu pour « Se souvenir de
moi ». Il est chargé dans `main()` **avant `runApp`**, la redirection le lisant
de façon synchrone.

### Trois façons de ne plus le revoir

| Situation | Ce qui le retient |
| --- | --- |
| « Commencer » touché | `welcomeSeenProvider.marquerVu()` |
| une session s'ouvre | `ref.listen` sur `authStatusProvider` |
| une session est **déjà** ouverte au démarrage | contrôle explicite dans `build()` |

La troisième ligne n'est pas de la redondance : `ref.listen` ne se déclenche
qu'au **changement**, et une session restaurée au lancement ne le réveillerait
pas — c'est pourtant le cas le plus courant.

**Une session ouverte vaut présentation faite.** Sans cette règle, quelqu'un
arrivé par un lien d'invitation — qui n'a donc jamais vu l'écran — se le verrait
proposer le jour où il se déconnecte, longtemps après avoir appris à quoi sert
l'application.

Conséquence sur la redirection : `welcomeSeenProvider` est lu **dans tous les
cas**, connecté compris. C'est cette lecture qui construit le provider, et un
provider jamais construit ne retiendrait rien.

### Un chemin public demandé explicitement passe avant

```dart
if (AppRoutes.isPublic(location)) return null;
return bienvenueVue ? AppRoutes.loginPath : AppRoutes.welcomePath;
```

L'ordre compte. Rediriger `/rejoindre/<jeton>` vers la présentation **perdrait
le jeton en silence** — la panne la plus pénible, parce qu'elle ne laisse
aucune trace, exactement celle décrite sous « Liens externes et stratégie
d'URL ». Un test le vérifie.

L'écran de bienvenue remplace donc le point d'entrée *par défaut*, jamais une
destination demandée.

### L'illustration vient du dehors

**Elle ne se dessine pas ici** — même règle que le logo.
`assets/illustrations/bienvenue.png`, PNG-24 avec alpha, 1200 × 800 (3:2), fond
transparent. `assets/illustrations/README.md` porte le détail, dont le poids et
ce qu'on a renoncé à lui faire.

Le dossier est déclaré dans `pubspec.yaml`, et l'a été **avant que le fichier
existe** : un chemin d'asset absent fait échouer la compilation, là où un
fichier absent ne fait que déclencher l'`errorBuilder`.

Le repli ne dessine **pas** une illustration de remplacement : un aplat teinté
et un pictogramme discret, visiblement un emplacement en attente. La bande
garde sa hauteur de 240 dp dans les deux cas, pour que la carte des arguments
commence au même endroit ; `BoxFit.contain` s'accommode ensuite de tout rapport
de forme sans jamais rogner.

**Un `errorBuilder` ne casse rien, donc ne se voit pas en CI** : un fichier
supprimé ou renommé passerait au vert et ne se constaterait qu'à l'écran. Un
test lit donc l'en-tête PNG dans le bundle et contrôle les dimensions. Il lit
l'en-tête plutôt que de décoder : `decodeImageFromList` demande un vrai `await`
que le temps simulé d'un test de widget ne lui donne pas, et le test resterait
suspendu — ce qui est arrivé.

#### La coupe du bas commande la mise en page

Le sujet est **coupé net au bord inférieur du fichier**, à mi-cuisse : la boîte
englobante du contenu touche `y = hauteur`, sans marge ni dégradé. La maquette
masque cette coupe en faisant chevaucher la carte des arguments.

D'où deux choix de `WelcomeScreen` qui n'ont rien de décoratif :

- **aucun espace entre l'illustration et la carte**, dont le bord supérieur
  recouvre la coupe. Les 32 dp qui les séparaient donnaient la coupe à voir,
  en suspension ;
- **l'illustration sort de la marge d'écran** et va d'un bord à l'autre. La
  marge transparente du fichier — 10 % à gauche, 8 % à droite — lui donne déjà
  l'air nécessaire, et le défilement porte donc sa marge par enfant plutôt que
  d'un bloc.

C'est un détail à revérifier en changeant de fichier : une illustration qui,
elle, aurait une marge basse laisserait un vide sous les pieds.

### Pas d'emoji dans le titre

La maquette écrit « Bienvenue sur Jelvo 👋 ». Le projet n'embarque aucune police
emoji : le glyphe manquerait et s'afficherait en carré « tofu ». C'est le même
arbitrage — et le même emoji — que le titre de l'accueil. Un test vérifie que
le titre ne porte aucun caractère au-delà de `U+1F000`.

Les trois teintes des pictogrammes viennent du design system — `primary`,
`success`, `warning` : le violet, le vert et l'orange de la maquette y tombent
exactement, aucune couleur n'a été ajoutée.

---

## Authentification et Supabase

Seuls **l'authentification et le profil** sont branchés sur Supabase. Les
groupes, événements, tâches et contacts restent en mémoire.

### Configuration

`data/app_config.dart` lit l'URL et la clé publiable via `String.fromEnvironment`
avec des valeurs par défaut. Ces deux valeurs sont publiques par conception et
peuvent figurer dans un dépôt public, mais elles se surchargent à la compilation :

```bash
flutter build web --release \
  --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…
```

Le workflow les injecte depuis son bloc `env`. Toute nouvelle valeur de
configuration passe par `AppConfig`, jamais par une constante disséminée.

### « Se souvenir de moi » décide de ce qui est écrit, pas de ce qui expire

`SessionPersistence` (`data/session_persistence.dart`) est le `LocalStorage`
que gotrue interroge au démarrage et appelle à chaque rafraîchissement de
jeton. **Cochée — le défaut —, elle délègue au stockage habituel.** Décochée,
elle n'écrit rien : la session ne vit qu'en mémoire dans le client et disparaît
avec le processus. Ce n'est pas une expiration programmée, il n'y a simplement
rien à retrouver.

Le **drapeau**, lui, est persistant : il faut le connaître *avant* la
restauration de session, donc dès `initialize()`. Il passe par une seconde
instance du même stockage plutôt que par une dépendance de plus.

Trois points qui ne sont pas décoratifs :

- **Le réglage se pose avant `signIn`.** gotrue écrit la session dans la
  foulée ; régler après persisterait celle qu'on vient de refuser.
- **Décocher efface une session déjà enregistrée.** Sans cela, celle d'une
  connexion précédente survivrait — exactement l'impression que la case ne
  marche pas.
- **`removePersistedSession` n'est jamais conditionnelle** : une déconnexion
  efface quel que soit le réglage.
- La clé de session reprend **à l'identique** le format de
  `Supabase.initialize` (`sb-<hôte>-auth-token`) : en changer déconnecterait
  tout le monde à la mise à jour.

**L'application installée sur l'écran d'accueil a son propre stockage.** Se
connecter dans Safari ne connecte pas la PWA, et aucun code n'y peut rien.
L'écran de connexion le dit sous la case, sans quoi le premier réflexe est de
conclure que la case est cassée. La consigne est conditionnée par
`estSurLeWebProvider` et non par `kIsWeb` directement : les tests tournent sur
la machine virtuelle, où `kIsWeb` vaut faux, et un texte réservé au web n'y
serait jamais éprouvé.

`main()` attend `Supabase.initialize(url:, publishableKey:)` avant `runApp` :
la session persistée est donc déjà restaurée au premier `build` — d'où les deux
seuls états de `AuthStatus`, sans `unknown`.

### Feature `auth`

- `models/credentials_rules.dart` — validation pure, sans dépendance Flutter :
  pseudo `^[a-z0-9.]{3,20}$`, mot de passe de 8 caractères avec une majuscule et
  un chiffre.
- `models/auth_failure.dart` — **le seul endroit** qui traduit une erreur.
  `AuthFailure.from(Object)` couvre `AuthException`, `PostgrestException`
  (`23505` pseudo pris, `42501` RLS), `StorageException` et les pannes réseau.
  **Aucun message technique brut ne doit atteindre l'écran** : un `catch` qui
  affiche `error.toString()` est un bug. Seule exception, explicite et
  signalée : le **mode diagnostic** décrit ci-dessous.
  `AuthFailure.technical` est toujours renseigné ; seul son affichage en
  dépend.

  **Un message de repli doit rester vrai.** « Réessayez dans un instant »
  convient à une panne passagère et à rien d'autre : servi pour une colonne
  absente, il envoie chercher le défaut du mauvais côté. `PGRST204` et
  `42703` ont donc leur propre message, qui dit que la base attend une mise à
  jour.
- `repository/auth_repository.dart` — l'interface expose `bool isSignedIn` et
  `Stream<bool> watchSignedIn()` plutôt que les types gotrue, ce qui permet de
  tester toute la pile sans `Supabase.initialize`.
- La connexion par pseudo appelle la fonction SQL `email_pour_pseudo`, livrée
  dans `supabase/email_pour_pseudo.sql` et **à exécuter sur le projet**. Sans
  elle, PostgREST répond `PGRST202` et l'écran invite à se connecter par e-mail.
- La vérification par code à 6 chiffres suppose que le modèle d'e-mail Supabase
  émet `{{ .Token }}` et non `{{ .ConfirmationURL }}`.
- La ligne `profiles` ne peut être écrite qu'**une fois la session ouverte** :
  c'est elle qui satisfait RLS. D'où la finalisation par `completeSignUp`, en
  dernier.

### Mode diagnostic — `?diag=1`, sans redéployer

`DiagnosticMode` (`data/diagnostic_mode.dart`) accole l'erreur technique brute
— SQLSTATE, message, détail, indice — sous le message français, et la consigne
dans la console. Un bandeau rouge « DIAGNOSTIC » couvre l'écran tant qu'il est
actif : un mode silencieux resterait allumé sans qu'on le sache.

Il s'active **par l'URL**, donc sans nouvelle livraison :

```
https://…/JELVO/?diag=1#/            ← à préférer
https://…/JELVO/#/groupes/<id>?diag=1
```

Les deux formes marchent, mais la première seule survit à la navigation :
l'application n'appelant pas `usePathUrlStrategy()`, GoRouter réécrit le
fragment et emporterait un paramètre qui y serait collé. `?diag` nu vaut
« oui » ; `?diag=0` éteint. Pour sortir du mode, recharger sans le paramètre.

La lecture n'a lieu **qu'une fois**, dans `main()`, avant
`Supabase.initialize` — une panne d'initialisation doit déjà être lisible.
L'état est ensuite stable pour toute la session.

`--dart-define=JELVO_DIAGNOSTIC=true` reste la valeur **par défaut** au
démarrage (le workflow la fixe à `false`), mais ne plus le lire directement :
`AppConfig.diagnosticErrors` ne connaît pas l'URL, seul
`DiagnosticMode.isActive` fait autorité.

Ce paramètre existe parce que la voie précédente — un drapeau de compilation —
imposait un cycle livraison / déploiement complet pour voir une seule erreur
serveur, et a coûté plusieurs jours sur `invitations.type`. **Un diagnostic que
seul le développeur peut déclencher n'est pas un diagnostic.**

### Confirmation d'e-mail activée ou non

La confirmation d'adresse est un réglage du **projet Supabase**, pas du code.
`signUp` renvoie donc un `SignUpOutcome` décrivant ce que le serveur a fait :

| Réponse Supabase        | `SignUpOutcome`  | Parcours                              |
| ----------------------- | ---------------- | ------------------------------------- |
| session dans la réponse | `sessionOpened`  | profil créé aussitôt, puis accueil    |
| aucune session          | `codeSent`       | écran de code, puis profil, puis accueil |

En développement la confirmation est **désactivée** : l'inscription mène
directement à l'accueil. `VerifyEmailScreen` et sa route restent en place, mais
court-circuités ; réactiver la confirmation côté Supabase les remet dans le
parcours **sans toucher à l'application**. Ne pas remplacer ce test par un
drapeau de compilation : le serveur est seul à connaître son réglage.

Les deux chemins finissent par `signUpActionsProvider.completeProfile()`, qui
crée le profil, téléverse la photo, vide le brouillon et renvoie un message
d'avertissement au lieu de lever : un profil non enregistré ne doit pas barrer
l'entrée dans l'application. Les deux écrans capturent leur
`ScaffoldMessenger` **avant** les `await`, la garde du routeur pouvant les avoir
déjà quittés au moment d'afficher la `SnackBar`.
- La colonne du pseudo s'appelle `pseudo` (pas `username`) et `profiles` ne
  porte pas d'`email` : l'adresse vient de la session (`currentEmailProvider`).

---

## Groupes, contacts et invitations

Ces trois domaines lisent et écrivent Supabase. Le schéma étant **préexistant**,
le code s'y plie plutôt que l'inverse — d'où les noms de colonnes et les valeurs
d'énumération ci-dessous, qui ne sont pas négociables côté application.

> **Le schéma initial fait autorité.** Avant de livrer une fonction SQL ou une
> requête qui écrit dans une table, vérifier ses colonnes **réelles** :
> colonnes obligatoires sans valeur par défaut, contraintes `check`, clés
> étrangères, valeurs d'énumération. Ne pas les deviner, ni les déduire de ce
> que l'application croit savoir.
>
> Cette règle vient d'une panne : `inviter_dans_groupe` ne renseignait pas
> `invitations.type`, colonne `not null` du schéma initial, et l'invitation
> échouait en `23502`. La colonne avait échappé à un sondage de noms candidats
> — une méthode qui ne voit que ce qu'elle a pensé à chercher. La requête de
> vérification vit en fin de `supabase/correctif_invitations_type.sql` :
> lancez-la après toute nouvelle fonction d'écriture.
>
> **Inverser le sens de la comparaison supprime l'angle mort.** La requête A0
> de `supabase/diagnostic_taches_evenements.sql` ne part pas d'une liste de
> noms à chercher : elle part du catalogue de PostgreSQL et lui confronte, une
> ligne par site d'insertion, les colonnes que le code renseigne. Toute colonne
> obligatoire sans valeur par défaut qu'une insertion oublie ressort, y compris
> celle à laquelle personne n'a pensé. C'est le modèle à reprendre pour toute
> nouvelle table.

### Schéma utilisé

| Table | Colonnes |
| --- | --- |
| `groups` | `id`, `name`, `description`, `photo_url`, `is_private`, `created_by`, `created_at`, `deleted_at` |
| `group_members` | `group_id`, `user_id`, `role`, `joined_at`, `expires_at` — **pas de colonne `id`** |
| `contacts` | `requester_id`, `addressee_id`, `status`, `favorite_requester`, `favorite_addressee`, `created_at` — **pas de colonne `id`** |
| `invitations` | `id`, **`type`**, `group_id`, `event_id`, `task_id`, `inviter_id`, `invitee_id`, `status`, `created_at`, `expires_at` |
| `group_invite_links` | créée par la migration : `id`, `group_id`, `created_by`, `token`, `expires_at`, `max_uses`, `uses_count`, `revoked_at` |

Quatre types énumérés, dont les valeurs exactes comptent :

- `member_role` : `admin`, `member` — rien d'autre ;
- `contact_status` : `pending`, `accepted` — **il n'existe pas de `declined`**,
  d'où le refus d'une demande **par suppression de la ligne** ;
- `invitation_status` : `pending`, `accepted`, `declined`, `expired` ;
- `invitation_type` : `group`, `event`, `task`.

### `invitations` sert trois sortes d'invitation

Une seule table pour les groupes, les événements et les tâches. `type` est
**obligatoire** et discrimine ; une seule des trois clés `group_id`,
`event_id`, `task_id` est renseignée en conséquence.

Toute écriture dans `invitations` doit donc renseigner `type`, et toute lecture
destinée aux groupes doit filtrer `type = 'group'` — la jointure sur `groups`
suffirait par accident, ce qui n'est pas une raison de s'en remettre à elle.
`accepter_invitation` refuse explicitement un autre type : elle ne sait insérer
que dans `group_members`.

Deux conséquences de forme :

- `groups` ne porte ni couleur ni icône : `GroupAccent.forId` et l'icône sont
  **dérivées de l'identifiant** par une somme de contrôle stable. Ne pas
  utiliser `String.hashCode`, qui change d'une exécution à l'autre.
- Le favori est **personnel** : une seule ligne par relation, mais deux colonnes.
  L'application écrit `favorite_requester` ou `favorite_addressee` selon le bout
  où se trouve l'utilisateur ; `mes_contacts()` renvoie déjà le bon.

### `expires_at` sur `group_members`

L'adhésion temporaire — un membre invité le temps d'un voyage. `null` signifie
« sans terme ». **Toute lecture de `group_members` filtre les adhésions
échues**, en SQL comme côté client (`_activeMembership` dans le dépôt).

Voir « Adhésion temporaire » plus bas pour la façon dont un terme se pose et ce
qu'il déclenche.

### Le `returning` d'une insertion passe par la politique SELECT

Piège coûteux, rencontré sur la création de groupe. `groups_select` exige
`is_group_member(id)`, et **PostgreSQL applique les politiques SELECT au
`returning` d'un `insert`**. Un `insert(...).select()` sur `groups` échoue donc
en `42501` : à cet instant, le créateur n'est pas encore dans `group_members`,
sa propre ligne lui est invisible.

Un déclencheur `after insert` qui inscrirait le créateur n'y change rien : les
déclencheurs `after row` s'exécutent en fin d'instruction, après le contrôle de
visibilité. D'où `creer_groupe`, fonction `security definer` qui insère le
groupe et l'adhésion admin dans la même transaction.

**Règle générale** : sur une table dont la politique SELECT dépend d'une ligne
créée *ensuite*, ne pas utiliser `insert(...).select()` — passer par une
fonction. Cela vaut aussi pour toute future table de ce genre.

### Migrations

Elles s'appliquent **toutes seules** à chaque push sur `main` : voir « Les
migrations s'appliquent toutes seules » en tête de document. L'ordre vit dans
`supabase/migrations.txt`, et une nouvelle migration n'existe qu'une fois
ajoutée à ce fichier — un `.sql` déposé dans `supabase/` sans y figurer ne
sera jamais appliqué. C'est voulu : c'est ce qui tient les scripts de
diagnostic à l'écart.

**L'ordre du fichier n'est pas celui des numéros**, et ne peut pas l'être :
`tranche7_durcissement.sql` referme l'exécution de toute fonction absente de sa
liste et **lève si un nom de sa liste n'existe pas en base**. Il reste donc le
dernier passage, et les tranches 8, 9, 10 et 11 s'insèrent avant lui.

Trois entrées de `supabase/` ne sont **pas** des migrations : elles n'écrivent
rien et ne changent rien.

| Entrée | Rôle |
| --- | --- |
| `diagnostic_invitation.sql` | rejoue l'invitation nominative sous `authenticated`, dans une transaction annulée |
| `diagnostic_taches_evenements.sql` | même chose pour les tâches et les événements, précédé de l'audit du schéma (PARTIE A) |
| `verification/` | contrôle local sur base jetable, décrit en tête de document |

Les deux fichiers de diagnostic **peuvent** être collés dans l'éditeur SQL du
projet : leur PARTIE A est en lecture seule, leur PARTIE B se termine par un
`rollback`. Ils ne sont simplement pas à rejouer comme les migrations.

La tranche 2 apporte les favoris personnels, `expires_at`, la table
`group_invite_links` avec ses politiques, et les fonctions ci-dessous.

| Fonction | Rôle |
| --- | --- |
| `est_membre_du_groupe`, `est_admin_du_groupe` | prédicats `security definer`, pour écrire les politiques sans récursion `group_members` → `group_members` |
| `membres_du_groupe` | membres + profil, réservé aux membres |
| `mes_contacts` | carnet + profil d'en face + favori du bon côté + *(tranche 10)* groupes en commun |
| `chercher_profils_par_pseudo` | recherche par début de pseudo |
| `apercu_groupe_par_jeton` | aperçu public d'un lien |
| `rejoindre_groupe_par_jeton` | valide le jeton et insère le membre |
| `quitter_groupe` | départ, promotion, suppression — en une transaction |
| `mes_invitations`, `inviter_dans_groupe`, `accepter_invitation`, `refuser_invitation` | invitations nominatives |
| `invitation_par_id` | *(tranche 8)* une invitation **dans l'état où elle se trouve**, pour son écran |
| `creer_groupe` | groupe + adhésion admin en une transaction (voir ci-dessus) |
| `mes_groupes_apercu` | *(tranche 11)* effectif **et** quatre profils par groupe, en une lecture |

`supabase/correctif_invitations_type.sql` renseigne `invitations.type` dans
`inviter_dans_groupe` et restreint `accepter_invitation` et `mes_invitations`
au type `group`. Il porte aussi la requête de vérification du schéma.

**Pourquoi tant de fonctions plutôt que des requêtes directes.** Deux raisons,
et une seule suffirait :

1. Rien ne garantit qu'un utilisateur puisse lire la ligne `profiles` d'un autre.
   Passer par une fonction `security definer` fait marcher membres, contacts et
   recherche **quelle que soit la politique RLS de `profiles`**, sans l'assouplir.
2. Un arrivant n'est pas encore membre : il ne peut pas s'insérer lui-même dans
   `group_members`. L'adhésion **doit** passer par une fonction.

`quitter_groupe` relève d'un troisième motif : trois écritures dépendantes —
retrait, promotion du plus ancien membre, suppression douce du groupe — qui,
enchaînées depuis le client, laisseraient un groupe sans administrateur en cas
d'échec au milieu.

### L'écran d'un groupe

Bandeau photo, description, deux compteurs, trois accès rapides, puis les
sections « À venir », « Tâches prioritaires » et « Membres ».

#### Ce que la maquette proposait et qui n'existe pas

| Écarté | Pourquoi |
| --- | --- |
| pictogrammes **Listes** et **Dépenses** | aucune table, aucun écran, rien nulle part |
| pictogramme et compteur **Notes** | idem — la maquette le montrait, le projet ne l'a jamais eu |
| compteurs **listes actives** et **notes** | un compteur qu'aucune donnée n'alimente vaut zéro pour tout le monde, pour toujours |
| section **« Prochains événements »** | elle listait les mêmes événements que « À venir », une section plus bas |

`task_list_items` pourrait faire croire à des listes : c'est la case à cocher
**d'une tâche**, pas un objet qu'on ouvre. La confondre avec la ligne
« Listes » de la maquette donnerait un écran sans contenu.

**Il reste donc deux compteurs et trois accès rapides**, et chacun mène quelque
part de réel : la conversation, les tâches du groupe, le calendrier filtré sur
lui.

#### Les deux compteurs se calculent sans une lecture de plus

`mes_taches` et `mon_agenda` sont déjà chargées **sans bornes de dates** et
portent `group_id` : `groupStatsProvider` n'a qu'à filtrer.

| Compteur | Règle |
| --- | --- |
| tâches en retard | `Task.isOverdue` — `completed_at` vide et `due_at` dépassée |
| événements à venir | **`end`** encore devant nous, et non `start` |

La fin plutôt que le début n'est pas un détail : un événement commencé ce matin
et qui dure jusqu'au soir serait sinon compté comme passé alors qu'on y est.

**Zéro n'est pas une erreur, mais il ne s'alarme pas** : la pastille du retard
ne devient rouge qu'au-delà de zéro. Un rond rouge sur un « 0 » annoncerait un
problème qui n'existe pas.

#### « Voir tout » demandait une destination qui n'existait pas

Le lien des tâches ouvrait `/taches`, c'est-à-dire **toutes** les tâches — pas
celles du groupe qu'on venait de lire. D'où `?groupe=<id>`
(`AppRoutes.tasksGroupParam`), qui restreint la liste et titre l'écran du nom
du groupe. Même forme que `/creer?groupe=…`, et pour la même raison : un
`extra` se perdrait au rafraîchissement du web.

Côté événements, rien à inventer : le filtre par groupe du calendrier existe
depuis sa refonte. « Voir tout » le pose et navigue.

#### Le bandeau

Les trois commandes sont des **pastilles blanches opaques** posées sur la
photo. Ce n'est pas décoratif : une icône blanche disparaît sur une photo
claire, une icône sombre sur une photo de nuit — le disque tranche dans les
deux cas. C'est le même problème que résout le dégradé de `CoverBanner` pour le
texte.

**La cloche compte les notifications de tout le monde, pas celles du groupe.**
`notifications` n'a pas de colonne de groupe, et son `payload` ne porte pas
l'identifiant pour tous les types : un compteur par groupe demanderait une
lecture que la base ne sait pas faire. Elle ouvre donc la boîte complète.

Sans photo, le repli est le dégradé d'accent — et `CoverBanner` reçoit
`showFallbackIcon: false`, la vignette ronde portant déjà la même icône juste
en dessous. Les deux superposées se lisaient comme un défaut d'affichage.

**Les avatars n'apparaissent qu'une fois les membres chargés.** Une rangée
factice mentirait sur qui est là.

#### Le crayon de la description est réservé aux administrateurs

`groups` n'est modifiable que par eux : un crayon qui ouvrirait un formulaire
que la base refuse serait pire qu'une ligne inerte. Sans description, la ligne
invite un administrateur à en écrire une, et **disparaît** pour un membre
simple — il n'y a alors ni texte à lire ni geste à proposer.

#### « Tâches prioritaires » trie, sinon le titre ment

Priorité décroissante, puis échéance la plus proche, sans échéance en dernier.
Trois lignes au plus. **Seule la priorité « Haute » porte une pastille** :
« Normale » est le défaut de `creer_tache`, et l'afficher sur les trois quarts
des lignes noierait les deux qui comptent. « Basse » garde le gris — lui donner
`warning` lui prêterait une urgence qu'elle dit précisément ne pas avoir.

### Le groupe et ses premiers membres se décident ensemble

Avant, il fallait créer le groupe, ouvrir son écran, puis inviter — trois
étapes pour une seule intention, et un groupe vide entre-temps.
`GroupMemberPicker` met la sélection dans l'écran de création : rangée
d'avatars des contacts acceptés, favoris en tête, recherche pour retrouver
qui n'y figure pas.

**La rangée est l'état d'ouverture, la recherche ne fait que la compléter** :
dans un carnet de quelques dizaines de noms, reconnaître un visage est plus
rapide que taper un nom.

Deux règles que le code porte, et qu'il faut garder :

- **les invitations partent après la création, et leur échec ne remet rien en
  cause.** `inviteAll` ne lève jamais et renvoie le nombre d'invitations non
  parties ; l'écran entre dans le groupe puis le dit. Lever ici afficherait
  une erreur sur un groupe pourtant bien créé ;
- **un échec partiel est nommé.** Sans message, on croit avoir invité cinq
  personnes alors que deux n'ont rien reçu, et rien ne le signale — c'est le
  même défaut silencieux qu'une écriture PostgREST sans effet.

Le sélecteur n'apparaît **qu'à la création**. En modification, la liste des
membres se gère depuis l'écran du groupe, qui sait aussi les retirer.

#### Le critère des suggestions se constate, il ne se devine pas

La rangée classe **favoris d'abord, puis les groupes en commun décroissants,
puis l'ordre alphabétique**. Les deux premiers disent la même chose de deux
façons — qui l'on fréquente : le favori est *déclaré*, les groupes en commun se
*constatent*. Quelqu'un avec qui on organise déjà trois choses est un candidat
plus probable qu'un contact rencontré une fois, et l'ordre alphabétique n'en
sait rien.

**Rien n'est lu de plus pour cela** : `mes_contacts` renvoie déjà
`groupes_communs` depuis la tranche 10. C'est le seul critère envisagé qui ne
demandait aucune colonne — « les plus fréquents » supposerait un compteur
d'interactions que rien n'écrit, et « les plus récents » une date de dernier
échange que `contacts` ne porte pas.

#### « Groupe privé » est un constat, et l'interrupteur a disparu

**La colonne `groups.is_private` existe bel et bien** — `not null`, défaut
`true` —, `creer_groupe` la renseigne, `Group` la lit. Ce n'est donc pas une
donnée inventée.

Mais **rien ne s'en sert**. Aucune politique RLS ne la cite, aucune fonction
n'en dépend, et `groups_select` exige `is_group_member(id)` quelle qu'en soit
la valeur. Jelvo n'a ni annuaire de groupes, ni page publique, ni recherche par
nom : **tout groupe Jelvo est privé**, et un interrupteur qui se décoche
promettait un groupe public qui n'existe pas.

La ligne reste — elle dit quelque chose de vrai, et de rassurant — mais c'est
le **contrôle** qui s'en va. `creer_groupe` reçoit `true`, qui est déjà son
défaut. Le jour où un groupe public existerait, l'interrupteur reviendrait ici
sans une ligne de SQL à changer.

C'est la même règle que les lignes Téléphone et Localisation écartées du
profil, appliquée à un cas plus retors : ici la donnée existe, c'est son
*effet* qui manque.

#### « Inviter par lien » se décide avant, et s'exécute après

Un jeton se tire sur un groupe qui **existe** : la carte ne peut donc rien
faire au moment où on la touche. Elle retient l'intention, et
`?lien=1`(`AppRoutes.groupLinkParam`) la porte jusqu'à l'écran du groupe, qui
ouvre `InviteLinkSheet` à l'arrivée — une seule fois, un retour sur l'écran ne
la rouvre pas.

Le paramètre passe par l'**URL** et non par un `extra`, pour la même raison que
`/creer?type=…` : un `extra` se perd au rafraîchissement du web.

L'alternative — afficher la carte et répondre « le lien s'obtient une fois le
groupe créé » — aurait été exactement la ligne qui ne mène nulle part qu'on
écarte partout ailleurs.

#### Le scan de QR code n'entre pas dans la création de groupe

La maquette pose une icône de QR dans le champ de recherche. Elle est écartée :
le QR de Jelvo encode un **pseudo** et sert à **ajouter un contact**, pas à
inscrire quelqu'un dans un groupe. L'y mettre ferait espérer un geste — scanner
le téléphone d'en face pour l'ajouter au groupe — que rien n'exécute, et le
scanner est de toute façon désactivé sur le web, où il n'y a pas de caméra.

### Invitations : deux mécanismes distincts

**Nominative** (`invitations`) — pour quelqu'un **déjà inscrit**. L'écran
d'invitation montre l'émetteur, le groupe, sa description, quelques membres, et
les deux seules réponses possibles. Accepter crée la ligne `group_members`.

**Par lien** (`group_invite_links`) — pour quelqu'un **sans compte**. Un membre
génère le lien depuis l'écran du groupe et le partage par `share_plus`. Le
destinataire ouvre `/rejoindre/<jeton>`, route **publique**.

- Sans session, le jeton est retenu par `pendingInviteTokenProvider` et
  l'inscription prend le relais ; le groupe est rejoint à la fin, dans
  `SignUpActions.completeProfile()` comme après une connexion.
- Cinq états couverts, chacun avec son message : **valide, invalide, expiré,
  révoqué, épuisé** — plus « déjà membre » à l'adhésion.
- La lecture anonyme de `group_invite_links` est restreinte **par un `grant`
  de colonnes** à `(token, group_id)` : le reste de la ligne — auteur, compteur
  d'usage, échéance — n'est visible que des membres.
- Le jeton est tiré côté client avec `Random.secure()`, 16 octets en base64 URL.

### Garde de navigation

`AppRoutes.isPublic` ajoute une comparaison **par préfixe** à `publicPaths` : un
lien d'invitation porte un jeton variable. Attention à la dissymétrie du
`redirect` — un utilisateur connecté est renvoyé à l'accueil depuis un écran
d'authentification, **mais pas depuis `/rejoindre/…`**, qu'il doit pouvoir
ouvrir. C'est même le cas courant : un membre qui teste son propre lien.

---

## Adhésion temporaire

`group_members.expires_at` existait depuis la tranche 2, et toutes les lectures
le filtraient déjà. `supabase/tranche6_adhesion_temporaire.sql` apporte de quoi
**poser** un terme, et de quoi en tirer les conséquences.

### Ce qui se passe tout seul, et ce qui demande une écriture

**C'est la distinction qui commande toute la tranche.** À la seconde où
`expires_at` est passé :

- le groupe, ses tâches, ses événements et sa conversation **disparaissent
  déjà** de l'application de l'intéressé, et il ne reçoit **déjà plus** aucune
  notification du groupe. Rien à écrire : `est_membre_du_groupe` porte la
  condition, et les rares endroits qui joignent `group_members` directement la
  portent aussi ;
- mais **ce qui a été écrit en son nom reste écrit**. Une tâche lui reste
  assignée, une invitation à un événement lui reste attachée, une notification
  déjà déposée reste dans sa boîte.

`appliquer_adhesions_echues()` ne fait *que* la seconde moitié. Le battement
n'est donc pas ce qui fait expirer l'adhésion — elle est déjà expirée — mais ce
qui range derrière elle : assignations retirées, participations retirées,
notifications du groupe refermées, file d'envoi purgée, ligne supprimée.

Elle reprend aussi les deux garde-fous de `quitter_groupe` : plus aucun membre
actif ferme le groupe, plus aucun administrateur promeut le plus ancien.

### Deux `expires_at` qui ne parlent pas de la même chose

`invitations.expires_at` et `group_invite_links.expires_at` disent jusqu'à
quand **l'invitation** vaut. Le terme de l'adhésion est une autre date, et
porte donc un autre nom : **`membership_expires_at`**, sur les deux tables. Les
confondre donnerait une adhésion prenant fin le jour où l'invitation cesse
d'être acceptable.

Le terme voyage avec l'invitation et ne dépend pas du moment où elle est
acceptée : « jusqu'au 31 août » vaut jusqu'au 31 août, qu'on accepte le 1er ou
le 20.

### La suppression de la ligne est la mémoire

Une fois retirée de `group_members`, l'adhésion n'est plus sélectionnée : le
passage suivant ne la retraite pas. Pas de colonne `traite_le`, pas de table de
suivi, pas de course entre deux battements — même principe que la clé primaire
de `push_reminders_sent`. Le contrôle négatif est dans `fumee.sql` : en
retirant le `delete`, le second passage échoue.

**Conséquence assumée** : une adhésion échue et rangée ne se prolonge plus. Il
faut réinviter.

### Le battement est celui qui existe déjà

`envoyer-push` appelle `appliquer_adhesions_echues()` dans le **même** passage
que `empiler_rappels()`, chaque minute. Une seconde planification serait une
seconde cadence à tenir d'accord — le reproche déjà fait aux deux
planifications écartées pour les rappels.

L'ordre compte : ranger **avant** de lire la file écarte les notifications
déposées à quelqu'un dont l'adhésion vient de prendre fin.

### Poser, déplacer, effacer : une seule écriture

`definir_terme_adhesion(groupe, membre, date)` couvre les trois gestes —
prolonger, écourter, rendre permanent — parce que la base n'en connaît qu'un :
poser une valeur, ou poser `null`. Trois fonctions diraient trois fois la même
chose, et la troisième finirait par diverger. Côté écran, une seule entrée de
menu et une feuille qui montre l'état actuel avant de le changer.

Deux refus valent d'être connus :

- **une date déjà passée est refusée** (`terme_passe`). Écourter jusqu'à hier,
  c'est retirer quelqu'un du groupe — avec des conséquences que « Retirer du
  groupe » annonce, confirmation comprise, et que ce chemin-ci n'annoncerait
  pas ;
- **le dernier administrateur ne peut pas devenir temporaire**
  (`dernier_admin`). Ce serait programmer un groupe que personne ne peut plus
  administrer. Même règle que `retrograder_membre` et `retirer_membre`.

Fixer une durée est réservé aux **administrateurs**, y compris à l'invitation ;
inviter tout court reste ouvert à tout membre, comme avant.

### Le terme se dit avant d'accepter, pas après

Une adhésion qui s'arrête n'est pas la même offre qu'une adhésion sans fin.
`apercu_groupe_par_jeton` et `mes_invitations` renvoient donc
`membership_expires_at`, et les deux écrans l'annoncent au-dessus des boutons.

Cela a coûté **deux `drop function`** : un `returns table` ne gagne pas une
colonne de sortie par `create or replace`. C'est l'inverse de l'arbitrage rendu
pour `preset:`, où onze suppressions en production auraient été le prix d'un
gain nul côté appelant ; ici le gain est pour l'invité, et il n'y a pas
d'expression à détourner.

`membership_expires_at` n'entre **pas** dans le `grant` de colonnes qui ouvre
`group_invite_links` à `anon` : la lecture anonyme reste `(token, group_id)`, et
c'est la fonction d'aperçu qui dit la durée une fois le jeton reconnu.

### Une date choisie vaut toute sa journée

`MembershipTermPicker.finDeJournee` retient 23 h 59. Une adhésion « jusqu'au
31 août » qui expirerait à minuit s'arrêterait la veille au soir, ce que
personne n'attend d'une date prise dans un calendrier.

« Sans terme » est **l'état d'ouverture** du sélecteur, et doit le rester : une
adhésion permanente est le cas courant, une durée est le cas qu'on choisit.

---

## Les trois écrans d'invitation

Rejoindre un groupe, venir à un événement, prendre une tâche : trois
demandes, un seul motif. **Qui demande** en haut, **ce à quoi on est convié**
au milieu, **la réponse** en bas — refus à gauche en contour, accord à droite
en plein.

| Écran | Route | Réponse |
| --- | --- | --- |
| groupe | `/invitations/:id` | Refuser · Rejoindre |
| événement | `/evenements/:id/invitation` | Non · Peut-être · Oui |
| tâche | `/taches/:id/attribution` | Refuser · Accepter |

Les deux derniers **n'existaient pas** : une invitation à un événement ouvrait
son écran de détail, et une tâche confiée n'ouvrait rien du tout. Le motif
commun vit dans `core/widgets/invitation_header.dart` — `InvitationHeader`,
`InvitationDetailRow`, `InvitationActions` —, qui ne connaissent pas plus le
domaine que les autres composants de `core`.

### Le bandeau de couverture est le même sur les trois

`CoverBanner` vivait dans la feature `groups`, ce qui l'y enfermait : une
feature ne lit pas les widgets d'une autre. Il est monté dans `core/widgets` —
il ne prend que des `String`, une `Color` et une `IconData`, jamais un
`Group` — et les trois écrans le posent en tête.

**L'ordre de préférence de l'image est le même partout** : ce que l'élément
porte en propre, puis la couverture du groupe, puis le repli d'accent. Sur
l'écran d'un événement :

```
events.image_url  →  groups.photo_url  →  dégradé + icône
```

C'est le même ordre qu'un avatar : prédéfini, photo, initiales. Le repli n'est
jamais une illustration choisie par l'application — c'est un dégradé, dérivé
de l'identifiant du groupe, ou de celui de l'élément quand il est personnel.

**Une tâche ou un événement personnel garde son bandeau**, titré
« Personnel ». Le supprimer ferait démarrer un des trois écrans à une hauteur
différente des deux autres, pour un cas qui n'a rien d'exceptionnel.

#### `groupe_nom` et `groupe_photo` viennent de la lecture, pas du client

`mon_agenda` et `mes_taches` les renvoient. Les relire par `groupByIdProvider`
paraissait plus simple et était faux : **un convive ou un assigné n'est pas
forcément membre du groupe**, et sa liste de groupes ne contiendrait alors ni
le nom ni la photo. L'écran affichait « Personnel » pour une tâche de groupe.
La liste locale ne sert plus que de repli.

### Décider si l'on vient n'est pas retrouver ce qu'on a accepté

C'est ce qui justifie deux écrans par élément plutôt qu'un. `EventDetailScreen`
sert à **retrouver** : modifier, supprimer, voir qui vient. L'écran
d'invitation sert à **décider** : il met l'organisateur en tête, l'essentiel
au milieu, et la réponse sous le pouce. Les fusionner reviendrait à ouvrir un
écran d'administration à quelqu'un qui se demande seulement s'il est libre
samedi.

### Une invitation ne se lit plus seulement quand elle est en attente

`mes_invitations` ne renvoie que les `pending`, sur un groupe vivant. Quatre
situations très différentes — déjà acceptée, déjà refusée, expirée, groupe
supprimé — n'y trouvaient donc rien, et l'écran disait « Invitation
introuvable » pour toutes les quatre.

`invitation_par_id` renvoie **toujours une ligne**, avec un mot d'état
(`InvitationScreenStatus`) : `valide`, `acceptee`, `refusee`, `expiree`,
`deja_membre`, `groupe_supprime`, `introuvable`. Deux conséquences tenues par
le code :

- **aucun bouton sans effet.** Hors de `valide`, « Rejoindre » et « Refuser »
  disparaissent au lieu d'être grisés, et un pavé dit ce qui s'est passé. Une
  invitation déjà acceptée propose la seule suite qui ait du sens : ouvrir le
  groupe ;
- **`introuvable` rend une ligne, pas zéro.** Un appelant qui reçoit une liste
  vide ne saurait pas distinguer « rien à cet identifiant » d'une lecture qui a
  mal tourné.

La fonction est réservée à l'invité : l'identifiant d'une invitation qui n'est
pas la sienne donne `introuvable`, et non le nom du groupe. Le test de fumée en
fait un contrôle négatif.

### Ce que la maquette montrait et que la base ne sait pas

**Une seule chose manque, et c'est la même des deux côtés : l'ancienneté.**

| Écran | « depuis combien de temps » |
| --- | --- |
| groupe | `invitations.created_at` — réel |
| événement | **rien** : `event_participants` ne porte que `responded_at` |
| tâche | **rien** : `task_assignees` ne porte aucune date de création |

`events.created_at` et `tasks.created_at` s'en approchent, mais seraient faux
pour quiconque est convié ou assigné après coup. La ligne est donc omise —
`InvitationHeader.since` est facultatif — plutôt que remplie d'une valeur
vraisemblable.

Le reste de la maquette existait bel et bien, contrairement à ce qu'on pouvait
craindre : `events.image_url`, `tasks.priority` (`low`/`medium`/`high`) et la
valeur `maybe` de `event_response` sont dans le schéma initial. Le « peut-être »
n'a donc pas eu à être inventé.

Deux lignes de la maquette sont **omises quand la donnée est nulle** plutôt
qu'affichées vides : le lieu d'un événement et la description d'une tâche.
« Non précisé » ferait passer un champ vide pour une donnée — même règle que
les lignes Téléphone et Localisation écartées du profil.

### Le nom de qui invite a coûté deux `drop function`

`mon_agenda` et `mes_taches` renvoyaient `owner_id` et `created_by`, donc un
identifiant. L'en-tête, lui, ouvre sur une phrase. Reconstituer le nom côté
client demanderait de lire `profiles`, ce que RLS n'autorise pas toujours —
c'est la raison même pour laquelle ces lectures sont `security definer`.

Une colonne de sortie de plus impose un `drop function` : même arbitrage qu'en
tranche 6, et même conclusion, le gain étant pour celui qui lit.

`auteur` vaut `null` quand le profil a disparu, et l'écran **reformule sans
sujet** — « Cette tâche vous a été confiée » — au lieu d'inventer un nom. Même
règle que `public.nom_affiche` côté notifications système.

### Une tâche confiée entre enfin dans la boîte

La tranche 5c poussait `task_assigned` vers le téléphone, mais **aucune ligne
n'était déposée dans `notifications`**. La seule trace d'une tâche confiée
était donc une notification système, qui disparaît une fois balayée : l'écran
d'attribution n'aurait eu aucune entrée dans l'application.

`notifier_attribution_tache` comble l'écart, sur le modèle exact de
`notifier_invitation_evenement` : `security definer` — la table n'a aucune
politique d'insertion —, et toute erreur consignée en `warning`. **Une
notification est un effet de bord : elle ne doit jamais faire échouer
l'écriture qui l'a provoquée.**

Deux clôtures l'accompagnent, et la seconde n'est pas du confort :
`clore_notification_tache` sur `update` — répondre referme —, et
`clore_notification_tache_retiree` sur `delete`, parce que
`definir_assignes_tache` **supprime** la ligne au lieu de la modifier. Sans
elle, une notification resterait seule à réclamer une réponse sur une tâche
qui n'est plus la vôtre.

`NotificationType.taskAssigned` compte pour l'onglet **Accueil** : les tâches
n'ont pas d'onglet, et c'est de là que leur liste s'ouvre.

### La réponse remonte à qui a confié la tâche

Confier une tâche prévenait l'assigné ; accepter ou refuser ne prévenait
personne. C'était un **aller sans retour** : celui qui compte sur la tâche
devait rouvrir l'écran pour savoir si elle était prise.

`notifier_reponse_tache` est le symétrique exact de `push_reponse_evenement`,
qui remonte déjà la réponse à l'organisateur d'un événement, et pour la même
raison : c'est **lui** que la réponse intéresse, et lui seul.

Deux dépôts dans le même déclencheur, comme partout ailleurs : une ligne dans
`notifications` pour la boîte, qui se dépile, et un `empiler_push` pour le
téléphone.

| | |
| --- | --- |
| titre push | le nom du groupe — « Personnel » à défaut |
| corps push | `Léa Marchand accepte : Réserver le restaurant` |
| ouverture | `/taches/:id`, le **détail** et non l'écran d'attribution |

L'ouverture n'est pas un détail : qui a confié la tâche n'y est pas assigné, et
l'écran d'attribution lui dirait « Cette tâche ne vous est pas assignée ».

Trois refus tenus par le déclencheur :

- **seul le passage de « en attente » à une réponse compte.** Un `done` posé
  plus tard est un avancement, pas une réponse à l'attribution ;
- **répondre à sa propre tâche ne notifie pas.** On sait ce qu'on vient
  d'écrire ;
- toute erreur est consignée en `warning` : une notification ne fait jamais
  échouer l'écriture qui l'a provoquée.

**Le type entre dans `types_de_notification()`**, sans quoi il ne serait pas
désactivable depuis les réglages — et un envoi qu'on ne peut pas couper est un
défaut. Ils sont donc **huit**, et le test de fumée le vérifie.

### Les trois réponses à un événement ont changé d'ordre

`ResponseButtons` affichait Oui · Peut-être · Non ; il affiche désormais
**Non · Peut-être · Oui**, partout — écran de détail et ligne de notification
compris.

Le garder à un endroit et pas à l'autre aurait été le pire des deux : trois
boutons identiques dont le premier veut dire « oui » ici et « non » là, à un
doigt d'écart.

**Un événement passé se dit, mais ne se verrouille pas.** La base accepte
encore la réponse ; griser les boutons poserait une règle qu'elle n'a pas. De
même, une réponse déjà donnée est rappelée par un pavé, sans empêcher d'en
changer — contrairement à une invitation de groupe, qui ne se répond qu'une
fois.

### La liste des groupes

Grande carte par groupe : photo de couverture en bandeau paysage, puis le nom,
l'effectif, la rangée d'avatars et une ligne d'activité. La pastille violette
des non lus est à droite.

#### La rangée d'avatars ne coûte pas une lecture par carte

C'était le piège de cet écran. La façon évidente d'avoir des avatars —
`membres_du_groupe` par carte — donne **une requête par ligne de la liste**, et
la liste est ce qu'on ouvre en premier.

`fetchMyGroups` comptait déjà les membres « en une requête plutôt qu'une par
carte ». `mes_groupes_apercu` reprend ce compte et lui adjoint les quatre
profils que la rangée montre : **le nombre de requêtes ne bouge pas**, la
rangée est offerte.

**Pourquoi une fonction et non un embed PostgREST.** Joindre `profiles` depuis
`group_members` paraît plus simple, mais depuis la tranche 7 `profiles_select`
vaut `id = auth.uid() or has_social_link(id)`. L'embed rendrait donc des
profils **partiellement nuls, sans erreur** — des avatars manquants au hasard,
et rien pour le dire. C'est la raison d'être de `membres_du_groupe`, et elle
vaut ici aussi.

Quatre profils au plus : au-delà, `AvatarStack` bascule sur « +N », et
`memberCount` dit déjà le reste. Le « +N » se calcule donc sur l'**effectif** et
non sur la longueur de la rangée — d'où `AvatarStack.extraCount`, sans quoi un
groupe de huit afficherait quatre visages et aucun reste.

L'ordre de l'aperçu est **stable** — les plus anciens d'abord, `user_id` pour
départager. Sans lui, la rangée changerait de visages d'une lecture à l'autre
sans que rien n'ait bougé.

#### La ligne d'activité ne lit rien de plus

`mes_taches` et `mon_agenda` sont déjà chargées sans bornes de dates et portent
`group_id` : `groupActivityProvider` filtre en mémoire, comme les compteurs de
l'écran d'un groupe.

**Zéro ne se dit pas.** « 0 tâche · 0 événement » est vrai et inutile, et se lit
comme un défaut de chargement. Un groupe sans rien annonce donc « Rien de prévu
pour l'instant », et **une seule moitié vide s'efface** au lieu d'afficher son
zéro : trois tâches et aucun événement donnent « 3 tâches en cours », pas
« 3 tâches en cours · 0 événement à venir ».

#### La recherche n'apparaît qu'à partir de trois groupes

En deçà, la liste tient à l'écran : un champ vide ne ferait que la repousser.
C'est le même arbitrage que le rail alphabétique du carnet, qui disparaît sous
deux sections.

**Deux vides, deux causes**, et l'action diffère : aucun groupe appelle à en
créer un, une recherche sans résultat appelle à l'effacer. Proposer « Créer un
groupe » à quelqu'un qui cherche « Corse » l'enverrait créer ce qu'il essaie de
retrouver.

#### La pastille violette compte les messages, pas les notifications

C'est `unreadForGroupProvider`, donc `messages_non_lus()` — le compte réel des
messages non lus de **cette** conversation. Elle est violette et non rouge : ce
n'est pas une alerte, c'est de l'activité. Le rouge de `NavBadge` sert les
compteurs de la barre, qui réclament une action.

C'est la carte qui dit ce nombre, là où la pastille de l'onglet Groupes compte
des *conversations* — voir « Deux compteurs qui répondent à deux questions ».

### La tranche 8 s'applique avant la tranche 7

`tranche7_durcissement.sql` retire l'exécution de toute fonction absente de sa
liste, et **lève si un nom de cette liste n'existe pas en base**. Il doit donc
rester le dernier passage de `migrations.txt`, quel que soit le numéro des
tranches qui s'ajoutent. `invitation_par_id`, puis `prendre_tache` et
`se_desister`, sont ajoutées à sa liste ; les fichiers des tranches 8 et 9
sont insérés **avant** lui.

---

## Tâches et événements

Même principe qu'en tranche 2 : le schéma initial fait autorité, et les
écritures passent par des fonctions `security definer`.

| Table | Colonnes |
| --- | --- |
| `tasks` | `id`, `group_id`, `created_by`, `title`, `description`, `due_at`, `priority`, `reminder_at`, `rrule`, `completed_at`, `created_at`, `deleted_at` |
| `task_assignees` | `task_id`, `user_id`, `status` — **pas de colonne `id`** |
| `task_list_items` | `id`, `task_id`, `label`, `position`, `checked_at`, `checked_by`, `created_at` |
| `events` | `id`, `group_id`, `owner_id`, `title`, `description`, `starts_at`, `ends_at`, `location`, `rrule`, `image_url`, `reminder_minutes`, `created_at`, `deleted_at` |
| `event_participants` | `event_id`, `user_id`, `response`, `responded_at` — **pas de colonne `id`** |

Trois énumérations de plus : `task_priority` (`low`, `medium`, `high`),
`assignee_status` (`pending`, `accepted`, `declined`, `done`) et
`event_response` (`yes`, `no`, `maybe`, `pending`).

**`completed_at` est la seule source du statut d'une tâche** : terminée si
renseigné, en retard si l'échéance est passée, à faire sinon. Aucun état n'est
stocké en double, donc rien ne peut se contredire.

`tasks` porte `reminder_at` — un instant — et `events` `reminder_minutes` — un
délai avant le début. L'asymétrie vient du schéma initial ; l'application s'y
plie plutôt que de l'uniformiser.

**Ni `tasks`, ni `events`, ni `task_assignees`, ni `event_participants` n'ont
de politique DELETE.** Supprimer une tâche est donc une suppression douce, et
changer la liste des assignés passe obligatoirement par
`definir_assignes_tache` : sans elle, on ne pourrait qu'ajouter.

Les fonctions de lecture — `mes_taches`, `mon_agenda` — renvoient les assignés
et les participants **agrégés en JSON**, profil compris. Un écran ne fait donc
qu'une seule lecture, sans jointure ni requête de complément, comme pour les
notifications.

Un événement sans `group_id` est un rendez-vous personnel : seul son
propriétaire le voit. Un événement de groupe convie par défaut tous les
membres actifs.

### Les deux formulaires de création

Feuilles montantes toutes les deux, et non des pages : créer une tâche est un
geste bref, et garder l'écran d'origine visible derrière dit d'où l'on vient.
Les deux partagent trois primitives, montées dans `core/widgets` :

| Composant | Rôle |
| --- | --- |
| `OptionRow` | icône, libellé, aide, valeur en violet, chevron |
| `ExpandableOptions` | la carte « Plus d'options » qui se replie |
| `PersonAvatarRow` / `PersonPickerSheet` | rangée d'avatars et liste complète |

**Ils ont changé de place pour une raison de règle, pas d'esthétique** :
`event_form_sheet.dart` importait `tasks/widgets/option_row.dart` et
`tasks/widgets/assignee_picker.dart` — or *une feature ne lit jamais les
widgets d'une autre*. Ces trois-là ne connaissent que des `String`, des
`IconData` et un `PickablePerson` (identifiant, nom, prénom, avatar) : ils
avaient leur place dans `core` depuis le début.

#### Aucun assigné n'est un choix, et l'écran doit le dire

**Personne n'est présélectionné dans « Assigner à ».** Ce n'était déjà pas le
cas, mais rien ne disait ce que cela **voulait dire** — et une rangée
d'avatars sans coche se lit spontanément comme un formulaire incomplet.

Or `null` et `[]` ne veulent pas dire la même chose pour `creer_tache` (voir
« `null` et `[]` ne veulent pas dire la même chose ») : le formulaire envoie
`<String>[]`, la tâche est **proposée au groupe**, et c'est ce qui produit la
carte à boutons Oui / Non dans la conversation.

D'où une mention sous la rangée, qui **change avec la sélection** au lieu de
n'apparaître qu'à vide :

| Sélection | Ce que dit la mention |
| --- | --- |
| aucune | « Proposée à tout le groupe : une carte s'affichera dans la conversation, et le premier qui accepte la prend. » |
| une | « Confiée à Léa, qui recevra une notification. » |
| plusieurs | « Confiée à Léa, Thomas et 2 autres, qui recevront une notification. » |

Elle change aussi d'icône et de teinte — mégaphone gris, silhouette violette —
mais **le texte porte seul le sens** : la couleur ne fait que le doubler.

#### « Autre » n'apparaît qu'au-delà de six membres

Le bouton ouvre la liste complète avec recherche. En deçà de sept membres, la
rangée les montre déjà tous : un bouton qui n'ouvrirait que les mêmes visages
n'irait nulle part. La feuille rend les **noms entiers**, là où la rangée n'a
la place que du prénom — c'est ce qui la rend utile, et non le seul fait de
tout montrer.

#### Le groupe d'un événement se choisit enfin

`GroupSelector` porte la photo du groupe, son nom et son nombre de membres.
**Il n'existait pas**, et l'absence était une vraie limite : le groupe était
*imposé par l'écran d'où l'on venait*. Ouvert depuis le calendrier ou depuis le
« + », le formulaire ne savait créer qu'un rendez-vous personnel — sans aucun
moyen de le rattacher à un groupe.

« Personnel » est **une valeur du choix, et non son absence** : un rendez-vous
qu'on est seul à voir est un cas courant, pas un défaut de saisie. Changer de
groupe vide les convives — ceux d'un groupe n'ont aucun sens dans un autre.

Le sélecteur ne paraît **qu'à la création**. Déplacer un événement d'un groupe
à l'autre changerait qui le voit, sans que personne en soit prévenu.

#### Participants : une ligne, pas une carte

La rangée d'avatars de l'événement devient une `OptionRow` qui ouvre la liste.
Sa valeur dit **« Tous les membres »** quand rien n'est coché — ce que fait
réellement `creer_evenement` avec une liste `null` — et non « aucun ». C'est
l'inverse exact de la tâche, et c'est voulu : convier tout le monde est le
défaut d'un événement, prendre une tâche ne l'est pas.

#### La date et l'heure se rangent, la fin ne disparaît pas

La maquette montre `Date | Heure` côte à côte, et rien d'autre. La suivre à la
lettre **refigerait la durée à une heure**, ce qu'elle a déjà été — un déjeuner
de famille et un week-end entier ne se ressemblent pourtant pas. La fin
descend donc d'une ligne, sous la colonne de l'heure à laquelle elle se
rapporte, plutôt que d'être supprimée.

#### La description sort de « Plus d'options », qui disparaît

Elle est visible d'emblée, avec son compteur de caractères
(`AppTextField.showCounter`). Ce que la maquette rangeait derrière « Plus
d'options » était « Ajouter une image, plus de détails… » — or **l'image d'un
événement n'a pas de dépôt** : `events.image_url` existe et se lit, mais aucun
bucket ne l'accueille et aucun écran ne la téléverse. Il ne restait donc rien
à replier, et un en-tête qui s'ouvre sur du vide est pire qu'un en-tête absent.

La tâche, elle, **garde** son « Plus d'options » : échéance, priorité et
description y sont vraiment, et sont vraiment rares.

### Toute valeur d'énumération écrite porte une conversion explicite

```sql
insert into public.task_assignees (task_id, user_id, status)
values (nouvelle.id, assigne,
        (case when assigne = utilisateur then 'accepted' else 'pending'
         end)::assignee_status)
```

Le `::assignee_status` n'est pas décoratif. Un littéral **seul** est de type
`unknown` et se laisse convertir vers la colonne visée ; dès qu'il entre dans
une expression — un `case`, un `coalesce` —, la résolution de type s'applique
d'abord, et deux littéraux `unknown` donnent du `text`. Or il n'existe **pas**
de conversion implicite de `text` vers un type énuméré. D'où :

```
42804: column "status" is of type assignee_status but expression is of type text
```

La tranche 3 a été livrée avec ce défaut sur quatre sites : toute création de
tâche et tout événement de groupe échouaient. Rien ne l'avait vu, parce que
rien ne pouvait le voir — voir ci-dessous.

**Règle** : convertir explicitement dès qu'une valeur d'énumération est écrite,
y compris pour un littéral seul, pour que la règle n'ait pas d'exception à
retenir.

### Une écriture PostgREST qui ne touche aucune ligne répond 200

Promouvoir un membre et le retirer ne fonctionnaient pas, sans jamais le dire.
L'application écrivait directement dans `group_members` :

```dart
await _client.from('group_members')
    .update({'role': 'admin'}).eq('group_id', id).eq('user_id', membre);
```

Si les politiques UPDATE et DELETE ne couvrent pas le cas d'un admin agissant
sur autrui, la requête ne touche **aucune ligne** — et PostgREST répond `200`
sans erreur. Aucune exception n'était levée, l'écran affichait « X est
désormais administrateur », et rien n'avait changé. **Un échec silencieux est
pire qu'une erreur** : il se diagnostique mal, et longtemps.

D'où `promouvoir_membre`, `retrograder_membre` et `retirer_membre` en
`security definer`, qui renvoient un **mot d'état** — `promu`, `dernier_admin`,
`non_admin`… — traduit par `MemberOutcome`. C'est lui, et non l'absence
d'exception, qui décide du message affiché.

**Règle** : une écriture dont l'effet dépend d'une politique RLS ne se juge pas
à l'absence d'erreur. Soit elle passe par une fonction qui dit ce qu'elle a
fait, soit elle relit ce qu'elle vient d'écrire.

### Créer une fonction ne prouve pas qu'elle s'exécute

`create function` ne contrôle que la **syntaxe** du corps d'une fonction
plpgsql. Les instructions SQL qu'elle contient ne sont préparées qu'au premier
appel : erreurs de typage, colonnes inexistantes et conversions manquantes ne
se manifestent qu'à l'exécution. Le rejeu de `rejouer.sh` passait au vert sur
les quatre `case` fautifs ci-dessus.

D'où `supabase/verification/fumee.sql`, lancé par `rejouer.sh` après les sept
fichiers : il pose un décor minimal — deux comptes, un groupe, deux adhésions —
puis **appelle réellement les vingt fonctions** des tranches 3 et 3b sous le
rôle `authenticated`, avec des `assert` sur ce qu'elles renvoient, et annule
tout par un `rollback`. C'est lui qui a trouvé le défaut, et lui seul le
pouvait.

Il ne couvre pas encore les fonctions des tranches précédentes, éprouvées par
l'usage en production. Les y étendre est la suite naturelle.

### `task_list_items.position` s'écrit entre guillemets — parfois

`POSITION` est un `col_name_keyword` de PostgreSQL, un mot dont la grammaire
accepte l'usage à certaines places et pas à d'autres :

| Contexte | Règle grammaticale | `position` nu |
| --- | --- | --- |
| colonne d'un `create table` | `ColId` | accepté |
| liste de colonnes d'un `insert` | `ColId` | accepté |
| référence qualifiée `i.position` | `ColId` | accepté |
| colonne de sortie d'un `returns table` | `type_function_name` | **refusé** |
| nom d'argument de fonction | `type_function_name` | **refusé** |

`type_function_name` exclut les `col_name_keyword` ; `ColId` les admet. D'où le
`"position"` cité dans la déclaration d'`articles_de_tache` : sans lui, la
fonction ne se crée pas (`42601: syntax error at or near "position"`). Les
guillemets ne renomment rien — la colonne reste `position` en minuscules, donc
`row['position']` côté Dart ne bouge pas.

Le piège est asymétrique : le mot passe partout ailleurs dans le fichier, y
compris dans les insertions juste au-dessus. C'est la seule occurrence
concernée de tout `supabase/` — vérifié en confrontant les noms de sortie de
chaque `returns table` et les noms d'argument de chaque fonction à la liste
`col_name_keyword`. Un nouveau nom à surveiller de la même façon : `time`,
`timestamp`, `row`, `values`, `interval`, `char`, `precision`, `setof`, `out`.

---

## Les cartes de la conversation

Une tâche proposée au groupe n'avait **aucun endroit où être vue de tous** :
l'écran d'attribution s'adresse à un assigné, et une tâche sans assigné ne
s'adressait donc à personne. La conversation est le seul endroit que tout le
groupe regarde — les tâches et les événements d'un groupe y déposent
désormais une carte, à laquelle on répond sur place.

### Une carte **est** une ligne de `messages`

Ce n'est pas un détail d'implémentation : c'est ce qui fait tenir trois
exigences d'un coup, sans une ligne de code pour chacune.

| Exigence | Ce qui la tient |
| --- | --- |
| rester à sa place chronologique | `order by created_at`, comme le reste |
| se mettre à jour chez les autres | `messages` est dans la publication depuis la tranche 5a |
| compter dans les non-lus | `messages_non_lus` ne fait pas de différence |

L'alternative — fusionner côté client la liste des messages et celle des
tâches — demandait de faire coïncider **deux paginations** : « les trente
derniers messages » et « les tâches créées dans le même intervalle ». Deux
fenêtres qui glissent l'une par rapport à l'autre, et un « charger plus » qui
ne sait plus où il en est.

`messages` gagne donc `task_id` et `event_id`, deux clés étrangères nullables
— la forme qu'a déjà `invitations`. Une ligne ordinaire les a toutes deux à
`null`. `content` porte le titre : `messages_check` exige un contenu **ou** un
média, et un client qui ne connaîtrait pas les cartes lirait au moins de quoi
savoir de quoi il s'agit.

**Une carte ne pousse pas comme un message.** `push_nouveau_message` les
écarte : l'élément qu'elles portent a déjà sa propre notification —
`task_assigned`, `event_invitation` —, et sans ce garde-fou l'assigné en
recevrait deux. La pastille de conversation, elle, s'allume normalement.

### `tache_prise` — ce qu'aucun état ne dit

Une tâche à un seul assigné se lit de deux façons **opposées** :

- « Thomas a pris la tâche » — il s'est proposé, il peut se désister ;
- « Tâche attribuée à Thomas » — on la lui a confiée, il répond mais ne se
  retire pas.

Les deux situations sont **identiques** dans `task_assignees` : une ligne, un
statut. Seule l'histoire les sépare, et c'est elle que retient
`messages.tache_prise`, posé par `prendre_tache` et retiré par `se_desister`.
Le nom du preneur, lui, n'est pas recopié : il reste dans `task_assignees`,
qui en est la seule source.

Conséquence assumée : une tâche créée sans assigné puis attribuée depuis
l'écran de détail devient « Tâche attribuée à X ». C'est ce qui s'est passé.

### Deux personnes qui acceptent au même instant

**C'est le point qui justifie une fonction plutôt qu'une insertion.** Toutes
deux liraient une tâche sans assigné, toutes deux s'insèreraient : la tâche
serait prise deux fois, et personne ne saurait par qui.

```sql
select * into tache from public.tasks t where t.id = p_task_id for update;
if exists (select 1 from public.task_assignees a where a.task_id = p_task_id)
then return 'deja_prise';
```

Le `for update` sérialise les deux transactions : la seconde attend la
première, puis voit l'assigné qu'elle vient de poser. Un test préalable sans
verrou se doublerait d'une course entre le test et l'insertion — même raison
que la clé primaire de `message_reactions` ou celle de `push_reminders_sent`,
à ceci près qu'ici aucune contrainte d'unicité ne peut porter la règle : elle
dit « aucun assigné », pas « pas deux fois le même ».

`prendre_tache` renvoie donc un **mot d'état** — `prise`, `deja_prise`,
`supprimee`, `non_membre` —, et c'est lui qui décide du message affiché. La
seconde personne lit « Quelqu'un vient de la prendre avant vous », et non le
silence d'une écriture sans effet.

### Se désister n'est pas refuser

`se_desister` ne s'applique qu'à ce qui a été **pris depuis la carte**. Une
tâche qu'on vous a confiée se refuse — `repondre_tache` —, elle ne se rend
pas : le refus reste visible pour celui qui l'a confiée, la disparition non.
La fonction ressort `non_desistable` dans ce cas, et le test de fumée en fait
un contrôle négatif.

### Répondre doit se voir chez les autres

`prendre_tache` et `se_desister` écrivent dans `messages` — le temps réel déjà
en place suffit. Répondre à une tâche confiée ou à un événement, en revanche,
ne touche que `task_assignees` ou `event_participants`, que le canal du groupe
n'écoutait pas. Les deux tables entrent donc dans la publication, et le canal
s'y abonne **sans filtre** : elles n'ont pas de `group_id`, comme
`message_reactions`. Sans conséquence — le signal ne transporte rien d'autre
qu'un « relis la fenêtre ».

### Ce que la base ne sait pas dire

**« Non » sur une tâche proposée ne s'écrit nulle part.** `assignee_status`
suppose une ligne d'assignation, et refuser une tâche qu'on ne vous a pas
confiée n'en crée aucune. Le bouton est donc un accusé de réception — « la
tâche reste proposée au groupe » — et non une écriture. L'inventer demanderait
une table de refus dont rien d'autre n'a besoin, et un « Non » qui masquerait
la carte à celui qui l'a touché priverait le groupe d'un avis qu'il ne verrait
jamais.

### `null` et `[]` ne veulent pas dire la même chose

`creer_tache` interprète une liste d'assignés **absente** comme « assigne
l'auteur », et une liste **vide** comme « proposée au groupe ». La distinction
existait déjà — le formulaire passe `<String>[]` quand aucun avatar n'est
sélectionné — et c'est elle qui décide de la carte qu'on obtient. La confondre
donnerait une tâche déjà prise par son auteur, sans boutons, ce que personne
n'attend d'une tâche qu'on propose.

### La carte est pleine largeur, la bulle non

Ce n'est pas quelqu'un qui parle, c'est quelque chose qui arrive au groupe :
la distinction doit se voir avant d'être lue. La carte ne porte ni avatar ni
réaction, et **coupe la série** — la bulle qui la suit recommence par son nom.

Un appui ouvre le détail ; les boutons répondent sur place. Une carte
supprimée n'ouvre plus rien et **garde son titre** : sans lui, elle ne dirait
plus de quoi il s'agissait.

---

## Disponibilités

`availabilities` et `get_availability_status` **viennent du schéma initial** :
`supabase/tranche4_disponibilites.sql` n'en crée ni n'en modifie aucun, il
n'ajoute que quatre fonctions d'accès. Les colonnes ont été relevées sur le
projet avant d'écrire une ligne, conformément à « Le schéma initial fait
autorité ».

| Table | Colonnes |
| --- | --- |
| `availabilities` | `id`, `user_id`, `weekday`, `on_date`, `start_time`, `end_time`, `status`, `kind`, `created_at` |

Deux énumérations : `availability_status` (`available`, `unavailable`) et
`availability_kind` (`recurring`, `exception`).

Un créneau `recurring` s'appuie sur `weekday`, un créneau `exception` sur
`on_date`. **Une exception remplace la règle hebdomadaire du jour**, elle ne
s'y ajoute pas : c'est tout l'objet d'une exception, et les cumuler donnerait
une journée comptée deux fois. `slotsForDayProvider` applique cette règle une
fois pour toutes ; `availableMinutesForDayProvider` s'y branche.

### `weekday` ne se compte pas pareil des deux côtés

La base retient **`extract(dow)` — 0 = dimanche … 6 = samedi**, et le fait
tenir : `availabilities_weekday_check : CHECK (weekday >= 0 AND weekday <= 6)`.
Dart retient l'**ISO — 1 = lundi … 7 = dimanche** (`DateTime.weekday`).

Les deux conventions **coïncident du lundi au samedi**. Seul le dimanche les
sépare — et c'est exactement ce qui rend l'écart si facile à ne pas voir : six
cas sur sept passent sans conversion, et le septième échoue en `23514`.

L'application garde l'ISO en mémoire, pour que `slot.weekday == jour.weekday`
se compare sans arrière-pensée, et convertit **aux deux frontières** :
`AvailabilitySlot.jourBaseDepuisIso` à l'écriture, `jourIsoDepuisBase` à la
lecture dans `fromRow`. Nulle part ailleurs.

Le défaut avait été livré. Il n'a été vu qu'en relisant
`supabase/schema_actuel.sql` **après** l'application de la migration — le
décor de `verification/` ne portait alors aucune des contraintes `check` de
la table, et laissait donc passer un 7. Les trois y sont désormais recopiées,
et `fumee.sql` écrit un dimanche. Contrôle négatif fait : avec un 7, le rejeu
échoue.

**Règle** : quand `schema_actuel.sql` révèle une contrainte `check` sur une
table qu'on écrit, la recopier dans `verification/schema_factice.sql`. Un
décor plus permissif que la vraie base ne vérifie rien.

| Fonction | Rôle |
| --- | --- |
| `mes_disponibilites` | ses propres créneaux, avec tout le détail — **aucun paramètre d'utilisateur** |
| `definir_disponibilite` | crée ou modifie un créneau, conversions d'énumération explicites |
| `supprimer_disponibilite` | renvoie un booléen : c'est lui qui dit si une ligne est partie |
| `statuts_de_disponibilite` | statut de plusieurs personnes à un instant donné |

### Les autres ne voient jamais qu'un mot parmi trois

**Disponible, Indisponible, Inconnu.** Jamais un créneau, jamais une heure,
jamais une raison. La visibilité est limitée aux contacts et aux co-membres de
groupes.

Cette règle est tenue **par la base**, pas par l'écran :
`statuts_de_disponibilite` **délègue** à `get_availability_status` au lieu de
relire `availabilities`. Réimplémenter la visibilité, ce serait se donner deux
endroits où elle peut diverger — et l'un des deux finirait par être le plus
permissif. La fonction du schéma initial reste seule juge.

Côté Dart, la distinction est portée par deux types différents, et non par un
drapeau : `AvailabilityStatus` (deux valeurs) est ce que l'on déclare pour
soi, `PeerAvailability` (trois valeurs) est tout ce qu'on peut savoir d'autrui.
Aucune conversion ne mène de l'un vers l'autre. `unknown` couvre aussi bien
« rien de déclaré » que « vous n'avez pas à le savoir » : les distinguer serait
déjà en dire trop.

`PeerAvailabilityList` ne prend que des `PeerCandidate` — un identifiant, un
nom — et sert donc aussi bien les membres d'un groupe que les contacts. Il
apparaît dans `EventFormSheet` **une fois la date et l'heure choisies** : sans
instant à interroger, la question n'a pas de réponse. Une panne de lecture y
est signalée sans bloquer la création.

L'écran de saisie s'ouvre depuis le **profil** — une disponibilité décrit la
personne, pas le fonctionnement de l'application — et porte la règle en tête,
là où l'on saisit plutôt que dans une page d'aide que personne n'ouvre.

---

## Chat de groupe

**Une seule conversation par groupe.** Ni canaux, ni fils, ni messagerie
privée — et le schéma dit la même chose que le produit : `messages` ne porte
qu'un `group_id`, sans aucune notion de destinataire.

Les trois tables **viennent du schéma initial** ; `supabase/tranche5a_chat.sql`
n'en crée aucune, il n'ajoute que six fonctions.

| Table | Colonnes | Ce que la forme impose |
| --- | --- | --- |
| `messages` | `id`, `group_id`, `sender_id`, `content`, `media_url`, `media_kind`, `created_at`, `deleted_at`, **`task_id`**, **`event_id`**, **`tache_prise`** | `CHECK (content is not null or media_url is not null)`, contenu ≤ 2000 |
| `message_reactions` | `message_id`, `user_id`, `emoji` — **PK `(message_id, user_id)`** | une réaction par personne et par message, **tenu par la base** |
| `message_reads` | `group_id`, `user_id`, `last_read_at` — **PK `(group_id, user_id)`** | l'accusé de lecture est **par conversation**, jamais par message |

`media_type` ne connaît que `image` et `video` : c'est **le type**, et non une
règle d'écran, qui interdit les documents.

### Trois conséquences qui ne se négocient pas

**1. La clé primaire de `message_reactions` porte déjà la règle.**
`reagir_message` n'a donc rien à vérifier : elle fait un `on conflict` et
bascule. Reposer le même emoji le retire.

**2. « Lu » se déduit, il n'est stocké nulle part.** Le schéma ne connaît qu'un
`last_read_at` par conversation. Un message est lu si un *autre* membre a un
`last_read_at` postérieur à son `created_at` — c'est ce que renvoie la colonne
`lu_par` de `messages_du_groupe`. Un accusé par message demanderait une table
qui n'existe pas.

**3. `messages` n'a pas de politique DELETE.** Seulement `msg_insert`,
`msg_select` et `msg_update using (sender_id = auth.uid())`. La suppression est
donc **douce**, et `supprimer_message` renvoie un booléen : une écriture sans
effet répond 200 côté PostgREST, et l'absence d'erreur ne prouve rien.

### `content` passe à la chaîne vide, pas à `null`

Piège trouvé par le test de fumée, et par lui seul. Vider `content` **et**
`media_url` viole `messages_check`, qui exige l'un ou l'autre : la suppression
échouait en `23514`. La contrainte dicte donc la forme de la suppression douce.

Le contenu part quand même — `messages_du_groupe` ne renvoie ni texte ni média
pour une ligne supprimée. **Ce n'est pas un masquage d'écran** : ce qui n'est
pas renvoyé n'est pas non plus lisible dans la réponse réseau.

### Le temps réel n'apporte qu'un signal

`postgres_changes` ne transporte que les colonnes brutes de la ligne : ni le
nom de l'expéditeur, ni l'agrégat des réactions, ni le compte de lectures, que
seule la fonction SQL sait assembler. À chaque changement, l'application
**relit** donc la fenêtre courante plutôt que d'appliquer l'événement.
Reconstituer la jointure côté client, ce serait se donner deux endroits où elle
peut diverger.

L'impression d'instantanéité vient d'ailleurs : le message que l'on envoie
s'affiche **avant** l'aller-retour, en `pending`, et la relecture le remplace.

**Une table doit être ajoutée à la publication pour émettre.** Sans
`alter publication supabase_realtime add table …`, le client s'abonne, le canal
passe à `subscribed`, et **aucun événement n'arrive jamais, sans la moindre
erreur**. La migration l'ajoute pour les trois tables, de façon idempotente.
RLS continue de s'appliquer : chacun ne reçoit que ce que `msg_select` lui
laisse voir.

### Les médias vivent dans un bucket privé

`chat-media` **existait déjà et est privé**. Vérifié par sondage plutôt que
supposé, `schema_actuel.sql` ne couvrant pas le schéma `storage` :

| Requête | Bucket présent | Bucket absent |
| --- | --- | --- |
| `GET /object/<bucket>/sonde` | `NoSuchKey` | `NoSuchBucket` |
| `GET /object/public/<bucket>/sonde` | `NoSuchBucket` s'il est **privé** | `NoSuchBucket` |

**La convention de chemin porte l'autorisation** :

```
chat-media/<group_id>/<uuid>.<ext>
```

Le premier segment est le groupe, et c'est lui que lisent les quatre
politiques de `storage.objects`. Sans cette convention, une politique devrait
retrouver le groupe dans `messages` — or l'objet est déposé **avant** que le
message existe.

`public.groupe_du_chemin` extrait ce segment et renvoie `null` sur tout ce qui
sort de la convention. C'est essentiel : **une exception levée dans une
politique fait échouer la requête entière** au lieu de refuser l'accès.

`messages.media_url` stocke **le chemin, jamais une URL**. Le bucket étant
privé, la lecture passe par une URL signée qui expire ; stocker l'URL donnerait
des liens morts en quelques heures. `signedMediaUrlProvider` la demande à la
volée, et il est `autoDispose` pour la même raison.

Les photos sont compressées à la sélection (`imageQuality`, `maxWidth`), comme
les avatars. **Les vidéos ne sont pas ré-encodées** — aucun paquet de
compression vidéo n'est dans les dépendances —, d'où une borne de poids
contrôlée *à la sélection* : échouer après trente secondes de téléversement
serait pire que refuser tout de suite.

Le workflow des migrations peut ne pas avoir le privilège de créer des
politiques sur `storage.objects`. Le fichier attrape alors
`insufficient_privilege`, **avertit fort** et laisse le reste s'appliquer : un
échec dur bloquerait toutes les migrations suivantes, alors que le défaut se
répare en collant la PARTIE 2 dans l'éditeur SQL.

### Deux compteurs qui répondent à deux questions

**Dans l'application, la pastille de l'onglet Groupes compte les
*conversations*, pas les messages.** Trois personnes qui écrivent dans le même
groupe, cela reste **1** : ce qu'annonce la pastille, c'est le nombre
d'endroits où aller, pas le volume de ce qui s'y trouve. Un « 47 » sur
l'onglet dirait quelque chose de vrai et d'inutile.

**Sur le téléphone, c'est l'inverse : une notification système par message**,
avec le nom du groupe pour s'y retrouver. La question n'est plus « où dois-je
aller ? » mais « que s'est-il passé ? ».

La carte du groupe, dans la liste, affiche le **compte réel** de ses messages
non lus : elle a la place de le dire, là où la pastille de l'onglet ne l'a
pas. C'est elle qui répond à « lequel est actif ».

`unreadConversationsProvider` dérive tout cela de `messages_non_lus()`, seule
lecture nécessaire — `message_reads.last_read_at` suffit.

**`navBadgesProvider` agrège deux sources de nature différente** : les
notifications de la boîte et les conversations non lues. Un message n'a pas de
ligne dans `notifications` — ce n'est pas une notification, il n'a rien à faire
dans une liste qu'on dépile —, et n'apparaît donc pas dans le compteur de la
cloche. **La cloche et la somme des pastilles ne coïncident donc plus** ;
c'était vrai tant que tout venait de `notifications`, la messagerie y a mis
fin. Le compromis est le bon : allumer la cloche à chaque message ferait de la
boîte un fil de discussion.

Le compteur doit bouger **sans** qu'on entre dans la conversation, sinon il
n'annonce rien. `UnreadMessagesNotifier` s'abonne donc à un canal Realtime
**global** sur `messages` : RLS ne laisse passer que les groupes dont on est
membre, ce qui évite de les énumérer et de refaire l'abonnement à chaque
adhésion.

### Le nom coiffe la série, l'avatar la termine

Dans une conversation, le nom de l'expéditeur apparaît sur le **premier**
message d'une suite, son avatar sur le **dernier** — celui du bas. Poser
l'avatar sur chaque message donnerait une colonne de visages répétés ; le
poser en haut le séparerait de la fin de la prise de parole.

**La gouttière de 28 dp reste réservée** sur les messages sans avatar : sans
cela, les bulles d'une même série se décaleraient d'une ligne à l'autre et la
suite se lirait en escalier.

Aucun avatar sur ses propres messages, qui restent à droite : on sait qui l'on
est, et la place gagnée profite au texte. Leur bulle garde 78 % de la largeur
là où celle des autres descend à 70 % — à 360 dp, garder 78 % des deux côtés
ferait déborder la ligne une fois la gouttière posée.

Le rendu passe par `AvatarImage`, comme partout ailleurs : c'est ce qui fait
qu'un avatar prédéfini, une photo ou des initiales s'affichent ici sans une
ligne de code propre au chat.

**Il n'y a pas de conversation à deux** au sens d'une messagerie privée : une
conversation appartient toujours à un groupe. Un groupe de deux membres reçoit
donc le même traitement, délibérément — une exception ferait sauter la mise en
page le jour où un troisième membre arrive, pour économiser 36 dp.

### La frappe passe par un broadcast, jamais par une table

« X est en train d'écrire » vaut deux secondes. L'écrire en base laisserait une
ligne derrière chaque frappe, pour une information périmée avant d'être lue.
D'où un `sendBroadcastMessage` sur le canal du groupe — et une **expiration
côté client** : sans elle, quelqu'un qui ferme l'application en plein mot
resterait « en train d'écrire » indéfiniment.

Le composeur annonce **une fois** au début, puis la fin après deux secondes de
silence. Émettre à chaque touche inonderait le canal.

---

## Notifications système (Web Push)

L'application est une PWA : les notifications passent par **Web Push**, pas par
un SDK natif. `supabase/tranche5c_notifications_push.sql` et
`supabase/functions/envoyer-push/` en portent la moitié serveur.

### Ce qui a dû être élargi dans le schéma

`push_tokens` venait du schéma initial avec
`CHECK (platform IN ('ios','android'))` : **`'web'` était refusé**, et tout
abonnement aurait échoué en `23514` — le défaut du dimanche de la tranche 4,
vu cette fois avant livraison. La contrainte est élargie sans rien retirer, et
deux colonnes nullables (`p256dh`, `auth_key`) accueillent les clés.
**`token` porte l'endpoint** : c'est l'adresse de destination, donc le jeton au
sens de cette table, et la clé primaire garde son sens.

### Une file, pas un appel depuis le déclencheur

Les déclencheurs empilent dans `push_outbox` ; la fonction Edge la vide.
Trois raisons, chacune suffisante :

1. une notification est un effet de bord et ne doit **jamais** faire échouer
   l'écriture qui l'a provoquée — un appel réseau dans la transaction
   violerait cette règle à la première panne ;
2. la clé VAPID privée n'a rien à faire dans la base ;
3. les rappels de la tranche 5d y déposeront aussi : un seul envoyeur.

`push_outbox` n'a **aucune politique d'insertion** : personne ne dépose dans la
file d'autrui. Sa politique SELECT ne montre que ses propres lignes — piège
rencontré au test de fumée, où compter sous le mauvais jeton donnait zéro
alors que les lignes existaient. Les vérifications de la file tournent donc
sous `postgres`.

Les préférences suivent un modèle **opt-out** : absence de ligne = activé. Un
modèle inverse aurait imposé de semer six lignes à l'inscription, pour une
application qui n'enverrait rien tant qu'on n'a pas coché.

### Titre = le contexte, corps = qui fait quoi

**Une seule règle de formulation, sans exception.** Le titre porte le **nom du
groupe** — « Personnel » à défaut —, jamais un mot de catégorie. Sur un écran
verrouillé, le titre sert à savoir de quel coin de sa vie vient la
notification ; le corps, à savoir quoi.

| Type | Titre | Corps |
| --- | --- | --- |
| `chat_message` | Famille | `Julie Martin : On fait un barbecue ?` |
| `group_invitation` | Famille | `Julie Martin vous invite dans le groupe` |
| `event_invitation` | Famille | `Julie Martin vous convie à Randonnée du lac Blanc` |
| `task_assigned` | Famille | `Julie Martin vous a confié : Réserver le restaurant` |
| `event_response` | Famille | `Randonnée du lac Blanc — Julie Martin vient` |
| `event_changed` | Famille | `Randonnée du lac Blanc déplacé au 24/08 à 19:30` |
| `reminder` (tâche) | Famille | `Rappel — Réserver le restaurant` |
| `task_response` | Famille | `Léa Marchand accepte : Réserver le restaurant` |
| `reminder` (événement) | Amis | `Rappel — Randonnée du lac Blanc à 09:00` |

Trois conventions cohabitaient avant : le nom du groupe pour les messages, le
titre de l'événement pour les réponses et les changements de date, un mot de
catégorie — « Invitation », « Nouvelle tâche », « Rappel » — pour le reste.
L'empilement se lisait mal et ne se triait pas d'un coup d'œil.

**Conséquence à tenir pour tout nouveau type** : le corps doit **nommer
l'élément**, puisque le titre ne le fait plus. Le test de fumée éprouve les
deux moitiés de la règle sur `event_invitation` — le titre vaut le nom du
groupe, le corps contient celui de l'événement.

`public.nom_affiche(uuid)` écrit le nom d'une personne **au même endroit pour
tous** : le même `coalesce(prénom nom, pseudo)` était recopié dans chaque
déclencheur. Elle renvoie `null` quand le profil manque, à charge de
l'appelant d'écrire « Quelqu'un » ou de reformuler sans sujet — `task_assigned`
bascule ainsi sur « Nouvelle tâche : … » quand l'assigneur n'est pas
identifiable.

### Convier quelqu'un à un événement notifie — depuis peu

Ce cas **n'envoyait rien**, et c'était un trou, pas un choix. Deux raisons
cumulées, qu'il faut connaître avant d'ajouter un type :

- `push_invitation` écarte tout ce qui n'est pas `type = 'group'` ;
- convier quelqu'un passe par une insertion dans `event_participants`, table
  qui n'avait de déclencheur que sur `update`. On était donc prévenu qu'un
  autre avait répondu, mais jamais qu'on était invité.

`push_invitation_evenement` comble l'écart. Un événement de groupe conviant
par défaut tous ses membres actifs, une création dans un groupe de huit envoie
sept notifications : c'est voulu.

Le type porte le **même nom que dans la table `notifications`**
(`event_invitation`), où il existait déjà depuis la tranche 3b. Les deux
mécanismes restent distincts — la boîte se dépile, la notification système
s'affiche — mais les nommer pareil évite d'avoir à traduire.

### Deux services worker, deux portées

`web/jelvo_push_sw.js` est **distinct** de celui que Flutter génère. Deux
enregistrements ne peuvent pas partager une portée, et le fichier de Flutter
est régénéré à chaque compilation : y ajouter du code le ferait disparaître au
build suivant. Le nôtre s'enregistre sur `push/`. Un abonnement appartient à
l'enregistrement et non à la page, donc une portée étroite ne gêne rien.

Le clic sur une notification compose une URL **avec `#`** : l'application
n'appelle pas `usePathUrlStrategy()`, et un lien sans fragment servirait
`404.html` en perdant la destination — même piège que `AppConfig.inviteUrl`.

### `dart:js_interop`, sans nouvelle dépendance

`push_service_web.dart` déclare son interopérabilité à la main plutôt que de
tirer `package:web`. Import conditionnel : sur la machine virtuelle et sur les
cibles natives, c'est `push_service_stub.dart` qui répond `nonSupporte`. Aucun
`kIsWeb` disséminé, et rien de JS ne remonte jusqu'aux écrans.

### Les limites d'iOS ne sont pas des défauts à corriger

Elles sont dans le produit, et l'écran de réglages les dit :

- **Web Push n'existe que dans l'application ajoutée à l'écran d'accueil.**
  Dans un onglet Safari, `PushManager` est absent. D'où l'état
  `installationRequise`, distinct de `nonSupporte`.
- **Aucun bouton d'installation n'est possible** : iOS n'implémente pas
  `beforeinstallprompt`. La consigne écrite est tout ce qui reste.
- **L'application installée a son propre stockage** : il faut s'y reconnecter.
- **Retirer l'icône détruit l'abonnement**, sans prévenir personne. D'où le
  réenregistrement à chaque ouverture de session
  (`pushRegistrationProvider`), et la purge sur `404`/`410` côté fonction Edge.
- **Un refus est définitif** côté application : l'API ne permet plus de
  redemander. L'écran renvoie donc aux réglages du navigateur plutôt que de
  proposer un bouton qui ne ferait rien.
- **Pas de push silencieux** : `userVisibleOnly` est obligatoire, et le service
  worker affiche toujours quelque chose — sinon l'abonnement est révoqué après
  quelques récidives. D'où le repli « Jelvo / Vous avez du nouveau ».

### Rien n'envoie sans ces secrets

| Où | Quoi |
| --- | --- |
| `env` de `deploy-web.yml` | `VAPID_PUBLIC_KEY` |
| Dashboard Supabase → Edge Functions → Secrets | **`VAPID_PUBLIC_KEY`**, `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT` |
| Secrets GitHub | `SUPABASE_ACCESS_TOKEN`, `SUPABASE_PROJECT_REF` |

**`VAPID_PUBLIC_KEY` figure deux fois, et ce n'est pas une redondance.** Le
`--dart-define` du workflow ne fournit la clé qu'au **bundle Flutter**, pour
que le navigateur puisse s'abonner. La fonction Edge tourne sur un tout autre
serveur, ne voit rien du dépôt, et lit ses propres secrets : sans la clé de
son côté, `setVapidDetails` refuse la paire — la publique entre dans l'en-tête
`Crypto-Key` de chaque envoi.

L'omission a coûté une mise en service : la fonction sortait en `500` dès la
première ligne, une fois par minute, **sans rien journaliser**.

La paire est un couple ECDSA **P-256**, encodé en base64url **sans
remplissage** : la publique est le point non compressé de 65 octets (87
caractères, commençant par `B`), la privée le scalaire de 32 octets (43
caractères). `npx web-push generate-vapid-keys` les produit, `openssl
ecparam -name prime256v1` aussi.

**La publique a sa place dans le dépôt**, comme la clé « publishable » : le
navigateur en a besoin pour s'abonner, elle part donc dans le bundle web de
toute façon. La **privée** ne doit jamais y entrer — le dépôt est public, et
elle vit dans les secrets de la fonction Edge, qui ne quittent pas le serveur.

Tant que `VAPID_PUBLIC_KEY` est vide, `_apiDisponible` est faux et l'écran
annonce que les notifications ne sont pas disponibles, plutôt que d'offrir un
bouton qui échouerait. `fonctions-supabase.yml` s'arrête de même, avec un
avertissement nommant les secrets manquants, plutôt que de déployer une
fonction incapable d'envoyer.

**Rien ne peut être planifié avant que la fonction soit déployée** : l'ordre
est donc secrets GitHub → déploiement → secrets de la fonction → planification.

### Une base ne se réveille pas toute seule

**La tranche 5c a livré une file que rien ne vidait.** `push_outbox` se
remplissait à chaque message, chaque invitation, chaque assignation — et
`envoyer-push` n'était appelée par personne. Aucune erreur nulle part : la
file grossissait, en silence. C'est le même genre de panne que la publication
`supabase_realtime` manquante, et elle se diagnostique aussi mal.

La tranche 5d ferme cet écart, et **il n'y a qu'une seule chose à planifier** :

```
Tableau de bord Supabase → Integrations → Cron → Edge Function
envoyer-push,  * * * * *
```

La fonction appelle `empiler_rappels()` **puis** vide la file, dans le même
passage. Deux planifications distinctes — l'une pour les rappels, l'autre pour
l'envoi — auraient donné deux cadences à tenir d'accord, et un rappel empilé
juste après le dernier envoi aurait attendu le tour suivant.

#### Un passage doit tenir dans le délai de la planification

L'interface Cron **plafonne le délai d'attente à 5000 ms**. Un passage qui
déborde est compté en échec chaque minute — et détruit le seul signal qui
disait si la chaîne fonctionne.

Trois choses pouvaient déborder, et réduire le lot n'en réglait qu'une :

| Cause | Borne posée |
| --- | --- |
| démarrage à froid (`web-push` s'importe en 1 à 3 s) | la réponse part **avant** le travail |
| un endpoint qui pend — `allSettled` attend le plus lent | `DELAI_ENVOI_MS`, 3 s par envoi |
| le volume | `LOT`, 20 lignes par passage |

**La deuxième est la seule qui comptait vraiment** : `sendNotification`
n'impose aucun délai maximal, si bien qu'un unique endpoint lent retenait le
lot entier — un lot de taille 1 y aurait suffi. Diminuer `LOT` n'y pouvait
rien.

La réponse est donc un simple accusé de réception (`202`), et le travail se
poursuit derrière elle via `EdgeRuntime.waitUntil` — sans quoi l'instance
serait susceptible d'être arrêtée dès la déconnexion de l'appelant, c'est-à-dire
aussitôt.

**Conséquence à connaître : l'historique de la planification ne dit plus que
« appelée ».** Ce qu'a fait un passage — rappels empilés, envois, échecs,
purges, durée — se lit dans les **journaux de la fonction**, et les échecs
individuels dans `push_outbox.last_error`. C'est le même compromis que pour le
workflow des migrations : le vert de la tâche ne désigne pas l'étape qui
compte.

Rien ne se perd au passage : la file est ordonnée par `created_at`, un envoi
non traité garde `sent_at is null`, et `attempts < 3` finit par abandonner ce
qui échoue systématiquement.

L'alternative, `pg_cron` + `pg_net` appelant la fonction depuis la base, a été
écartée pour une raison précise : elle impose de ranger une clé `service_role`
**dans la base**. La clé vit déjà du bon côté, dans les secrets de la fonction.

**C'est le second prérequis manuel du projet**, avec le modèle d'e-mail à
`{{ .Token }}`. Tant qu'il n'est pas posé, les rappels ne sont pas « en
retard » : ils ne sont pas empilés du tout, et aucune notification ne part.

---

## Rappels

`tasks.reminder_at` — un instant — et `events.reminder_minutes` — un délai
avant le début — étaient enregistrés depuis la tranche 3 sans que rien ne les
lise. `supabase/tranche5d_rappels.sql` les lit.

| Fonction / table | Rôle |
| --- | --- |
| `prochaine_occurrence` | prochaine occurrence d'une `rrule`, ou `null` |
| `empiler_rappels` | dépose dans `push_outbox` les rappels dus |
| `push_reminders_sent` | ce qui a déjà été rappelé — clé primaire à quatre colonnes |

### La mémoire est une clé primaire, pas un contrôle

Le battement passe toutes les minutes, mais `empiler_rappels` regarde **dix
minutes en arrière** : un battement manqué — un redéploiement, une minute
sautée — ne doit pas faire disparaître un rappel. La contrepartie, c'est que
le même rappel entre dans la fenêtre dix fois de suite.

Ce qui l'écarte est la clé primaire de `push_reminders_sent` —
`(kind, source_id, occurrence, user_id)` — et un `on conflict do nothing` dont
on lit le `found`. Pas un test préalable, qui se doublerait d'une course. Même
raison que pour `message_reactions`.

`occurrence` est dans la clé, et pas seulement `source_id` : un élément
récurrent doit être rappelé à **chacune** de ses occurrences.

Le contrôle négatif a été fait : en retirant le `continue when not found`, le
test de fumée échoue sur « un second passage a renvoyé le même rappel ».

### Une `rrule` inconnue ne se devine pas

L'application n'écrit que cinq règles (`RecurrenceRule`) : `FREQ=DAILY`,
`FREQ=WEEKLY`, `FREQ=WEEKLY;INTERVAL=2`, `FREQ=MONTHLY`, `FREQ=YEARLY`.
`prochaine_occurrence` ne connaît que celles-là et renvoie **`null` sur toute
autre** — l'élément n'est alors pas rappelé. Interpréter au jugé une règle
portant `COUNT`, `UNTIL` ou `BYDAY` donnerait des rappels à des heures
fausses, ce qui est pire qu'un rappel manquant.

Les occurrences sont calculées **depuis la base**, jamais de proche en
proche : un mensuel posé le 31 janvier tombe le 28 février puis **le 31 mars**,
et non le 28 mars. Les deux cas sont dans le test de fumée.

### L'avance est reportée, l'occurrence est recherchée en conséquence

Un rappel n'est pas « l'occurrence suivante moins l'avance » : c'est
l'occurrence dont le rappel tombe **maintenant**. La recherche part donc de
`fenêtre + avance`, sans quoi un quotidien à 9 h rappelé une heure avant ne
serait jamais trouvé — à 8 h, l'occurrence suivante est encore celle du jour,
et son rappel est déjà passé.

Pour une tâche, l'avance est `due_at - reminder_at` de la première
occurrence, reportée telle quelle sur les suivantes.

### Qui est rappelé

| Élément | Destinataires |
| --- | --- |
| tâche avec assignés | les assignés, sauf `declined` |
| tâche sans assigné | celui qui l'a créée |
| événement avec participants | ceux qui n'ont pas répondu `no` |
| rendez-vous personnel | son propriétaire |

L'heure affichée dans le corps de la notification est rendue en
**Europe/Paris** : l'application n'a qu'une locale, et le schéma ne porte
aucun fuseau par événement. Il n'y a rien de plus juste à faire ici.

Les tâches terminées et les éléments supprimés sont écartés — `completed_at`
reste la seule source du statut.

---

## Calendrier personnel et semaine d'accueil

### L'en-tête porte quatre choses, et deux n'existaient pas

Photo de profil, titre, **recherche**, **filtres**, et le « + ». Les deux du
milieu sont nouvelles.

**La recherche** cherche par titre dans les événements et les tâches datées —
tout l'agenda, pas le seul jour affiché : c'est justement quand on ne sait
plus *quand* a lieu quelque chose qu'on cherche. Toucher un résultat ouvre le
calendrier à sa date. Rien de nouveau n'est lu : `mon_agenda` et `mes_taches`
sont déjà chargées sans bornes de dates.

**Les filtres** ne créent pas de mécanisme : le filtre par groupe existait,
en rangée de puces sous la bande des jours. Il passe derrière l'icône, et
gagne le seul réglage d'affichage qui manquait — montrer ou non les créneaux.
Les créneaux restent **hors** du filtre par groupe : ils ne dépendent d'aucun
groupe, et les y mêler ferait disparaître le fond de la journée dès qu'on
choisit un groupe. Une pastille sur l'icône dit qu'un filtre est posé, sans
quoi une journée vide se lirait comme une journée sans rien.

### Le code couleur est celui du design system, pas un nouveau

Vert, rouge, violet de la maquette tombent exactement sur trois jetons
existants : `success`, `danger`, `primary`. Aucune couleur n'a été ajoutée.

| Couleur | Jeton | Ce qu'elle dit |
| --- | --- | --- |
| vert | `success` | créneau déclaré disponible, et tâche |
| rouge | `danger` | créneau déclaré **indisponible** |
| violet | `primary` | événement — ou l'accent du groupe, quand il en a un |

Deux nuances à connaître. `danger` sert ailleurs aux actions destructives ;
ici il ne dit pas « attention », il dit « occupé » — c'est le même mot que
`AvailabilityStatus.unavailable`, et la cohérence est celle de la donnée.
Et un événement de groupe prend **l'accent de son groupe** plutôt que le
violet générique : c'est déjà ce que fait le reste de l'application, et le
perdre ferait ressembler tous les groupes entre eux.

### Les trois chiffres de la maquette sortent tous des données

| Chiffre | D'où il vient |
| --- | --- |
| temps disponible | `availableMinutesForDayProvider`, somme des créneaux `available` du jour, exceptions appliquées |
| invitations en attente | invitations de groupe `pending` + événements et tâches sans réponse |
| pastilles sous les dates | `weekMarkersProvider` : un événement, une tâche datée, une indisponibilité déclarée |

Aucun n'est approché. Les pastilles sont calculées **pour la seule semaine
affichée** — sept lectures de `slotsForDayProvider`, et non une par jour de
l'année.

**Trois pastilles au plus, et jamais de chiffre** : à cette taille, un « 3 »
et un « 8 » ne se distinguent pas d'un coup d'œil, alors qu'une pastille
présente ou absente, si.

### Une journée vide, une journée chargée

La journée vide distingue **deux causes** : rien ce jour-là, ou un filtre qui
cache. L'action proposée diffère en conséquence — créer, ou tout revoir.
Confondre les deux enverrait créer un événement là où il en existe peut-être
déjà un, masqué.

La journée chargée passe par `DayTimeline.enSlivers` : une journée de
calendrier n'a pas de borne, et une `Column` bâtirait toutes ses lignes d'un
coup. La carte de l'accueil, elle, tient en trois lignes et garde la
`Column` — le squelette reste partagé, seule la façon de le poser change.

### Le calendrier n'a pas de contenu propre

Il **agrège** quatre sources : événements de tous les groupes, rendez-vous
personnels, tâches datées et créneaux de disponibilité. `dayAgendaProvider` les
réduit à un type commun, `AgendaEntry`, ce qui est la seule façon de les
**trier ensemble par heure** — une liste par source ne le permettrait pas.

L'agrégation vit dans le provider et non dans l'écran, parce que les quatre
compteurs d'en-tête lisent la même chose : deux agrégations parallèles
finiraient par afficher un nombre que la liste dessous contredit.

| Compteur | Source |
| --- | --- |
| Événements | lignes de type événement du jour affiché |
| Tâches | tâches datées du jour affiché |
| Disponible | `availableMinutesForDayProvider`, en « 4 h 30 » |
| Invitations | invitations de groupe + événements et tâches sans réponse |

Un rendez-vous personnel n'a pas à être filtré côté application : `mon_agenda`
ne le renvoie qu'à son propriétaire.

**Le filtre par groupe compte vide pour « tout »**, et non pour « rien » :
c'est l'état d'ouverture, et un calendrier vide par défaut n'aurait aucun sens.
`CalendarGroupFilter.personal` est la clé des éléments sans groupe, qui n'ont
pas d'identifiant à donner. Les créneaux de disponibilité **échappent au
filtre** : ils décrivent le fond de la journée, pas un groupe, et les masquer
en filtrant ferait disparaître ce fond.

`DayTimeline` rend le tout : gouttière d'heures, rail continu, une carte par
élément — et une bande discrète, sans carte ni ombre, pour les créneaux, qui
ne sont pas des choses qui arrivent mais des choses qui se peuvent.

### L'accueil suit une maquette, et s'arrête où les données s'arrêtent

Quatre blocs, dans cet ordre : **en-tête**, **bande des groupes**, **carte
Mon agenda**, **carte Mes tâches**. L'ordre descend du « où suis-je » vers le
« qu'ai-je à faire ».

**Trois éléments de la maquette n'ont pas été repris, faute de données** — et
c'est une règle, pas un renoncement ponctuel : *un écran ne montre que ce que
la base sait*.

| Écarté | Pourquoi |
| --- | --- |
| pastille de présence sur la photo | `profiles.last_seen_at` existe mais **n'est écrit nulle part**. Une pastille verte permanente serait un mensonge |
| avatars des participants sur une ligne d'agenda | `mon_agenda` les renvoie, mais à cette largeur ils poussent l'heure hors du cadre. Ils restent sur l'écran de détail |
| icônes de catégorie sur les cartes de groupe | `groups` ne porte ni thème ni pictogramme. Les déduire du nom serait une devinette |
| l'emoji 👋 du titre | règle antérieure : sans police emoji, le glyphe manque et s'affiche en carré « tofu » |

**Le repli d'une carte de groupe sans photo est l'initiale du nom**, sur
l'accent dérivé de l'identifiant — la même couleur que partout ailleurs pour
ce groupe. Une URL morte y retombe aussi : `errorBuilder` et `loadingBuilder`
renvoient le même repli, pour qu'un lien expiré ne laisse pas un rectangle
gris.

**La carte « Mon agenda » montre la journée complète** — événements et tâches
datées mêlés dans l'ordre des heures. C'est le but premier de la carte : voir
sa journée d'un coup d'œil, sans distinguer ce qui arrive de ce qu'on a à
faire. Une chronologie qui tairait les tâches ne la montrerait qu'à moitié.

**Les créneaux de disponibilité en sont écartés** (`todayAgendaProvider`) : ils
décrivent ce qui se peut et non ce qui arrive, et rempliraient une carte qui
doit tenir en trois lignes. Ils restent au calendrier, où la journée se lit en
entier.

**La ligne en double est retirée, pas la répétition.** Une tâche du jour figure
dans la chronologie *et* dans les compteurs — c'est voulu, « en retard »
continue de la compter. Mais elle n'est pas répétée dans la **liste** du bas, à
quelques centimètres de la première : `homeTaskRowsProvider` retire de
`focusTasksProvider` les identifiants que la chronologie porte déjà. Le filtre
passe par l'identifiant, jamais par le titre — deux groupes peuvent avoir une
tâche du même nom.

Deux conséquences à connaître :

- **une liste vide ne veut pas dire la même chose selon le compteur.** Sans
  tâche ouverte, « Tout est à jour » ; avec des tâches toutes remontées dans
  la chronologie, « Déjà dans votre agenda ». Dire « tout est à jour » dans le
  second cas serait un mensonge à quelques centimètres de la preuve du
  contraire ;
- **une tâche remontée dans la chronologie perd sa case à cocher** sur
  l'accueil : `DayTimeline` n'en porte pas, et lui en ajouter changerait aussi
  le calendrier. Elle se coche depuis son écran de détail, à une touche, ou
  depuis `/taches`.

**`DayTimeline` est la même** qu'au calendrier, avec un drapeau
`dansUneCarte` : lignes teintées sans ombre au lieu de cartes blanches, et la
plage horaire à droite. Deux chronologies séparées auraient fini par diverger.

**Les trois compteurs de tâches ne sont pas disjoints** : « en retard » est un
sous-ensemble d'« à faire ». Les soustraire donnerait un « à faire » qui ne
correspond à aucune liste consultable.

### La semaine sur l'accueil

`WeekOverview`, posé **sous l'en-tête**, montre les sept jours de la semaine en
cours : initiale, quantième, jour courant plein, et deux marqueurs par jour —
violet pour les événements, vert pour les tâches. Toucher un jour règle
`selectedDayProvider` puis ouvre le calendrier à cette date.

Elle **ne figure pas sur la maquette** et a été gardée : c'est le seul endroit
d'où l'on ouvre le calendrier à une date précise.

Les marqueurs sont des pastilles et non des chiffres : à cette taille, un « 3 »
et un « 8 » ne se distinguent pas d'un coup d'œil, alors qu'une pastille
présente ou absente, si. Le compte exact est à une touche. Il est en revanche
porté par l'étiquette `Semantics`, qu'une pastille ne dit pas à un lecteur
d'écran.

La hauteur des marqueurs est **réservée en permanence** : sans cela, les
colonnes chargées et les colonnes vides n'auraient pas la même hauteur et la
ligne des quantièmes danserait.

---

## Écran « Mon profil »

Trois cartes, dans l'ordre de la maquette : **identité**, **À propos**,
**Mes statistiques**.

### Il ne s'écrit plus là où il se lit — sauf la bio

L'écran était un formulaire ; il ne l'est plus. `ProfileEditScreen`
(`/profil/modifier`) porte **prénom et nom** ; l'écran de profil se lit d'un
coup d'œil. Un profil se consulte bien plus souvent qu'il ne se change, et un
bouton « Enregistrer » permanent laissait croire qu'il fallait valider pour
partir.

L'enregistrement **referme** la feuille sur le profil : rester sur le
formulaire ferait douter de l'effet.

### La bio se modifie sur place

Un appui sur la ligne la transforme en champ, déjà rempli et déjà actif : le
clavier s'ouvre sans second geste. C'est le champ qu'on retouche le plus
souvent, et le seul dont la valeur tient sur la ligne où elle se lit.

**Tout sort par la perte du focus.** Appui ailleurs (`onTapOutside`), touche
de validation, retour du clavier sur Android, coche de la ligne : les quatre
chemins finissent au même endroit, et un seul écrit. Le texte vit dans le
contrôleur, donc **rien n'est perdu**, même quand l'écriture échoue.

Trois règles que le code porte :

- **un échec reste en édition**, avec le texte et le message. Refermer ferait
  disparaître la saisie en même temps que le message, et laisserait croire que
  la bio est enregistrée ;
- **un texte intact n'écrit pas.** Perdre le focus sans avoir rien changé ne
  doit pas envoyer de requête, d'où `_valeurInitiale` ;
- **le profil se relit après chaque écriture** : `didUpdateWidget` n'accepte la
  valeur du serveur que hors édition, sans quoi elle écraserait une saisie en
  cours.

**Plus de chevron sur cette ligne** : il annonçait un écran qui s'ouvre. Un
crayon dit « on écrit ici », et cède la place à une coche en saisie — un moyen
explicite de valider, sans dépendre du clavier.

`saveBio` et `saveNames` relisent chacune ce qu'elles ne touchent pas. Depuis
que les deux moitiés se modifient à des endroits différents, l'écriture
partielle est la règle, et la faire dans les actions plutôt que dans l'écran
rend l'oubli impossible.

### Le bouton d'appareil photo ouvre les deux voies

La pastille posée sur l'avatar ouvre `AvatarChoiceSheet` : photo de l'appareil,
avatar Jelvo, et retrait quand il y a quelque chose à retirer. **Les avatars
prédéfinis y sont de même rang que la photo** — les cacher derrière un second
bouton en aurait fait une option de repli.

`AvatarPicker.choisirPhoto()` est le point unique de sélection : l'inscription
et le profil ouvrent la **même** boîte, avec les mêmes bornes de taille et la
même compression. Deux appels à `ImagePicker` auraient fini par diverger, et
c'est le poids envoyé au bucket qui en aurait pâti.

### Ce que la maquette proposait et qui n'existe pas

| Écarté | Pourquoi |
| --- | --- |
| badge « En ligne » | `profiles.last_seen_at` n'est écrit nulle part |
| ligne Téléphone | Jelvo ne collecte pas de numéro |
| ligne Localisation | ni de localisation |

Les afficher vides aurait suggéré qu'il manque quelque chose à remplir.

**L'e-mail n'a pas de chevron**, contrairement aux autres lignes : il vient de
la session, et le changer relèverait d'un parcours d'authentification que
l'application n'a pas. Un chevron qui n'ouvre rien est pire qu'une ligne
inerte.

### Les trois statistiques, et la nuance du troisième

| Compteur | Source |
| --- | --- |
| Groupes | `activeGroupsProvider.length` — exact |
| Événements | `eventsProvider`, soit `mon_agenda` **sans bornes de dates** : rien n'est tronqué |
| Tâches terminées | tâches visibles dont `completed_at` est renseigné |

Le troisième porte un libellé plus prudent que la maquette : **« Tâches
terminées » et non « réalisées »**. `tasks` ne connaît que `completed_at`,
jamais qui a coché — attribuer l'action à quelqu'un serait inventer ce que la
base ne sait pas. Le jour où une colonne `completed_by` existerait, le libellé
pourrait changer.

Chaque compteur **ouvre la liste qu'il résume** : un chiffre qu'on ne peut pas
ouvrir n'apprend rien de plus que lui-même.

### Le QR code existait déjà

`MyQrCodeScreen` et `QrContact` datent de la feature contacts : le code
n'encode que le **pseudo**, ni adresse e-mail ni agenda. La refonte ne fait
que le remonter au premier rang des actions, là où on le cherche quand on est
en face de quelqu'un.

« Partager profil » partage **exactement la même chose** que le QR code. Jelvo
n'a pas d'adresse publique de profil, et inventer un lien qui n'ouvrirait rien
serait pire que de partager le pseudo, avec lequel on se retrouve par la
recherche.

---

## Écran « Mes contacts »

Quatre blocs : **en-tête**, **bande des favoris**, **carnet rangé par
lettre**, et le rail alphabétique posé le long du bord droit. Le « + » de
l'en-tête ouvre la feuille des trois moyens d'ajouter quelqu'un.

### Les groupes en commun se comptent, ils ne se devinent pas

C'est la seule donnée de la maquette qui n'était pas déjà lisible, et elle
**l'est proprement** : `mes_contacts` croise `group_members` avec lui-même.
Trois filtres, aucun décoratif — le groupe doit être vivant, et **les deux**
adhésions actives. Une adhésion temporaire échue ne compte plus, d'un côté
comme de l'autre : c'est la règle de la tranche 6, et le carnet ne fait pas
exception. Les deux contrôles négatifs sont dans le test de fumée.

Le compte reste côté SQL parce que lire l'adhésion d'autrui ligne à ligne
n'est pas donné par RLS — c'est exactement pourquoi ces lectures passent par
une fonction `security definer`.

**Zéro se dit aussi.** « 0 groupe » est une information — on se connaît sans
rien organiser ensemble —, là où une pastille absente se lirait comme une
donnée manquante.

### La bande des favoris n'invente aucun mécanisme

Le favori existait déjà : personnel, posé d'une étoile sur la ligne du
contact, et **l'étoile n'a pas bougé**. La bande ne fait que remonter en tête
ceux qu'on a marqués.

Elle se met à jour **immédiatement** parce qu'elle dérive du même provider que
la liste : `favoriteContactsProvider` filtre `acceptedContactsProvider`, que
`toggleFavorite` rafraîchit. Aucun état parallèle à tenir d'accord.

**Sans favori, la bande reste et invite** — mais seulement s'il y a des
contacts à épingler. Sur un carnet vide, elle disparaît : ce serait la
deuxième invitation d'affilée sur un écran qui n'a encore rien. Elle
disparaît aussi pendant une recherche, où elle répondrait à une autre
question que celle qu'on pose.

**« Gérer » ouvre une feuille où tout le carnet porte son interrupteur.**
C'est ce qui manquait : sur la liste, l'étoile est à côté de chaque nom, mais
il faut la chercher ligne à ligne. Ici on épingle et on désépingle à la
chaîne, et la bande suit à chaque touche.

### Le rail saute par ancre, pas par calcul d'offset

`Scrollable.ensureVisible` sur la clé de l'en-tête visé. Cela suppose que les
en-têtes soient **construits**, donc une liste non paresseuse — c'est le prix,
assumé, d'un saut exact. Un carnet personnel tient dans quelques dizaines de
lignes ; le jour où il en compterait des milliers, il faudrait revenir à un
calcul d'offset, plus rapide et plus fragile.

Le rail ne montre **que les lettres présentes** : une cible qui ne mène nulle
part est pire qu'une lettre absente. Il se glisse autant qu'il se touche, et
disparaît sous deux sections — il n'y aurait rien à sauter.

La découpe par lettre vit dans `contactSectionsProvider` et non dans l'écran :
le rail et la liste doivent lire **la même**, faute de quoi une lettre du rail
pourrait ne correspondre à aucune section. `#` recueille tout ce qui ne
commence pas par une lettre.

### Le chevron mène quelque part

`ContactActionsSheet` : épingler, et **retirer de ses contacts** — une
capacité qui existait en base sans être atteignable nulle part dans
l'application. Un chevron qui n'ouvre rien est pire qu'une ligne inerte, et
c'est ce qu'il aurait été sans cette feuille.

Le « + » central de la barre ouvre **la même** feuille d'ajout que celui de
l'en-tête : « comment j'ajoute quelqu'un ? » n'a qu'une réponse.

### Ce que la maquette montrait et qui n'existe pas

| Écarté | Pourquoi |
| --- | --- |
| pastilles En ligne / Absent / Hors ligne | `profiles.last_seen_at` n'est écrit nulle part — même règle que l'accueil et le profil |
| libellés sous les prénoms des favoris | ils ne disaient que la présence |

---

## Internationalisation

Les textes vivent dans `lib/l10n/app_fr.arb` et sont exposés par la classe
générée `AppTexts` (`l10n.yaml`). `main()` branche
`AppTexts.localizationsDelegates` et `AppTexts.supportedLocales`.

Les délégués de Material et de Cupertino ne sont pas décoratifs : sans eux, un
`showDatePicker(locale: Locale('fr'))` reste en anglais quand il ne lève pas.

**Ajouter une langue = déposer `app_<code>.arb` à côté et le remplir.** Aucun
code à modifier. La migration des chaînes est **partielle** : voir les limites
connues.

---

## Notifications et pastilles

La table `notifications` — `id`, `user_id`, `type`, `payload`, `read_at`,
`created_at` — porte deux politiques : lecture et mise à jour de ses propres
lignes. **Il n'y a volontairement aucune politique d'insertion** : personne ne
doit pouvoir écrire dans la boîte de quelqu'un d'autre. L'alimentation passe
donc par des déclencheurs `security definer`, livrés dans
`supabase/notifications.sql`.

| Déclencheur | Effet |
| --- | --- |
| `after insert on invitations` | notification `group_invitation` pour l'invité |
| `after insert on contacts` | notification `contact_request` pour le destinataire |
| `after update on invitations` | referme la notification dès que l'invitation quitte `pending` |
| `after update on contacts` (accepté) | referme la notification de demande |
| `after delete on contacts` | referme la notification d'une demande refusée |

Trois autres vivent ailleurs, sur le même modèle : `after insert` et `after
update on event_participants` (tranche 3b, `event_invitation`), et les trois de
la tranche 8 sur `task_assignees` — dépôt d'un `task_assigned`, clôture à la
réponse, et clôture au **retrait** de l'assigné, `definir_assignes_tache`
supprimant la ligne au lieu de la modifier. Une quatrième y remonte la réponse
à qui a confié la tâche (`task_response`).

Les clôtures ne sont pas du confort : sans elles, une invitation acceptée
laisserait sa pastille allumée indéfiniment. **Un compteur doit refléter ce qui
reste à faire, pas ce qui est arrivé un jour.**

**Une notification est un effet de bord, elle ne doit jamais faire échouer
l'écriture principale.** Tous ces déclencheurs attrapent donc toute erreur, la
consignent en `warning` et laissent passer. Une invitation impossible à envoyer
parce que la notification a été refusée est un défaut bien plus grave qu'un
compteur qui ne s'allume pas. Tout nouveau déclencheur sur ces tables doit
suivre la même règle.

`type` est du **texte libre** côté base, pas un type énuméré :
`NotificationType.fromDb` fait donc tomber tout type inconnu dans `autre`
plutôt que de lever.

Le `payload` porte de quoi afficher la ligne — nom du groupe, nom de
l'émetteur, avatar, identifiants — pour que l'écran ne fasse qu'**une seule
lecture**, sans jointure ni requête de complément.

### Une action qui referme une notification doit relire la boîte

Les déclencheurs ci-dessus referment des notifications **côté base**, sans que
l'application en soit avertie : elle ne les relit qu'à la demande. Toute action
cliente qui déclenche une de ces fermetures doit donc rafraîchir
`notificationsProvider` — sinon la ligne reste à l'écran et la pastille
allumée, alors que la base est à jour.

C'est le cas d'`EventActions.respond` : répondre à un événement déclenche
`clore_notification_evenement`. Le défaut s'était vu à l'usage — la
notification survivait à la réponse.

La boîte est en outre relue **à chaque ouverture** de `NotificationsScreen` :
`notificationsProvider` n'est pas `autoDispose` et garde son état d'une visite
à l'autre, si bien qu'une invitation acceptée ailleurs y serait restée
indéfiniment.

### Répartition des pastilles

`NotificationType.navIndex` associe chaque type à **un seul** onglet :
`group_invitation` → Groupes, `contact_request` → Contacts,
`event_invitation` → Calendrier, `task_assigned` et `task_response` →
Accueil, comme le reste : les tâches n'ont pas d'onglet, et c'est de l'accueil
que leur liste s'ouvre.
Un élément n'est donc jamais compté deux fois, et le total de la cloche reste
exactement la somme des pastilles. Ajouter un type impose de lui choisir un
onglet — c'est voulu.

`unreadByTabProvider` renvoie les quatre compteurs dans l'ordre de
`AppBottomNav.destinations`. C'est `navBadgesProvider` qui y ajoute les
conversations non lues de la messagerie et que lit `AppShell` — voir « Deux
compteurs qui répondent à deux questions ». `NavBadge` ne peint rien quand le
compteur vaut zéro.

---

## Sécurité — ce que la tranche 7 a fermé

`supabase/tranche7_durcissement.sql`. Revue avant ouverture à de vrais
utilisateurs, menée sur `schema_actuel.sql` — le schéma **réel** — et non sur
ce que les fichiers de migration croient avoir posé.

### Le principe : six tables, et pas une de plus

L'application n'écrit directement que dans **`profiles`, `contacts`,
`notifications`, `groups`, `group_invite_links`**, et lit `group_members`.
Tout le reste passe par des fonctions `security definer`.

Relevé en recensant les `.from('…')` de `lib/` : c'est le seul point d'entrée
PostgREST vers une table. Les politiques d'écriture des quinze autres tables
n'avaient donc **aucun usage légitime** — chacune était une porte qu'aucun
code n'empruntait.

Elles sont retirées, et le privilège avec : `revoke insert, update, delete…`.
Le privilège est la vraie barrière, contrôlée avant même que RLS n'entre en
jeu.

**Une fonction `security definer` appartenant à `postgres` contourne RLS**,
puisque `postgres` possède les tables. Retirer ces politiques ne gêne donc
aucune écriture légitime — c'est déjà ce qui faisait marcher
`definir_assignes_tache`, qui supprime dans `task_assignees` alors qu'aucune
politique DELETE n'y a jamais existé.

**Règle pour la suite** : une nouvelle table écrite par une fonction ne reçoit
pas de politique d'écriture, et son privilège d'écriture est retiré à `anon`
et `authenticated`.

### Les quatre trous, du plus large au plus étroit

**1. `EXECUTE` est accordé à `PUBLIC` par défaut.** C'est le plus large, et le
plus contre-intuitif : un `grant execute … to service_role` *ajoute* un droit,
il n'en retire aucun. Les fonctions réservées au rôle de service étaient donc
appelables par n'importe quel porteur de la clé publiable, que PostgREST
expose toutes. En particulier `push_a_envoyer`, qui renvoie les **endpoints et
les clés Web Push** des notifications en attente de tout le monde — de quoi
leur écrire directement — et `empiler_push`, qui dépose une notification
arbitraire dans la boîte de n'importe qui.

Le fichier retire `EXECUTE` sur **toutes** les fonctions de `public`, puis
rouvre la liste exacte que `lib/` appelle. Une faute de frappe dans cette
liste ferme une fonction utilisée, et le défaut ne se verrait qu'à l'usage :
le bloc lève donc si un nom cité n'existe pas en base.

**Conséquence pour toute nouvelle fonction** : sans `grant execute … to
authenticated`, elle est fermée — mais rejouer la tranche 7 la refermerait de
toute façon si son nom n'entre pas dans la liste. **Ajouter le nom à la liste
fait partie de la livraison.**

**2. `group_members` s'écrivait depuis le client.** `gm_insert with check
(user_id = auth.uid())` autorisait à **s'inscrire soi-même dans n'importe quel
groupe**, au rôle de son choix, en connaissant son identifiant. Or les
identifiants circulent : liens d'invitation, charges utiles de notification,
URL d'écran.

**3. Une invitation se forgeait.** `inv_insert with check (inviter_id =
auth.uid())` laissait créer une invitation pour soi-même vers n'importe quel
groupe, puis l'accepter — `accepter_invitation` ne vérifiait pas que
l'invitant en était membre. Elle le vérifie désormais, en plus du privilège
retiré : deux barrières valent mieux qu'une.

**4. Les liens d'invitation se lisaient anonymement.**
`lien_invitation_lecture_publique SELECT {anon} using (true)` : le `grant` de
colonnes restreignait bien la lecture à `(token, group_id)`, mais **rien ne
restreignait les lignes**. Une requête sans session ramenait *tous* les jetons
actifs du service, et chacun ouvre un groupe à qui le présente. La politique
est supprimée ; la page publique passe par `apercu_groupe_par_jeton`, qui
exige le jeton exact.

### `profiles` était lisible par tout le monde

```
profiles_select : ((id = auth.uid()) OR has_social_link(id) OR true)
```

Le troisième terme rendait les deux premiers sans effet. Le `or true` est
retiré ; `has_social_link`, prédicat du schéma initial, reprend son rôle.

Le seul appel direct qui lisait le profil d'autrui était le contrôle de
disponibilité d'un pseudo. Il passe désormais par `pseudo_disponible`, qui ne
renvoie qu'un **booléen** : elle dit si le pseudo est libre, jamais à qui il
appartient, et ne peut donc pas servir à dresser un annuaire.

### Une politique UPDATE sans `with check` autorise le déplacement

Piège général, rencontré cinq fois. PostgreSQL retombe alors sur l'expression
`using`, qui décrit la ligne **avant** modification :

```sql
create policy msg_update on public.messages
  for update using (sender_id = auth.uid());   -- with check implicite
```

L'auteur d'un message pouvait donc changer son `group_id` et le poser dans un
groupe dont il n'est pas membre. Même défaut sur `events`, `event_participants`,
`task_assignees`, `contacts`, et sur `chat_media_maj` côté stockage — un média
déplaçable vers le dossier d'un autre groupe.

**Règle** : toute politique UPDATE porte un `with check` explicite, même
identique au `using`. Ce qui compte, c'est ce qu'il dit de la ligne
**d'après**.

### Une politique ne borne pas les colonnes ; un `grant` si

RLS dit « cette ligne », jamais « cette colonne ». Là où le client écrit
encore, les colonnes modifiables sont donc bornées par un `grant` :

| Table | Colonnes ouvertes en écriture |
| --- | --- |
| `contacts` | `status`, `favorite_requester`, `favorite_addressee` |
| `notifications` | `read_at` |
| `group_invite_links` | `revoked_at` |
| `groups` | `name`, `description`, `photo_url`, `is_private`, `deleted_at` |
| `profiles` | tout sauf `id` |

Sans borne sur `contacts`, on pouvait réécrire `requester_id` d'une ligne où
l'on figure — donc **fabriquer un lien social avec n'importe qui**, ce que
`has_social_link` prend pour argent comptant, et qui ouvre désormais la
lecture d'un profil. Les deux défauts se renforçaient.

Sans borne sur `group_invite_links`, le compteur d'utilisations se remettait à
zéro : un lien épuisé redevenait utilisable.

### Buckets

| Bucket | Lecture | Écriture | Poids | Types |
| --- | --- | --- | --- | --- |
| `avatars` | publique | son propre dossier | 2 Mio | images |
| `group-photos` | publique | administrateurs du groupe | 2 Mio | images |
| `chat-media` | membres du groupe | membres du groupe | 25 Mio | images + vidéos |

**La convention de chemin porte l'autorisation**, comme en tranche 5b : le
premier segment est l'identifiant du propriétaire — utilisateur ou groupe.

`avatars` et `group-photos` restent **publics en lecture**, et c'est un choix
assumé : l'application enregistre l'URL publique dans `profiles.avatar_url` et
`groups.photo_url`, si bien que les rendre privés invaliderait toutes les URL
déjà stockées. Y passer demanderait de stocker le **chemin** et de signer à la
volée, comme `chat-media` — c'est un arbitrage, pas un oubli.

Le poids et les types sont bornés **côté serveur**, dans `storage.buckets` :
la borne de l'application ne protège que l'application, et une requête directe
s'en passe.

### Ce qui reste ouvert, et pourquoi

- **`email_pour_pseudo` est accessible à `anon`**, et le doit : se connecter
  par pseudo suppose de n'avoir pas encore de session. C'est un oracle
  pseudo → adresse e-mail, inhérent à la fonctionnalité. Le supprimer, c'est
  supprimer la connexion par pseudo.
- **`chercher_profils_par_pseudo` permet d'énumérer les comptes** par préfixe.
  Nécessaire pour inviter quelqu'un ; à surveiller si le service grandit.
- Les avatars et photos de groupe sont **lisibles de qui a l'URL**, voir
  ci-dessus.

---

## Écran Paramètres

Trois cartes titrées — **Compte**, **Notifications**, **Autre** — puis la
déconnexion dans la sienne, en rouge. Chaque ligne porte une icône, un
libellé, l'état courant en violet et un chevron.

### Ce que la maquette proposait, et ce qui existe

**Aucune ligne ne s'affiche sans mener quelque part.** Une carte de trois
lignes vraies vaut mieux qu'une de six dont la moitié est décorative — c'est
la même règle que le chevron de l'e-mail sur le profil, et que les lignes
Téléphone et Localisation écartées.

| Ligne de la maquette | Verdict | Coût si on la voulait |
| --- | --- | --- |
| Informations personnelles | **existait** — `/profil/modifier` | — |
| Changer de mot de passe | **ajoutée** | l'écriture `updatePassword` existait pour « mot de passe oublié » ; il manquait le chemin |
| À propos de Jelvo | **ajoutée** | un écran, et `AppConfig.version` |
| Notifications (4 lignes) | **existaient**, rangées autrement | — |
| Sécurité et confidentialité | écartée | recouvre ce que les autres lignes font déjà ; le reste — blocage, visibilité — n'existe pas en base |
| Sessions actives | écartée | **impossible côté client** : gotrue ne liste les sessions qu'avec la clé `service_role`. Il faudrait une fonction Edge |
| Apparence (thème sombre) | écartée | une palette entière à définir et chaque écran à revoir. `themeMode` reste figé sur `light` |
| Langue | écartée | une seule locale, et la migration vers l'ARB est partielle. Un sélecteur sans second choix ne réglerait rien |
| Fuseau horaire | écartée | `profiles.timezone` **existe** et vaut `Europe/Paris`, mais **rien ne le lit** : les rappels sont rendus en Europe/Paris en dur, côté SQL. L'afficher laisserait croire à un réglage sans effet |
| Aide et support | écartée | il n'y a ni adresse de support ni page d'aide à ouvrir |

Les deux dernières se rejoignent : ce ne sont pas des chantiers techniques,
ce sont des décisions produit — quelle adresse, quel contenu — qui ne se
devinent pas.

### Les huit types, rangés en trois familles

La ligne du haut **coupe tout** : sans autorisation, aucun type ne part, quel
que soit son interrupteur. Les trois suivantes détaillent.

| Famille | Types |
| --- | --- |
| Groupes et discussions | `chat_message`, `group_invitation` |
| Événements | `event_invitation`, `event_response`, `event_changed` |
| Tâches et rappels | `task_assigned`, `task_response`, `reminder` |

**Aucun type n'est fusionné en base.** `types_de_notification()` reste la
seule source ; une famille n'est qu'une liste de ses noms, et les huit
interrupteurs vivent dans la feuille qu'ouvre la ligne. Ce que la ligne
annonce — **Activées**, **Partielles**, **Désactivées** — se déduit des types
qu'elle couvre.

**Un type ajouté en base sans toucher à ce fichier reste réglable** : la
famille `autres` recueille tout ce qu'aucune ne réclame, et n'apparaît que si
elle a quelque chose à montrer. Sans elle, ajouter un type SQL le rendrait
muet côté écran — exactement le défaut qu'on répare ailleurs.

### `AppConfig.version` est recopiée, et vérifiée

Lire `pubspec.yaml` à l'exécution demanderait `package_info_plus`, une
dépendance pour une chaîne. La version est donc une constante, et
`test/app_version_test.dart` la confronte au pubspec : une version qui diverge
fait échouer les tests plutôt que de mentir à l'écran.

### L'ancien mot de passe n'est pas redemandé

gotrue ne le vérifie pas : `updateUser` s'appuie sur la session, pas sur une
confirmation. Un champ « mot de passe actuel » existerait donc sans rien
contrôler — et un champ qui ne contrôle rien donne un faux sentiment de
sécurité.

---

## Conventions

- **Langue** : identifiants, commentaires et documentation en français ; le
  vocabulaire Flutter reste en anglais (`build`, `onTap`, `copyWith`).
- **Dates** : passer par `AppDates` (locale `fr_FR`). `initializeDateFormatting`
  est appelé dans `main()` — un test qui formate une date doit faire de même.
- **Heure courante** : ne jamais appeler `DateTime.now()` dans un provider, un
  dépôt ou un widget. Utiliser `ref.watch(nowProvider)`, surchargeable avec
  `FixedClock` en test.
- **Typage** : types explicites sur les déclarations et les littéraux
  (`<Widget>[…]`). Exception assumée : les providers `…family` et les
  `overrides` de test, dont Riverpod 3 n'exporte pas les types (`ProviderFamily`,
  `Override`) — l'inférence est alors la seule option.
- **Riverpod 3** : `AsyncValue.value` est nullable (`valueOrNull` n'existe
  plus) ; on écrit `ref.watch(xProvider).value ?? const <T>[]`. L'état mutable
  passe par `Notifier` / `NotifierProvider`.
- **`InMemoryCollection.items` renvoie une liste non modifiable** : trier une
  copie (`List<T>.of(items)..sort(…)`). Trier l'original lève une
  `UnsupportedError` que le `StreamProvider` transforme en état d'erreur
  silencieux — écran vide sans message.
- **Débordements** : dans une `Row`, tout texte de longueur variable doit être
  dans un `Expanded`/`Flexible` avec `overflow: TextOverflow.ellipsis`. Les
  écrans doivent tenir à partir de 360 dp de large.
- **Commentaires** : expliquer *pourquoi*, pas *quoi*. Un commentaire qui
  paraphrase la ligne suivante est à supprimer.
- **Univers des données de démonstration** : Jelvo s'adresse à la sphère
  personnelle. Les jeux `demo…` — désormais réduits aux tâches et aux
  événements — restent dans un registre **familial et amical** : famille, amis,
  colocation, voyage, sport. Le registre professionnel (réunion, sprint, point
  hebdo, syndic, copropriété) est **hors périmètre produit** et ne doit
  réapparaître ni dans les libellés, ni dans les énumérations.

---

## Tests

- `test/widget_test.dart` couvre le parcours principal : accueil, navigation
  entre les quatre onglets, ouverture de `/creer`, validation du formulaire et
  filtrage des contacts.
- `test/home_screen_test.dart` couvre l'accueil refondu : la salutation avec
  le prénom et la date sans année, la photo qui ouvre le profil, le bouton
  calendrier de l'en-tête, la bande des groupes — nom, nombre de membres,
  initiale de repli quand il n'y a pas de photo, image demandée quand il y en
  a une —, la carte d'agenda avec sa plage horaire, la chronologie qui mêle
  événements et tâches sans laisser entrer les créneaux, la ligne de tâche non
  répétée dans la liste du bas, les trois compteurs, et les cas vides.
- `test/auth_flow_test.dart` couvre la garde de navigation, les erreurs de
  connexion, la disponibilité du pseudo et la déconnexion.
- `test/credentials_rules_test.dart` couvre les règles de validation, sans
  widget.
- `test/session_persistence_test.dart` couvre « Se souvenir de moi » sans
  widget : le défaut coché, l'écriture ou non de la session, l'effacement au
  décochage, la survie du *choix* alors que la session ne survit pas, et la
  déconnexion qui efface quel que soit le réglage.
- `test/groups_contacts_test.dart` couvre la liste et le détail d'un groupe, la
  création — sélecteur de membres compris : les contacts acceptés proposés,
  l'invitation partie à la création, et l'échec partiel annoncé —, le départ, les cinq états d'un lien d'invitation, les demandes de
  contact, l'encodage du QR code, et le « + » contextuel : depuis l'écran d'un
  groupe il n'offre plus d'en créer un, sa feuille ouvre `/creer` déjà réglée
  sur ce groupe, et les deux sections portent leur propre action « Ajouter ».
  Côté liste refondue : le titre « Mes groupes » et son « + », la carte qui
  porte nom, effectif, avatars et **« +1 » calculé sur l'effectif** plutôt que
  sur la rangée, la pastille violette qui compte les messages du groupe — et
  son absence, plutôt qu'un zéro, sur le groupe sans message —, un groupe sans
  activité qui ne dit pas « 0 tâche », **une moitié vide qui s'efface** au lieu
  d'afficher son zéro, la recherche qui n'apparaît qu'à trois groupes, son
  filtrage, et la recherche sans résultat qui ne propose pas de créer.
  Côté écran de groupe refondu : le bandeau qui porte le nom, le nombre de
  membres, les avatars et **les trois pastilles seulement**, le repli sans
  photo qui ne charge aucune image, le crayon réservé à l'administrateur, les
  deux compteurs confrontés à un décor où une tâche est en retard et une autre
  non — **une tâche d'un autre groupe ne comptant pas** —, la rangée d'accès
  rapides qui n'offre ni listes, ni dépenses, ni notes, le compteur et le
  « Voir tout » qui ouvrent tous deux les tâches **du groupe** et non toutes,
  le tri par priorité avec sa pastille sur la seule « Haute », et les deux
  sections vides qui gardent chacune leur action sans proposer de « Voir tout ».
  Côté adhésion temporaire : la date de fin lisible sur la ligne du membre —
  et absente pour un membre permanent —, le réglage depuis le menu qui
  n'écrit qu'à la confirmation, « Sans terme » qui rend l'adhésion permanente,
  un refus de la base qui reste dans la feuille au lieu de la refermer, la
  durée emportée par l'invitation nominative comme par le lien, l'absence de
  terme quand on n'en choisit pas, et la page publique qui annonce la durée
  avant d'accepter. Côté carnet refondu : le titre et la barre de recherche,
  la bande des favoris qui ne montre que les étoilés **et suit l'étoile
  immédiatement**, le rangement par lettre et son inversion par le bouton de
  tri, la pastille des groupes en commun au singulier comme au pluriel, la
  ligne qui ouvre de quoi retirer un contact, les trois moyens d'ajouter
  quelqu'un, « Gérer » qui épingle à la chaîne, les trois cas vides — carnet
  vide sans bande, aucun favori avec invitation, recherche sans résultat — et
  la ligne qui tient à 360 dp.
- `test/notifications_test.dart` couvre la cloche, la répartition des pastilles
  par onglet, leur extinction, la liste et le marquage comme lu.
- `test/tasks_events_test.dart` couvre les écrans de détail, l'assignation et
  l'administration des groupes.
- `test/invitations_test.dart` couvre les trois écrans d'invitation : l'en-tête
  commun — qui invite, ce qu'il fait, depuis quand —, l'ordre des boutons
  (refus toujours à gauche, sur les deux boutons comme sur les trois), la carte
  centrale de chacun, et **les six états dégradés** du groupe : acceptée,
  refusée, expirée, groupe supprimé, identifiant inconnu, et le fait qu'aucun
  bouton sans effet ne subsiste. Côté événement : l'absence d'illustration
  quand `image_url` est nul, la ligne « Lieu » omise plutôt que vide, la
  réponse à trois choix et son enregistrement, la réponse déjà donnée qui ne
  verrouille rien, l'événement supprimé. Côté tâche : les quatre lignes dont
  la priorité, l'assigné, l'acceptation, la tâche non assignée et la tâche
  supprimée. Côté bandeau : la couverture présente sur les trois écrans,
  l'image propre à un événement qui l'emporte sur celle du groupe, le repli
  sans image inventée, et le nom du groupe lu dans la réponse plutôt que dans
  la liste locale. Enfin les ouvertures depuis la boîte de notifications, dont
  la réponse à une tâche — acceptée, déclinée — qui mène au **détail**.
- `test/auth_failure_test.dart` couvre la traduction des erreurs PostgREST
  sans widget : une colonne absente ne doit pas inviter à réessayer, et les
  cas déjà couverts — pseudo pris, refus RLS, repli générique — ne bougent
  pas.
- `test/avatar_catalog_test.dart` couvre le catalogue sans widget : la liste
  générée confrontée au dossier, les trois trous de numérotation, l'existence
  de chaque fichier, et la résolution d'une valeur `preset:` — y compris le
  préfixe nu, qui ne doit pas produire un chemin bancal.
- `test/profile_screen_test.dart` couvre l'écran de profil refondu : le nom,
  le pseudo et les trois actions, le QR code, le formulaire pré-rempli qui
  referme sur le profil, la pastille qui ouvre le choix photo ou avatar Jelvo,
  la bio vide qui invite à la remplir, l'absence de téléphone, de localisation
  et de badge de présence, les trois compteurs, et un compteur qui ouvre la
  liste qu'il résume. Côté bio sur place : la ligne qui devient un champ déjà
  actif, l'enregistrement à la sortie du champ comme par la coche, l'échec qui
  reste en saisie avec son message, le texte intact qui n'écrit rien, le
  crayon à la place du chevron, et le nom modifié qui ne perd pas la bio.
- `test/avatar_gallery_test.dart` couvre la galerie : les deux voies
  cohabitant dans la feuille de choix du profil, la sélection qui n'enregistre pas seule, la
  confirmation qui enregistre, l'inertie sans choix, l'anneau sur l'avatar
  courant, et la photo effacée par le choix d'un avatar.
- `test/availability_weekday_test.dart` couvre la conversion ISO ↔
  `extract(dow)`, sans widget : les six jours identiques, le dimanche qui ne
  l'est pas, la réversibilité, et la relecture d'une ligne de la base.
- `test/availability_calendar_test.dart` couvre la semaine d'accueil (sept
  jours, marqueurs, ouverture du calendrier à la date touchée), les quatre
  compteurs, l'agrégation d'un événement, d'une tâche et d'un créneau sur la
  même journée, le filtre par groupe — qui ne masque pas les créneaux —, et
  l'écran de disponibilités ouvert depuis le profil. Côté calendrier refondu :
  l'en-tête à quatre entrées, la ligne du jour et son bouton de retour qui
  n'apparaît que si l'on s'est éloigné, les pastilles sous les dates, la
  recherche qui trouve un événement et ouvre sa date, les créneaux masqués
  depuis les filtres sans toucher au reste, et la journée vide.

- `test/chat_test.dart` couvre l'entrée depuis l'écran du groupe et sa
  pastille, l'ordre inversé de la conversation, l'envoi, le refus d'un message
  vide, l'arrivée d'un message par le flux temps réel, l'indicateur de frappe
  dans les deux sens, la bascule d'une réaction, et les trois issues d'une
  suppression — la sienne, celle d'un autre, et celle qui ne touche aucune
  ligne. Côté pastilles : l'onglet Groupes allumé sans être entré nulle part,
  douze messages dans un groupe qui comptent pour une conversation, deux
  groupes actifs qui comptent pour deux, et l'extinction à la lecture. Côté
  médias : le sélecteur qui ne propose jamais de document, la
  vignette qui ne laisse pas fuiter le chemin de stockage, la vidéo annoncée
  comme telle, le média qui disparaît à la suppression, et les bornes de poids
  et d'extension, sans widget. Côté cartes : la tâche proposée au groupe et ses
  deux boutons, la prise qui appelle le dépôt, **la course** — la seconde
  personne lit « quelqu'un vient de la prendre avant vous » —, le preneur
  annoncé sans boutons pour les autres, le désistement réservé à celui qui a
  pris, la tâche confiée et son refus, les deux suppressions qui laissent une
  carte parlante, les trois réponses d'un événement avec son décompte, et la
  place chronologique de la carte entre deux messages. Côté avatars : une série de trois messages ne
  porte qu'un seul visage, posé sur le dernier, la gouttière garde les bulles
  alignées, ses propres messages n'en ont pas, et l'avatar prédéfini de
  l'expéditeur est rendu par le même point que partout ailleurs.

- `test/push_notifications_test.dart` couvre les réglages de notification :
  l'activation qui enregistre l'abonnement en base, le refus et sa marche à
  suivre, la désactivation des deux côtés, la consigne d'installation iOS sans
  bouton, les huit types désactivables, l'interrupteur qui revient si l'écriture
  échoue, et le réenregistrement au démarrage. Côté écran refondu : les trois
  cartes titrées, l'absence de toute ligne qui ne mènerait nulle part, le
  rangement des huit types dans leurs trois familles, le changement de mot de
  passe enfin atteignable, et la version annoncée par « À propos ».
- `test/app_version_test.dart` confronte `AppConfig.version` au `pubspec.yaml`,
  sans widget : la version est recopiée à la main, et une version fausse est
  pire qu'une version absente.
- `test/welcome_screen_test.dart` couvre l'écran de bienvenue : l'installation
  neuve qui s'ouvre dessus, les trois arguments et leurs pictogrammes,
  l'absence de « Passer » et de `PageView`, le titre sans emoji, la bande
  d'illustration qui garde sa hauteur, l'illustration bien présente au dépôt
  et à ses dimensions — contrôle qu'un `errorBuilder` rendrait sinon muet —,
  et « Commencer » qui mène à la connexion. Côté mémoire : le drapeau posé au départ, l'ouverture
  directe sur la connexion quand il l'est déjà, la session qui vaut
  présentation faite — **même sur une mémoire vierge** —, et le contrôle
  négatif qui compte le plus, `/rejoindre/<jeton>` que la présentation ne
  préempte jamais.
- `test/creation_screens_test.dart` couvre les trois écrans de création. Côté
  tâche : personne de présélectionné et la mention qui l'annonce, la mention
  qui change dès qu'on coche un avatar, **la liste vide et non nulle** envoyée
  au dépôt — c'est elle qui produit la carte à boutons dans la conversation —,
  l'absence du bouton « Autre » quand la rangée montre déjà tout le monde, et
  « Plus d'options » qui replie échéance, priorité et description avec son
  compteur. Côté événement : le choix du groupe, qui n'existait pas, jusqu'à
  l'identifiant transmis à la création ; « Tous les membres » sans sélection et
  le décompte après ; la date, l'heure et la fin qui tiennent ensemble ; la
  description visible d'emblée et l'absence de « Plus d'options », qui
  s'ouvrirait sur du vide. Côté groupe : le compteur de caractères qui suit la
  frappe, « Groupe privé » devenu un constat — **aucun `Switch` ne subsiste** —,
  l'ordre des suggestions qui met la favorite aux trois groupes communs avant
  le contact à un seul, « Inviter par lien » qui ouvre bel et bien la feuille
  du lien après la création, son contrôle négatif, et « Choisir dans mes
  contacts » qui ouvre le carnet entier en noms complets.

Onze faux dépôts vivent dans `test/fakes/` : authentification, profil, groupes,
contacts, notifications, tâches, agenda, disponibilités, chat, navigateur
(`FakePushService`) et préférences de notification. **Tous les
fichiers de test les surchargent tous** — un provider oublié tombe sur
`Supabase.instance`, absent en test.

`FakeChatRepository` simule le temps réel par un `StreamController` : un vrai
canal Realtime demande une socket, que le harnais de test n'a pas. Ce qui est
éprouvé, c'est donc que **l'écran réagit au signal** — pas que le signal
arrive, ce qui ne se vérifie qu'à l'usage.

L'oubli ne se voit pas toujours : un `AsyncNotifier` qui échoue à la
construction donne un `AsyncValue` en erreur, dont le `.value` nul retombe sur
la liste vide de repli. L'écran s'affiche, vide, et le test passe pour de
mauvaises raisons.

Quatre points à respecter dans tout nouveau test de widget :

1. Surcharger l'horloge — les données de démonstration et les libellés
   « Aujourd'hui »/« Demain » en dépendent :
   ```dart
   ProviderScope(
     overrides: [clockProvider.overrideWithValue(FixedClock(dateFigee))],
     child: const JelvoApp(),
   )
   ```
2. Agrandir la surface de test. Par défaut elle fait 800 × 600, ce qui laisse la
   moitié des écrans hors champ : les `Sliver` ne construisent alors pas leurs
   enfants et `find.text` ne trouve rien.
   ```dart
   tester.view.physicalSize = const Size(420, 1600);
   tester.view.devicePixelRatio = 1;
   ```
3. Surcharger l'authentification et le profil. Sans cela, les providers
   cherchent `Supabase.instance`, qui n'est pas initialisé en test, et l'écran
   reste bloqué sur la connexion :
   ```dart
   overrides: [
     authRepositoryProvider.overrideWithValue(FakeAuthRepository(signedIn: true)),
     profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
   ]
   ```
   Les deux faux dépôts vivent dans `test/fakes/fake_auth_repository.dart`.
4. Surcharger tout le reste du domaine, pour la même raison :
   `groupRepositoryProvider`, `contactRepositoryProvider`,
   `notificationRepositoryProvider`, `taskRepositoryProvider`,
   `eventRepositoryProvider`, `availabilityRepositoryProvider` et
   `chatRepositoryProvider`, avec les faux dépôts de `test/fakes/`. L'accueil,
   le calendrier et l'écran de groupe les lisent tous les sept.

Le `+` central de la barre et le bouton « Nouveau groupe » portent la même
icône : viser un bouton d'en-tête par `find.byTooltip`, pas par `find.byIcon`.
L'infobulle du `+` change avec l'écran, ce qui en fait aussi le moyen le plus
sûr d'éprouver son caractère contextuel.

---

## État actuel et limites connues

- **Tout le domaine est branché sur Supabase** : authentification, profil,
  groupes, contacts, invitations, notifications, tâches, événements,
  disponibilités et chat. Il n'y a plus aucun jeu de données de démonstration
  dans `lib/` — les seuls restants vivent dans `test/fakes/`.
- **Les vidéos s'envoient mais ne se lisent pas dans l'application.** Elles
  sont sélectionnées, bornées en poids, téléversées, stockées et affichées
  comme pièce jointe ; seule la **lecture en place** manque, car elle demande
  `video_player`, c'est-à-dire une nouvelle dépendance — un arbitrage, pas une
  exécution. Les photos, elles, sont complètes : vignette et plein écran.
- **Le temps réel n'est pas éprouvé automatiquement.** Les tests simulent le
  flux par un `StreamController` ; qu'un événement arrive réellement dépend de
  la publication `supabase_realtime` et d'une socket, et ne se constate qu'à
  l'usage. Un défaut de publication est muet : le canal s'abonne et rien
  n'arrive.
- Les notifications sont **relues à la demande**, pas poussées : la liste se
  rafraîchit à l'ouverture de l'écran, au geste de traction et après chaque
  action. Le temps réel et les notifications système (`push_tokens`) ne sont pas
  au périmètre.
- **La migration des chaînes vers l'ARB est partielle.** L'infrastructure est
  complète et `app_fr.arb` couvre la navigation, l'accueil, l'écran de groupe,
  la création, les statuts et les erreurs. Les écrans d'authentification, de
  contacts, de notifications et d'invitation portent encore leurs chaînes en
  ligne : elles restent à déplacer, sans changement de code autre que
  l'appel à `AppTexts.of(context)`.
- Tâches et événements ont leur écran de détail (`/taches/:id`,
  `/evenements/:id`), leur formulaire en feuille et leur liste (`/taches`).
  Restent hors périmètre : les notifications système, et la modification d'une
  seule occurrence d'un élément récurrent — la `rrule` vaut pour toute la
  série.
- **Trois prérequis manuels subsistent, et rien ne les remplace :**
  1. faire émettre `{{ .Token }}` au modèle d'e-mail de confirmation, pour le
     code à 6 chiffres ;
  2. **planifier `envoyer-push` toutes les minutes** — sans quoi la file ne se
     vide pas et aucun rappel n'est empilé ;
  3. pour que `schema_actuel.sql` atteigne `main` : le rôle
     **`RepositoryRole` `#5`** dans la Bypass list du ruleset **et** le secret
     **`JETON_POUSSEE_SCHEMA`** — jeton personnel d'un administrateur,
     permission *Contents* en écriture. L'application `github-actions` n'y est
     pas inscriptible : voir « L'application GitHub Actions ne peut pas être
     contournée ici ».

     **Posé et constaté** le 23 août 2026 : le commit `ee268eb`, « Relève le
     schéma réel de la base », est la première publication d'instantané à
     avoir atteint `main`. Le prérequis reste listé parce qu'il ne tient qu'à
     ces deux réglages — le jeton expire, et le rôle se retire d'un clic.

  Les migrations, elles, s'appliquent seules à chaque push sur `main`.
- **Une migration n'est éprouvée contre la vraie base qu'après fusion.** Le
  workflow qui l'applique ne peut pas tourner sur une pull request — le dépôt
  est public et le secret y serait exposé. Avant fusion, il reste
  `supabase/verification/rejouer.sh`, sur schéma factice : il compile *et*
  appelle les fonctions, mais son décor est recopié de cette documentation, et
  ne dit donc rien des colonnes réelles. C'est `supabase/schema_actuel.sql`,
  relevé après coup, qui fait foi.
- Le test de fumée couvre les tranches 3, 3b, 4, 5a, 5b, 5c, 5d, 6 et 8 — plus
  de trente fonctions réellement appelées, contrôles négatifs de l'accès au
  bucket, de la mémoire des rappels, du rangement des adhésions, de la portée
  d'`invitation_par_id` et de l'auto-attribution qui ne notifie pas. Le retour
  à l'auteur y est éprouvé des deux côtés : la ligne déposée dans la boîte et
  celle empilée pour le téléphone. La tranche 9 y ajoute **la course** — la
  seconde prise ressort `deja_prise` —, le désistement qui rouvre la tâche,
  celui qu'une tâche confiée refuse, et la carte d'un élément supprimé qui
  garde son titre. La tranche 10 y ajoute le compte des groupes en commun,
  avec ses deux contrôles négatifs : une adhésion échue et un groupe supprimé
  ne comptent plus.
  La tranche 6 y fait entrer `inviter_dans_groupe`,
  `accepter_invitation`, `rejoindre_groupe_par_jeton` et
  `apercu_groupe_par_jeton`, qui datent de la tranche 2 : le reste de cette
  tranche n'est toujours éprouvé que par l'usage en production.
- **« Non » sur une tâche proposée au groupe ne s'écrit pas.** Le bouton
  accuse réception, la tâche reste proposée : `assignee_status` suppose une
  ligne d'assignation, et refuser une tâche qu'on ne vous a pas confiée n'en
  crée aucune. Une table de refus serait le seul moyen de le retenir, et rien
  d'autre n'en a besoin.
- **Une invitation à un événement et une tâche confiée n'ont pas d'âge.** Les
  deux écrans le taisent plutôt que de l'approcher : `event_participants` ne
  porte que `responded_at`, `task_assignees` aucune date. Le combler
  demanderait une colonne de plus sur ces deux tables — un `alter table add
  column if not exists`, donc rien d'insurmontable, mais une écriture du
  schéma initial que rien d'autre ne réclame aujourd'hui.
- **Les disponibilités n'ont pas encore de lecture en dehors de la création
  d'événement.** Le statut d'un contact n'apparaît ni sur sa fiche, ni dans la
  liste des contacts ; c'est la suite naturelle, et elle ne demande aucun SQL
  de plus — `statuts_de_disponibilite` accepte déjà une liste.
- Le calendrier agrège une **journée** à la fois. Une vue mois, et le rendu des
  événements à cheval sur deux jours, restent hors périmètre : la timeline
  place chaque élément à son heure de début.
- Le scan de QR code demande une caméra : il est désactivé proprement sur le web
  et sur ordinateur, où l'écran renvoie vers la recherche par pseudo. Les cibles
  Android et iOS n'ont pas pu être compilées ici — `mobile_scanner` embarque du
  natif, et ni le SDK Android ni la chaîne iOS ne sont disponibles dans
  l'environnement de développement utilisé.
- **L'adhésion temporaire est complète** — voir sa section. Deux réserves :
  une adhésion échue et rangée ne se prolonge plus, il faut réinviter ; et
  personne n'est **prévenu** de l'échéance, ni le membre à l'approche du terme,
  ni les administrateurs après coup. Un rappel « votre accès s'arrête
  demain » relèverait de la file de la tranche 5c et n'est pas au périmètre.
- L'écran `/creer` enregistre désormais pour de bon : événement ou tâche, avec
  choix du groupe — ou « Personnel » — et de la date. Le choix « Groupe »
  redirige vers l'écran de création dédié. Ouvert depuis un groupe, il arrive
  pré-rempli par l'URL (`?type=…&groupe=…`).
- **L'image d'un événement se lit mais ne se téléverse pas.**
  `events.image_url` est dans le schéma initial, les trois écrans d'invitation
  la préfèrent à la couverture du groupe, et `updateEvent` la conserve — mais
  **aucun écran ne permet d'en choisir une**, et aucun bucket ne l'accueille :
  `avatars`, `group-photos` et `chat-media` portent chacun une convention de
  chemin qui ne convient pas. La combler demande un quatrième bucket, ses
  quatre politiques et son sélecteur — un chantier, pas un oubli. C'est la
  seule ligne de la maquette de création qui n'a pas pu être branchée, et c'est
  pourquoi l'événement n'a pas de « Plus d'options ».
- **`groups.is_private` est écrite et lue par personne.** La colonne existe,
  `creer_groupe` la renseigne, mais aucune politique RLS ne la cite : tout
  groupe Jelvo est privé. L'écran de création l'annonce désormais comme un fait
  au lieu d'offrir un interrupteur sans effet — voir « « Groupe privé » est un
  constat ».
- La récurrence se choisit dans une liste fermée (jamais, quotidienne,
  hebdomadaire, quinzaine, mensuelle, annuelle). Une `rrule` écrite ailleurs et
  non reconnue s'affiche « Jamais » mais **n'est pas effacée** tant que le
  sélecteur n'est pas touché.
- Les rappels partent — voir « Rappels ». Deux réserves : une `rrule` que
  l'application n'écrit pas n'est pas rappelée du tout, et l'arithmétique de
  récurrence se fait dans le fuseau de la session (UTC), si bien qu'un élément
  récurrent peut se décaler d'une heure au passage à l'heure d'été. Corriger
  cela demanderait un fuseau par élément, que le schéma ne porte pas.
- **Le chemin complet d'un rappel n'a pas été éprouvé de bout en bout.** Le
  test de fumée prouve que la file se remplit à la bonne heure et une seule
  fois ; que le navigateur affiche bien la notification dépend de la
  planification, des clés VAPID et d'un vrai appareil.
- Le mode sombre n'est pas au périmètre : `themeMode` est figé sur
  `ThemeMode.light`. L'écran Paramètres ne propose donc **aucune** ligne
  « Apparence » — voir l'inventaire de sa section.
- **`profiles.timezone` existe et n'est lu par personne.** Les rappels sont
  rendus en Europe/Paris en dur, côté SQL. Offrir un sélecteur de fuseau
  demanderait de le lire dans `empiler_rappels` **et** de formater les dates
  côté client dans cette zone — deux chantiers, pas un réglage.
- **Les sessions actives ne sont pas listables depuis le client** : gotrue ne
  les expose qu'à la clé `service_role`. Il faudrait une fonction Edge.
- `google_fonts` télécharge Inter au premier lancement. Pour un fonctionnement
  hors ligne garanti, il faudra embarquer la police dans `assets/`.
- Les dossiers `android/` et `ios/` sont générés et configurés (`com.jelvo.jelvo`,
  libellé « Jelvo »), mais seule la cible **web** a été compilée et vérifiée ici :
  le SDK Android et la chaîne iOS ne sont pas disponibles dans l'environnement de
  développement utilisé.
