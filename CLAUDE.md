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

tool/verifier.sh                 # les quatre commandes de la CI, codes de sortie lus
tool/verifier.sh --sans-build    # idem sans la compilation web
node tool/preparer_ecrans_de_lancement.js   # écrans de lancement iOS — voir web/splash/

tool/pieges_migrations.py        # quels fichiers de migration sont **gelés**
                                 # — à lancer avant d'en modifier un
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

C'est arrivé **une seconde fois**, sur l'analyse, et c'est pourquoi
`tool/verifier.sh` existe : il rejoue les quatre commandes dans l'ordre du
workflow et relève le `$?` de chacune, sans tube. Un filtre n'est pas un
verdict.

Le second passage ajoute deux pièges propres à `flutter analyze`, qu'aucune
lecture du workflow ne révèle :

- **il sort en échec sur un simple avertissement**, pas seulement sur une
  erreur. Un import devenu mort suffit à mettre l'étape au rouge, et donc à
  annuler tests, compilation et déploiement ;
- **sans option, il n'écrit pas ses lignes en retrait.** Le filtre employé
  attendait une indentation (`^ +(error|warning|info)`) : il ne pouvait rien
  trouver, quelle que soit la gravité. Un motif trop précis sur un format de
  sortie non contractuel ment dans le sens le plus coûteux — celui du vert.

Le prix payé : la PR #66 a échoué sur **un** import mort, et le thème sombre
est resté hors ligne le temps de le voir.

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

#### Quatre échecs différents, un seul rouge

Le job peut échouer à quatre endroits, et **le rouge ne dit pas lequel** :

| Où | Ce qui est vrai | Ce qu'il faut faire |
| --- | --- | --- |
| `checkout` | **rien n'est appliqué**, et le journal ne parle même pas de SQL | voir « Un jeton mort ne doit casser que l'instantané » |
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

#### Un jeton mort ne doit casser que l'instantané

**Constaté le 22 novembre 2026, et c'est le quatrième mode d'échec** — celui
qui manquait au tableau ci-dessus, et le plus trompeur, parce que son journal
ne parle pas de SQL du tout :

```
fatal: could not read Username for 'https://github.com':
terminal prompts disabled
```

L'étape `checkout` portait
`token: ${{ secrets.JETON_POUSSEE_SCHEMA || github.token }}`. **Ce repli ne
couvre qu'un secret absent, pas un secret refusé** : le jeton personnel ayant
expiré, `checkout` recevait un identifiant mort et ne pouvait même plus *lire*
le dépôt. Le job mourait donc avant `appliquer.sh`.

Le prix : les tranches **15 et 16** ont été fusionnées, déployées côté
application, et **la base n'a rien reçu**. L'application offrait un bouton
« Signaler » et un bouton « Bloquer » que la base ne servait pas — exactement
le défaut de la tranche 14, par une autre porte. Le contrôle qui l'a trouvé
n'est pas le rouge du job : c'est d'avoir interrogé la base, où
`to_regclass('public.signalements')` rendait `null`.

**Règle** : `checkout` lit avec `GITHUB_TOKEN`, toujours. Le jeton personnel
est posé sur la **seule** étape qui en a besoin, la poussée de l'instantané, de
sorte qu'un jeton mort ne casse que ce dont il est responsable — le troisième
échec, déjà documenté et déjà annoncé en toutes lettres.

Deux points de forme sur cette poussée :

- **un en-tête `Authorization`, et non une URL `https://jeton@…`** : un refus
  de git recopie l'URL distante dans son message, ce qui publierait le jeton
  dans le journal d'un dépôt **public** ;
- **le masque est reposé sur la valeur encodée.** Celui de GitHub porte sur le
  secret tel qu'enregistré, pas sur son base64 — même leçon que la chaîne de
  connexion épurée, où retirer un saut de ligne suffit à sortir du masque.

**Règle de méthode, et c'est la troisième fois qu'elle se paie** : un repli
`||` sur un secret ne distingue pas « absent » de « invalide ». Une
vérification de *présence* laisse passer un jeton mort — c'est déjà ce qui
était écrit de l'étape « Vérifier les secrets » de `fonctions-supabase.yml`,
et cela valait ici aussi.

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
│   ├── utils/                # AppDates (dates et heures, par langue)
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
`create`, `signalements` — qui porte aussi le blocage, les deux étant deux
façons de répondre au même abus et partageant leur dépôt.

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

### Couleurs — `JelvoColors`, et `context.couleurs`

| Jeton           | Clair     | Sombre    | Usage                          |
| --------------- | --------- | --------- | ------------------------------ |
| `primary`       | `#5B2EFF` | `#9E86FF` | actions principales, sélection |
| `primaryDark`   | `#3D1DB8` | `#7A5FE8` | états pressés, dégradés        |
| `primaryInk`    | `#4A22D6` | `#9E86FF` | le violet **en texte**         |
| `encre`         | `#12122B` | `#ECECF5` | texte principal, titres        |
| `textSecondary` | `#6B6B85` | `#A6A6C4` | texte secondaire, légendes     |
| `background`    | `#F7F7FB` | `#0E0E1A` | fond d'écran                   |
| `surface`       | `#FFFFFF` | `#1B1B30` | cartes, feuilles, barres       |
| `success`       | `#22A06B` | `#3ECF8E` | confirmé, terminé              |
| `warning`       | `#F5A623` | `#F2B544` | en attente, échéance proche    |
| `danger`        | `#E5484D` | `#F87171` | conflit, action destructive    |
| `border`        | `#ECECF4` | `#33334F` | traits, contours de champs     |
| `onAccent`      | `#FFFFFF` | `#12122B` | encre **sur un aplat saturé**  |

Les variantes `…Soft` servent aux fonds teintés ; les variantes `…Ink` sont la
même teinte **en texte**. `scrim`, `shadow`, les quatre jetons de bulle et les
deux listes d'accents complètent le jeu — voir `core/theme/jelvo_colors.dart`.

#### `midnight` s'appelle `encre`, et ce n'est pas un caprice

En sombre, ce jeton vaut `#ECECF5` — presque blanc. Le garder « minuit »
aurait fait mentir le nom sur la moitié des écrans, et un jeton qui ment est
pire qu'un jeton mal nommé.

#### Une `ThemeExtension`, et non des constantes

Les jetons étaient des `static const`. Une constante ne change pas de valeur à
l'exécution — et une **variable globale** ne conviendrait pas non plus, pour
une raison qui n'est pas évidente : Flutter ne reconstruit que ce qui dépend
d'un `InheritedWidget` modifié, et un widget qui lit une globale n'en dépend
d'aucun. Basculer le réglage laisserait la moitié de l'écran dans l'ancienne
palette jusqu'à ce qu'autre chose la fasse reconstruire.

Passer par le thème résout les deux à la fois : la valeur change, et
`Theme.of` crée la dépendance qui déclenche la reconstruction.

**Tout se lit donc au contexte** : `context.couleurs.surface`,
`context.typo.body`, `context.ombres.card`. Un modèle ou un provider qui
devrait choisir une couleur ne le peut plus — il n'a pas de `BuildContext` —,
et c'est voulu : il dit **ce que la chose est**, le widget en tire la teinte.
`AgendaEntry` porte un `AgendaAccent` et non une `Color`, `StatusTone` rend
`color(c)` et `ink(c)`, `GroupAccent` et `SpeakerAccent` rendent leur rang.

**Un thème absent ne fait pas planter** : `context.couleurs` retombe sur la
palette claire. C'est pour le widget isolé d'un test, pas une invitation à
s'en passer.

#### Ce qui ne suit **pas** le thème, et pourquoi

| Élément | Ce qu'il fait | La raison |
| --- | --- | --- |
| voile d'un bandeau photo | reste **noir** | il est posé sur une photographie, qui n'a pas d'apparence ; bâti sur `encre`, il éclaircirait le bas de l'image en sombre et effacerait le titre blanc qu'il sert à détacher |
| pastilles du bandeau de groupe | restent **blanches**, encre sombre | elles doivent trancher sur un ciel d'été comme sur une photo de nuit ; suivre le thème les aurait rendues sombres — invisibles sur une photo sombre, le défaut même qu'elles existent pour éviter |
| bulle de l'utilisateur | reste un **violet profond**, texte blanc | l'encre ne s'inverse pas : c'est ce qui permet à l'heure et à la coche de lecture de garder leur blanc translucide, et c'est la seule pièce qui dit « c'est moi qui parle » |
| initiale d'un avatar, icône d'un groupe | restent **blanches** | elles sont posées sur un accent, borné pour que le blanc s'y lise dans les deux thèmes |

#### Les teintes fonctionnelles étaient déjà illisibles en texte

Mesuré, pas supposé : `warning` sur `warningSoft` donnait **1,81:1**,
`success` **2,96:1**, `danger` **3,35:1** — sous les 4,5:1 d'un texte courant,
et **avant** ce chantier. D'où les variantes `…Ink`, assombries en clair et
confondues avec la teinte vive en sombre, où c'est le fond qui est foncé.
`StatusDot` rempli porte désormais l'encre, jamais la teinte vive.

Un seul accent **clair** a changé de valeur : l'ambre des groupes, de
`#F5A623` à `#C27D0C`. Une icône blanche dessus ne donnait que 2,03:1, dans
les deux thèmes.

#### En sombre, l'ombre ne sépare plus rien

Une ombre noire à 4 % sur un fond presque noir est invisible. C'est l'écart de
clarté entre `surface` et `background` qui porte seul la séparation — et c'est
pour cela que la carte sombre est plus **claire** que son fond. Les opacités
d'`AppShadows` sont doublées en sombre, ce qui creuse le pourtour sans
dessiner de halo ; seule l'ombre `accent`, colorée, garde tout son sens.

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

#### Les emojis ont leur police, embarquée

Le web ne garantit **aucune** police d'emojis : selon la machine, un emoji
s'affichait en couleur, en noir et blanc, ou pas du tout. Le rendu était
incohérent d'un poste à l'autre, et d'un emoji à l'autre sur le même poste.

L'embarquer était nécessaire, mais **pas suffisant** : voir « Le repli ne
suffit pas » plus bas, qui est la moitié du problème que la police seule ne
règle pas.

`assets/fonts/NotoColorEmoji.ttf` est donc embarquée et posée en
`fontFamilyFallback` sur **tous** les styles d'`AppTypography` — pas seulement
sur les bulles : partout où du texte saisi par quelqu'un s'affiche, c'est-à-dire
aussi les noms de groupes, les titres et descriptions de tâches et
d'événements, et la bio du profil. Inter n'ayant aucun glyphe d'emoji, le
moteur ne descend ici que pour eux : le texte latin ne bouge pas d'un pixel.

**La variante compte, et le double est en jeu** :

| Variante | Table | Brut | gzip |
| --- | --- | --- | --- |
| bitmap | `CBDT`/`CBLC` | 10,18 Mio | 9,43 Mio |
| **vectorielle (retenue)** | `COLR`/`CPAL` | 4,76 Mio | **2,69 Mio** |

Le bitmap embarque une image PNG par emoji, déjà compressée : le serveur n'y
gagne rien. Celle servie par `fonts.gstatic.com` pèse 23,95 Mio — c'est la même
COLRv1, non optimisée ; celle du dépôt `googlefonts/noto-emoji` est la bonne.

**Un sous-ensemble ne conviendrait pas**, et c'est la première question qu'on
se pose : sous-ensembler suppose de connaître à l'avance les emojis employés,
or le texte concerné est **saisi par les utilisateurs**. Quelqu'un tape 🫠 et
obtient un carré vide, sans que rien ne l'ait annoncé — le défaut qu'on
corrige, en plus sournois parce qu'intermittent.

`assets/fonts/README.md` porte le détail, dont les deux pistes qui, elles,
tiennent : ne pas embarquer sur mobile — iOS et Android ont déjà la leur —, et
servir la police depuis le réseau sur le web. Les deux sont des arbitrages.

`GoogleFonts.inter()` **n'accepte pas** `fontFamilyFallback` : il passe par un
`copyWith` (`AppTypography._avecEmojis`). L'oublier sur un style le rendrait
muet, sans erreur.

#### Le repli ne suffit pas — et c'est le piège central

**Un repli de police n'est consulté que pour ce que la police principale ne
couvre pas.** Or Inter couvre **trente-sept** des caractères de Noto Color
Emoji, dont les plus employés :

```
❤ U+2764   ⚠ U+26A0   ☀ U+2600   ⬆ U+2B06   ♥ U+2665
© U+00A9   ® U+00AE   ™ U+2122   ‼ U+203C   ⁉ U+2049
↔ ↕ ↖ ↗ ↘ ↙ ↩ ↪ ⏏ Ⓜ ▪ ▶ ◀ ⬜   et les chiffres 0-9, # et *
```

Pour ceux-là, **Inter gagne, le repli n'est jamais atteint**, et le glyphe
sorti est celui d'une police de texte — c'est-à-dire noir. C'est exactement ce
qu'on a constaté : « un cœur rouge tapé au clavier iPhone apparaît en cœur
noir », alors que `😀`, absent d'Inter, sortait bien en couleur.

**Le sélecteur `U+FE0F` n'y change rien.** Il est censé forcer la présentation
emoji, mais la résolution de police se fait **caractère par caractère** : le
cœur est déjà attribué à Inter quand le sélecteur est examiné, et Inter ne le
couvrant pas, il est simplement écarté.

Le rendu a été mesuré, pas supposé : la ligne du haut est un `Text` ordinaire
avec le repli, celle du bas passe par `EmojiText`.

| | ❤️ | ⚠️ | 🇫🇷 | 👍🏽 |
| --- | --- | --- | --- | --- |
| repli seul | **noir** | **noir** | couleur | couleur |
| police principale | rouge | jaune | couleur | couleur |

#### `EmojiText` — la police d'emojis en **principale**

D'où `core/widgets/emoji_text.dart` : le texte est découpé en suites, et les
suites d'emojis reçoivent `fontFamily: 'NotoColorEmoji'` en police
**principale**, `fontFamilyFallback` vidé — le laisser rouvrirait la porte
qu'on ferme. Le repli du système reste en dernier recours : une grappe mal
classée s'affiche, elle ne devient pas un carré vide.

**Le découpage se fait par grappe de graphèmes** (`String.characters`), jamais
par point de code : un drapeau, une famille, un ton de peau ou une séquence à
sélecteur sont plusieurs points de code qui doivent rester ensemble, faute de
quoi la ligature `GSUB` ne se forme pas et `🇫🇷` sort en deux lettres carrées.

Trois règles décident, et **aucune ne suffit seule** :

| Règle | Ce qu'elle rattrape |
| --- | --- |
| la grappe porte `U+FE0F` | `❤️` du clavier — la règle qui manquait |
| la grappe porte `U+20E3` | `1️⃣`, l'enceinte des touches |
| `Emoji_Presentation=Yes` | `😀`, `👍`, les drapeaux — et `⬜`, seul cas qu'Inter couvre sans sélecteur |

`❤` **sans** sélecteur reste du texte, et le cœur noir d'Inter est alors le
rendu juste — c'est ce que dit Unicode. De même, `©` au fil d'une phrase reste
un copyright, et `1` reste un chiffre.

Les plages d'`Emoji_Presentation` sont relevées sur `emoji-data.txt` de l'UCD,
pas devinées.

**Un texte sans emoji ne construit aucun span** : `EmojiText` se réduit alors à
un `Text`, et un emoji seul aussi. Ce n'est pas qu'une économie — `Text.rich`
avec des enfants échappe à `find.text`, et n'y recourir que pour les chaînes
vraiment mixtes garde les tests et l'arbre de sémantique intacts.

**Le champ de saisie a son contrôleur**, `EmojiTextEditingController` :
`TextField` ne prend qu'un `style` unique, et le découpage doit donc se faire
dans le contrôleur. Sans lui, l'emoji serait noir dans le champ puis coloré
dans la bulle — les deux étant à l'écran en même temps.

**Règle pour la suite : tout texte saisi par quelqu'un s'affiche par
`EmojiText`.** Le texte de l'application, lui, reste un `Text` — il n'y a pas
d'emoji dans les libellés de Jelvo, et c'est déjà une règle ailleurs.

### Une couleur par personne — `SpeakerAccent`

Huit teintes dérivées d'un identifiant, pour le nom d'un expéditeur au-dessus
de ses bulles. Même mécanisme que `GroupAccent.forId` — somme de contrôle
stable, jamais `String.hashCode` — mais **pas la même palette** : celle des
groupes est faite pour des aplats, et son `warning` ne donne que 1,90:1 sur le
fond de l'application. Voir « Une couleur par personne » sous le chat.

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
| `EmojiText` / `EmojiTextEditingController` | **tout texte saisi par quelqu'un** : les emojis y reçoivent leur police en principale |

**Les composants de `core/widgets` ne connaissent pas le domaine** : ils
prennent des `String`, `IconData`, `Color` et `AvatarData`, jamais un `Group` ou
un `CalendarEvent`. La conversion domaine → composant se fait dans les widgets
de feature (voir `avatarsForContactIdsProvider`).

---

## Le thème sombre

Trois choix — **Clair**, **Sombre**, **Automatique** —, une ligne « Apparence »
dans les paramètres, et une feuille qui applique le choix **sur place** : une
apparence se juge en la voyant, un bouton « Enregistrer » obligerait à valider
à l'aveugle.

### Le réglage vit sur l'appareil, pas sur le compte

`profiles` pourrait le porter. Il ne le porte pas, parce que l'apparence dépend
de l'écran qu'on a sous les yeux : sombre le soir sur le téléphone, clair sur
l'ordinateur du bureau. Un réglage de compte imposerait le même aux deux.

`ThemeStorage` reprend donc la brique de `SessionPersistence` et
d'`OnboardingStorage` — un `LocalStorage` de gotrue détourné, sous la clé
`jelvo-apparence`. Ce qui est écrit est un **mot** (`clair`, `sombre`,
`systeme`) et non un rang : un index se décalerait le jour où Flutter
ajouterait une valeur à `ThemeMode`, et l'appareil se réveillerait dans une
apparence qu'il n'a jamais choisie.

### Lu avant `runApp`, sinon ça clignote

`main()` charge le réglage **avant** `runApp`, comme la session et le drapeau
de bienvenue. Sans cela, l'application s'ouvrirait en clair puis basculerait à
la première image — et un clignotement ne se rattrape pas après coup.

### Sur le web, « avant `runApp` » est déjà trop tard

Deux choses sont décidées par le navigateur **avant qu'une ligne de Dart ne
tourne** : le fond de la page, et la couleur du bandeau de la barre d'état.
D'où un flash blanc à l'ouverture et un bandeau resté blanc sous une
application sombre. Aucun code Dart, si tôt soit-il, ne peut les corriger : il
arriverait après.

`web/index.html` les règle donc lui-même, en lisant le réglage enregistré sur
l'appareil **avant le premier pixel**.

#### Il lit la même clé, et il n'y a pas de mémoire parallèle

Sur le web, `SharedPreferencesLocalStorage` n'emprunte pas
`shared_preferences` : il écrit directement dans `localStorage`, sous la clé
telle quelle (`jelvo-apparence`) et avec le mot tel quel. La page lit donc
exactement ce que `ThemeStorage` écrit — pas une copie tenue à jour en
parallèle, qui aurait fini par diverger.

Un repli lit `flutter.jelvo-apparence` en retirant les guillemets, au cas où ce
stockage repasserait un jour par `shared_preferences`, qui préfixe et encode en
JSON. Sans lui, le défaut serait **muet** : le réglage ignoré au démarrage,
donc le clignotement de retour, et rien pour le relier à sa cause.

#### Une seule implémentation de la règle, et elle est en JavaScript

La page expose `window.jelvoAppliquerApparence(mot)`. Elle l'appelle au
démarrage avec la valeur lue ; l'application l'appelle ensuite à chaque
changement de réglage, par `lib/data/pont_navigateur.dart` — une **interface**
derrière un import conditionnel, talon hors du web, même mécanique que
`push_service`. Une interface et non deux fonctions libres, pour la même
raison que les dépôts : sans elle, rien ne prouverait que le crochet se
déclenche, et un crochet muet ne se constate que sur l'appareil de quelqu'un.
**Dart ne fait que passer le mot** : réécrire la règle de son côté, ce serait deux
implémentations à tenir d'accord, et l'écart se verrait en clignotement.

Les trois mots — `clair`, `sombre`, `systeme` — sont donc un **contrat**, et
`ThemeStorage.jeton` en est la source. Tout autre mot est ramené à `systeme` :
un stockage abîmé ne doit pas décider d'une apparence.

Trois recopies subsistent dans la page, inévitables puisqu'elle est servie
avant tout Dart : la clé, les trois mots, et les deux fonds. Aucune ne
protesterait en devenant fausse — d'où `test/launch_screen_test.dart`, qui les
confronte à `ThemeStorage` et à `JelvoColors`.

#### Le bandeau prend le fond, pas le violet de la marque

`theme-color` valait `#5B2EFF`. Le bandeau **continue l'écran** : il prend donc
`background`, et le violet ne prolongeait aucun écran, dans aucune des deux
apparences.

Deux déclarations avec `media` couvrent le mode Automatique **sans script**, et
continuent de suivre le téléphone si son réglage change en cours de route. Un
choix explicite les remplace par une seule — et repasser en Automatique doit
les **rendre**, ce pour quoi elles sont rebâties de zéro à chaque appel.

**`theme-color` n'est pas lu par l'application iOS ajoutée à l'écran
d'accueil.** C'est `apple-mobile-web-app-status-bar-style` qui décide là-bas, et
sa valeur par défaut `default` donne précisément un bandeau blanc à texte
sombre. Elle n'accepte aucune requête de média : en Automatique, le script
résout lui-même et pose `black` ou `default`.

#### Depuis iOS 26, le bandeau se règle par le fond, et plus par une méta

**Et c'est ce qui l'a enfin fait suivre à chaud.** Le correctif précédent
écrivait dans `apple-mobile-web-app-status-bar-style` à chaque changement de
réglage — le crochet s'exécutait, la valeur était juste, et le bandeau ne
bougeait pas jusqu'à ce qu'on quitte et rouvre. La raison tient en une phrase :
**iOS lit cette méta au lancement et ne la relit jamais.**

Sauf qu'à partir d'iOS 26, WebKit ne la lit plus du tout, et ne lit pas
davantage `theme-color` : il **échantillonne le fond de la page** (bug WebKit
301756). Ce qui ferme une porte en ouvre une autre, puisqu'un fond, lui, se
change à l'exécution.

Encore faut-il qu'il y ait un fond à échantillonner. `--jelvo-fond` peint bien
l'écran, mais **une variable CSS ne se lit pas de l'extérieur du document**, et
une fois Flutter démarré le fond visible est sa toile, qui ne porte aucune
couleur CSS. `jelvoAppliquerApparence` pose donc la teinte **en clair** sur
`html` et sur `body`, à chaque appel.

Mesuré dans un navigateur, sur les deux réglages de téléphone : une bascule
vers « Sombre » donne `html` et `body` à `rgb(14, 14, 26)`, et repasser en
« Automatique » rend les deux déclarations `media` **et** résout le fond sur le
réglage du téléphone.

| Version d'iOS | Ce qui décide du bandeau | À chaud |
| --- | --- | --- |
| **26 et au-delà** | le fond de la page | **oui**, c'est le correctif |
| 25 et avant | `apple-mobile-web-app-status-bar-style` | **non** — lue au lancement, jamais relue |

Les deux mécanismes sont donc écrits, et la méta reste posée pour les versions
qui n'ont que lui. Sur celles-là, **il n'y a pas de correctif** : le seul
contournement, `black-translucent`, impose un texte de barre d'état *toujours
blanc*, illisible sur le fond clair. C'est une limite, pas un défaut en
attente.

#### Un seul écran de lancement, et il attend que l'accueil ait son contenu

Un voile plein écran, le logo fourni au centre, le fond du thème, retiré en
fondu de 240 ms — puis **retiré du document** : laissé en place, un voile
transparent avalerait les touches.

Deux choses ont demandé plus qu'un voile, et toutes deux se voyaient à
l'ouverture.

**Il y en avait deux.** Une application ajoutée à l'écran d'accueil affiche
d'abord un écran de lancement d'iOS, puis celui de la page : le logo changeait
de taille entre les deux.

Le premier correctif a été de photographier l'écran de la page **à la taille
exacte de douze iPhone** — vingt-quatre fichiers — pour faire coïncider les
deux tailles. **Il n'a pas tenu**, et le défaut était dans l'approche, non
dans la liste : iOS n'accepte que des dimensions exactes, une taille absente
retombe en silence sur ce que le système décide, et Apple sort des tailles
chaque année. Une liste de modèles est en retard par construction.

**Ce qui l'a réglé, c'est qu'un seul endroit dessine le logo.** Deux tailles à
faire coïncider, c'était déjà le problème ; il suffit qu'il n'y en ait qu'une.
Le voile de la page est désormais seul à porter le logo — et il garde la plus
grande des deux tailles, 96 px —, tandis que les images de lancement se
réduisent à **un aplat de la couleur de fond, un par apparence**.

Un aplat n'a pas de géométrie : iOS peut l'étirer, le rogner ou le centrer,
cela ne se voit pas. Il ne reste donc qu'une **proportion** à viser — 19,5:9,
celle des iPhone depuis l'iPhone X — et plus aucune taille à manquer. Leur
seul rôle est d'épargner le blanc que Safari affiche sinon pendant que la page
charge : **rien ne dépend d'eux**, et si iOS refusait une image sans requête
de taille, le logo resterait unique de toute façon.

Deux fichiers au lieu de vingt-quatre, 30 Kio au lieu de 2,5 Mio, et plus de
navigateur dans le générateur — `tool/preparer_ecrans_de_lancement.js` écrit
les deux PNG à la main, en lisant les teintes dans `web/index.html` pour ne
pas en devenir une troisième source. Voir `web/splash/README.md`.

**Ce qui reste, et qu'aucune page ne peut reprendre** : la transition
d'ouverture d'iOS, l'icône de l'écran d'accueil qui grandit jusqu'au cadre de
l'application. Elle existe pour toute application, native comprise.

**Et sur un iPhone, remplacer ces fichiers ne suffit pas à voir le
changement** : iOS fige les métadonnées de l'application installée, comme il
fige son icône. Il faut retirer l'icône de l'écran d'accueil et réinstaller —
ce qui détruit l'abonnement push. C'est la première chose à vérifier si le
logo saute encore.

**Il partait trop tôt.** Il s'effaçait sur `flutter-first-frame`, or à cet
instant l'accueil est construit mais ses quatre lectures sont en vol. Et comme
`ref.watch(x).value ?? const []` rend une liste vide pendant le chargement,
**un écran qui lit est indiscernable d'un écran vide** : l'accueil s'affichait
avec « Aucun groupe pour le moment » et « Journée libre », puis se remplissait.
Ce n'était pas une redirection — la redirection de GoRouter est synchrone et
aucune route par défaut n'est construite en attendant, c'est mesuré — c'était
l'accueil d'un compte neuf, sur le compte de quelqu'un qui a quatre groupes.

C'est donc **l'application qui dit quand effacer**, par
`applicationPreteProvider` (`lib/demarrage.dart`) : sans session, tout de
suite — la bienvenue et la connexion ne lisent rien ; avec session, quand les
quatre lectures de l'accueil ont **répondu**. Répondu, et non réussi : une
erreur vaut un contenu, sans quoi quelqu'un hors ligne resterait devant un logo
sans jamais rien apprendre.

Deux filets, et ce sont des filets, pas le mécanisme : **deux secondes après la
première image**, puis dix secondes dans l'absolu. Un accueil encore vide vaut
mieux qu'un logo qui s'éternise, et un voile posé sur une application pourtant
chargée serait bien pire que le clignotement qu'il corrige.

Mesuré dans un vrai navigateur : première image à ~1,0 s, voile retiré à
~2,1 s sur le signal ; avec les lectures retardées d'une seconde et demie,
c'est le filet des deux secondes qui tranche.

#### Ce qui ne suit toujours pas le réglage

| Surface | Pourquoi |
| --- | --- |
| le bandeau d'un iPhone **sous iOS 25 ou avant** | `apple-mobile-web-app-status-bar-style` est lue **au lancement** et jamais relue. Le crochet s'exécute, la valeur est juste à la réouverture suivante, et iOS ne la réapplique pas en cours de route. Sur iOS 26 et au-delà, le fond de la page prend le relais — voir la section précédente |
| la **transition d'ouverture** d'iOS | l'icône de l'écran d'accueil qui grandit jusqu'au cadre de l'application appartient au système, et existe pour toute application, native comprise |
| splash de la PWA installée sur **Android** | `manifest.json` ne porte ni requête de média ni variante sombre, et Chrome n'accepte pas d'image de lancement. La page reprend la main dès qu'elle est chargée |
| écrans de lancement **natifs** Android et iOS | ils vivent dans `android/` et `ios/`, hors de la chaîne web, et ces deux cibles ne sont pas compilables ici |
| un **choix explicite** contraire au téléphone | l'aplat de lancement est choisi par `prefers-color-scheme`, donc par le réglage du téléphone : « Clair » choisi sur un téléphone sombre donne un lancement sombre puis une application claire |

### La palette

Elle vit dans `core/theme/jelvo_colors.dart`, en deux exemplaires bâtis par la
**même** fonction de thème. Le détail des jetons, la raison de la
`ThemeExtension`, ce qui ne suit pas le thème et ce qui a changé côté clair
sont documentés sous « Couleurs » du design system.

### Ce qui a demandé plus qu'un changement de couleur

| Endroit | Ce qu'il a fallu |
| --- | --- |
| `AgendaEntry` | il portait une `Color` choisie **dans un provider**, sans contexte : il porte un `AgendaAccent` et le widget en tire la teinte |
| `StatusTone`, `GroupAccent`, `SpeakerAccent`, `CreationKind`, `NotificationType`, `CategoryState`, `DayMarker` | sept énumérations portaient des couleurs en `const` ; elles rendent désormais un rang ou prennent la palette |
| bulles de conversation | quatre jetons à elles — `primary` devenant clair en sombre, du texte blanc dessus serait tombé à 2,9:1 |
| bandeaux photo | voile noir fixe et pastilles blanches fixes : une photographie n'a pas d'apparence |
| `PrimaryButton`, `NavBadge`, `TaskRow`, la barre de navigation… | le blanc posé sur un aplat de marque devient `onAccent` : en sombre l'aplat est clair |
| `AppCard`, `EventCard`, `GroupCard`, `NavBadge` | leurs valeurs par défaut lisaient la palette dans la liste de paramètres, où le contexte n'existe pas : elles passent à `null`, résolu au `build` |

### Les images

| Image | Sur fond sombre |
| --- | --- |
| logo (`web/icons/Icon-192.png`) | **opaque**, carré violet à monogramme blanc : il porte son propre fond et tient des deux côtés |
| `assets/illustrations/bienvenue.png` | fond transparent, sujet coloré et de luminance moyenne (112/255) : il tient. Deux pertes mineures — les cheveux et les contours très sombres se fondent au bord de la silhouette, et les confettis bleu foncé disparaissent |
| avatars prédéfinis | 22 % de transparence au pourtour, mais ils sont toujours posés **sur un disque d'accent** : le fond de l'écran ne les touche pas |
| photos de couverture | fournies par l'utilisateur : le voile noir et les pastilles blanches gardent le titre lisible, mais une photo déjà sombre donne une carte moins contrastée qu'en clair |


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
| `profiles` | …, **`anniversaire_jour`**, **`anniversaire_mois`** — jour et mois sans année, renseignés ensemble ou pas du tout |
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

#### Trois fichiers sont **gelés**, et les modifier casse la livraison

`tranche2_groupes_et_invitations.sql`, `correctif_invitations_type.sql` et
`tranche3_taches_et_evenements.sql` **ne sont plus rejouables**. Une tranche
ultérieure a redéfini certaines de leurs fonctions avec une signature
différente, précédée d'un `drop function` : leur `create or replace` tente
donc de revenir en arrière, et PostgreSQL refuse.

| Fichier gelé | Fonctions reprises plus tard |
| --- | --- |
| `tranche2_groupes_et_invitations.sql` | `apercu_groupe_par_jeton`, `inviter_dans_groupe`, `mes_invitations`, `mes_contacts` |
| `correctif_invitations_type.sql` | `inviter_dans_groupe`, `mes_invitations` |
| `tranche3_taches_et_evenements.sql` | `mes_taches`, `mon_agenda` |

**Le rejeu par empreinte rend le piège silencieux jusqu'à la fusion.** Un
fichier n'est rejoué que si son contenu change ; tant qu'on n'y touche pas,
rien ne se produit. Le jour où on y ajoute une ligne — un filtre d'une ligne a
suffi —, il est rejoué et échoue :

```
ERROR:  cannot change return type of existing function
HINT:  Use DROP FUNCTION apercu_groupe_par_jeton(text) first.
```

Et comme **chaque fichier est appliqué dans sa propre transaction**, le
fichier gelé reste intact : ce qui se perd, c'est **tout ce qui le suit dans
le manifeste**. C'est arrivé le 21 novembre 2026, à la fusion de la
tranche 14 : la colonne est passée, la tranche 2 a échoué, et les tranches 5c,
9, 13, 14 et 7 n'ont jamais été appliquées. L'application, elle, était
déployée — **un bouton de suppression de compte que la base ne servait pas**.

Le rejeu local ne pouvait pas le voir, et ce n'est pas un oubli du décor :
`rejouer.sh` part d'un catalogue **vide**, où la tranche 2 s'applique avant la
tranche 6 et n'a donc rien à défaire. Le défaut n'existe que contre une base
déjà à jour — c'est exactement la limite déjà écrite pour la traduction des
notifications, rencontrée cette fois dans l'autre sens.

**Règle** : pour changer une fonction d'un fichier gelé, la **redéfinir dans
un fichier postérieur**. Le propriétaire d'une fonction est le **dernier**
fichier qui la crée, pas le premier — c'est la même règle que pour
`messages_du_groupe`, qui vit dans la tranche 5a et appartient à la tranche 9.
Le filtre de `chercher_profils_par_pseudo` vit donc dans la tranche 14.

`tool/pieges_migrations.py` tient la liste **en partant du code** : il relève
les fonctions définies dans plusieurs fichiers et signale celles dont un
définisseur postérieur porte un `drop`. À lancer avant de toucher à une
migration. Il ne fait pas échouer la CI : ces fichiers sont gelés par
construction, et le rester est l'état normal — un contrôle rouge en permanence
ne serait plus lu.

**L'ordre du fichier n'est pas celui des numéros**, et ne peut pas l'être :
`tranche7_durcissement.sql` referme l'exécution de toute fonction absente de sa
liste et **lève si un nom de sa liste n'existe pas en base**. Il reste donc le
dernier passage, et les tranches 8 à 16 s'insèrent avant lui.

**Et la tranche 16 précède la tranche 13**, bien que son numéro soit plus
grand : `profil_consultable` appelle `bloque()` pour ne plus rien rendre sur
une personne bloquée. Elle est en `plpgsql`, dont le corps n'est pas validé à
la création, si bien que l'ordre inverse *marcherait* — c'est précisément
pourquoi il a été écarté. **Ne rien faire dépendre de la validation
paresseuse** : la dépendance est réelle, et l'ordre du manifeste doit la dire
plutôt que de la laisser tenir par accident.

Trois fichiers **précèdent** au contraire tout le reste, et pour la même
raison : ils ajoutent une colonne ou une valeur d'énumération que des fonctions
en `language sql` — dont PostgreSQL valide le corps à la création —
mentionnent. `colonne_avatar_predefini.sql` ouvre le manifeste,
`colonne_compte_supprime.sql` le suit — `messages_du_groupe`, `nom_affiche` et
`chercher_profils_par_pseudo` lisent `supprime_le` —, et
`colonne_media_audio.sql` se place juste avant `tranche5a_chat.sql`.

Quatre entrées de `supabase/` ne sont **pas** des migrations.

| Entrée | Rôle |
| --- | --- |
| `diagnostic_invitation.sql` | rejoue l'invitation nominative sous `authenticated`, dans une transaction annulée |
| `diagnostic_taches_evenements.sql` | même chose pour les tâches et les événements, précédé de l'audit du schéma (PARTIE A) |
| `designer_moderateur.sql` | la ligne qui désigne un modérateur, à passer une fois. **Hors du manifeste parce que le dépôt est public** : elle porterait une adresse ou un identifiant — voir « Signaler un abus » |
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
défaut. Ils sont donc **neuf** depuis la tranche 12, et le test de fumée le
vérifie — avec un nombre écrit à la main, pour qu'ajouter un type oblige à
passer par là et à se demander dans quelle famille il va.

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
| `messages` | `id`, `group_id`, `sender_id`, `content`, `media_url`, `media_kind`, **`media_duree_s`**, `created_at`, `deleted_at`, **`task_id`**, **`event_id`**, **`tache_prise`** | `CHECK (content is not null or media_url is not null)`, contenu ≤ 2000 |
| `message_reactions` | `message_id`, `user_id`, `emoji` — **PK `(message_id, user_id)`** | une réaction par personne et par message, **tenu par la base** |
| `message_reads` | `group_id`, `user_id`, `last_read_at` — **PK `(group_id, user_id)`** | l'accusé de lecture est **par conversation**, jamais par message |

`media_type` ne connaît que `image`, `video` et `audio` : c'est **le type**, et
non une règle d'écran, qui interdit les documents. `audio` est arrivé avec les
messages vocaux — voir plus bas ; les deux autres sont du schéma initial.

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

### L'écran, rapproché de la maquette

Quatre pièces, dont trois n'existaient pas : l'en-tête, la barre de raccourcis,
les séparateurs de date. Les réactions en pastille et la coche de lecture,
elles, étaient là depuis la tranche 5a.

| Pièce | Ce qu'elle porte |
| --- | --- |
| `ChatHeader` | retour, photo du groupe, nom, effectif |
| `ChatShortcutBar` | tâches en cours, événements à venir, chevron vers le groupe |
| `ChatDayDivider` | « Aujourd'hui », « Hier », puis la date |
| `ChatActionsSheet` | ce que propose le « + » |

**Ni téléphone ni caméra dans l'en-tête.** La maquette pose deux pictogrammes
d'appel : Jelvo n'a ni appel audio ni appel vidéo — aucune table, aucun
service, aucun écran. Les laisser en gris promettrait une fonctionnalité qui
n'arrive pas ; les laisser actifs ouvrirait sur du vide. Même règle pour les
listes, les dépenses et les notes de la feuille du « + » et de la barre de
raccourcis, écartées comme elles l'ont été de l'écran du groupe.

**Les deux compteurs ne coûtent aucune lecture.** `mes_taches` et `mon_agenda`
sont déjà chargées sans bornes de dates et portent `group_id` :
`groupOngoingProvider` filtre en mémoire, et c'est le **même** provider qui
alimente la ligne d'activité d'une carte de groupe. Deux calculs parallèles
finiraient par afficher deux comptes différents de la même chose.

**Zéro ne se dit pas**, ici comme sur la carte d'un groupe : « 0 tâche ·
0 événement » se lit comme un défaut de chargement. Une moitié vide s'efface,
un groupe sans rien annonce « Rien de prévu pour l'instant » — et le chevron
reste, la barre étant aussi un chemin.

#### On dépile pour aller au groupe, on n'empile pas

La conversation est posée sur le **navigateur racine**
(`parentNavigatorKey: _rootNavigatorKey`), au-dessus de l'écran du groupe, qui
vit dans la branche Groupes. Y pousser une seconde fois `/groupes/<id>` met
deux fois la même page dans la pile, ce que Flutter refuse net :

```
'!keyReservation.contains(key)': is not true.
```

`_ouvrirLeGroupe` dépile donc, et ne se rabat sur `goNamed` que si rien n'est
dépilable — le cas d'une arrivée directe par notification. La règle vaut pour
tout écran empilé sur la racine qui voudrait « revenir » à son parent.

#### Le séparateur coiffe la journée, et recoupe la série

La liste est **inversée** : le message d'indice supérieur est le précédent dans
le temps. Le séparateur se pose donc au-dessus du premier message d'une
journée, ce qui, dans une liste inversée, veut dire *après* lui dans la
colonne — d'où le `Column` qui les emballe tous les deux.

Un changement de jour **coupe la série** au même titre qu'une carte : le nom de
l'expéditeur se relit sous le séparateur, et son avatar se repose au-dessus.
Sans cela, la journée du dessous commencerait sans dire qui parle.

Le libellé vient d'`AppDates.relativeDay`, celui qu'emploient déjà le
calendrier et l'accueil. Une seconde façon de nommer les jours aurait fini par
diverger de la première.

### Une couleur par personne, pour son nom seulement

**Les bulles ne changent pas de couleur** : violet pour soi, blanc pour les
autres. Ce qui change, c'est le **nom** au-dessus des bulles des autres, qui
prend une teinte dérivée de l'identifiant de son auteur — dans un groupe de
huit, le gris uniforme obligeait à lire le nom pour savoir qui parle.

**Les accents de groupe n'étaient pas transposables tels quels.** Ils sont
faits pour des aplats et des vignettes, pas pour du texte de 13 :

| Accent | Contraste sur `#F7F7FB` |
| --- | --- |
| `warning` | 1,90:1 |
| `success` | 3,12:1 |
| `danger` | 3,66:1 |

WCAG demande **4,5:1** pour du texte courant. `SpeakerAccent`
(`core/theme/speaker_accent.dart`) reprend donc le mécanisme — même somme de
contrôle stable que `GroupAccent.forId`, jamais `String.hashCode`, qui change
d'une exécution à l'autre — avec huit teintes assombries qui passent toutes la
barre, de 5,48:1 à 9,51:1.

### Le sélecteur d'emoji est une liste, pas un paquet

Les paquets de sélecteur embarquent leur propre police et leur propre
catalogue, c'est-à-dire une **seconde source de vérité** pour un rendu que
`NotoColorEmoji` assure déjà. Ce qu'il faut ici tient dans une liste : six
familles, quelques centaines de glyphes.

Le catalogue est volontairement **court**. Un sélecteur complet compte plus de
trois mille emojis et demande une recherche pour être utilisable ; celui qu'on
ouvre dans une conversation de famille sert à répondre vite, et le clavier du
système reste là pour le reste — c'est lui qui a la recherche.

L'emoji s'insère **là où est le curseur**, et non à la fin : on en pose souvent
un au milieu d'une phrase déjà écrite. Ouvrir le panneau referme le clavier
système : les deux occupent le même bas d'écran.

### Messages vocaux

Enregistrement depuis la barre de saisie, envoi dans `chat-media` — le bucket
existant —, lecture dans la bulle avec la durée.

#### Le format n'est pas le même partout, et ne peut pas l'être

Sur le web, l'enregistrement passe par `MediaRecorder`, dont les formats
dépendent du navigateur, et de sa version :

| Navigateur | Ce qu'il sait enregistrer |
| --- | --- |
| Safari, iOS compris | AAC dans un conteneur MP4 (`.m4a`) |
| Chrome, Edge | Opus en WebM ; AAC en MP4 sur les versions récentes |
| Firefox | Opus en WebM, ou Ogg |

Imposer un format unique reviendrait donc à priver une famille de navigateurs
de la fonctionnalité. L'encodeur est **négocié** par `isEncoderSupported`, AAC
d'abord : c'est le seul que Safari écrit *et* lit, et il se lit partout
ailleurs. L'extension suit l'encodeur retenu, et c'est elle qui décide du type
MIME à l'envoi — un `.webm` annoncé `audio/mp4` ne se lirait nulle part.

Trois limites du navigateur, qu'aucun code ne contourne :

- **le refus du micro est définitif** côté application, l'API ne permettant pas
  de redemander. L'écran renvoie aux réglages du navigateur, comme pour les
  notifications système ;
- **il faut un geste de l'utilisateur** pour ouvrir le flux : rien ne peut
  déclencher un enregistrement depuis une minuterie ;
- **Safari n'accorde le micro qu'en HTTPS**, ou sur `localhost`.

Côté natif, `RECORD_AUDIO` est déclarée dans le manifeste Android et
`NSMicrophoneUsageDescription` dans l'`Info.plist` : sans elles, le système
refuse **avant** que l'autorisation soit demandée.

#### La durée est une colonne, pas une lecture de fichier

`messages.media_duree_s` (`supabase/colonne_media_audio.sql`). La lire dans le
fichier imposerait de le **télécharger** pour l'afficher : une URL signée et un
aller-retour par bulle, avant même que quiconque appuie sur « lire ». Celui qui
enregistre la connaît — elle voyage avec le message.

Elle vient de l'horloge de l'enregistrement et non du conteneur : les fichiers
produits par `MediaRecorder` n'annoncent pas toujours leur durée, et un
« 0:00 » sur un message de vingt secondes serait pire qu'un arrondi.

`envoyer_message` **l'écarte pour tout autre type de média** : une durée posée
sur une photo laisserait une valeur qu'aucune lecture ne saurait interpréter.
Le test de fumée en fait un contrôle négatif.

#### Ce que la valeur `audio` a coûté

`alter type public.media_type add value if not exists 'audio'` vit dans son
propre fichier, **avant** `tranche5a_chat.sql` dans `migrations.txt` — même
raison que `colonne_avatar_predefini.sql` : `messages_du_groupe` est en
`language sql`, dont le corps est validé à la création, et un `returns table`
citant une colonne absente ne se crée pas.

**`appliquer.sh` applique chaque fichier dans une transaction**, et depuis
PostgreSQL 12 un `alter type … add value` y est accepté. Ce qui reste interdit,
c'est d'**employer** la nouvelle valeur avant la validation : le fichier ne
fait que l'ajouter, et les fonctions qui la manipulent sont appliquées ensuite,
donc dans d'autres transactions.

Deux signatures ont dû changer, et aucune ne pouvait l'être par `create or
replace` : `envoyer_message` gagne un paramètre — ce serait une **surcharge**,
et PostgREST, qui appelle par noms d'arguments, n'aurait pas de quoi trancher —
et `messages_du_groupe` une colonne de sortie. Les deux fichiers reposent leur
propre `grant execute` après le `drop`, sans quoi la tranche 7 — qui ne se
rejoue que si elle change — les laisserait fermées.

#### Pas de forme d'onde

Les barres qu'on voit ailleurs représentent l'**amplitude** du son, que rien
n'enregistre ici. Les dessiner au hasard donnerait un motif décoratif qui
*ressemble* à une donnée sans en être une — la même règle que la pastille de
présence écartée du profil. Une barre de progression dit ce qu'elle sait : où
l'on en est.

#### Un seul lecteur pour toute la conversation

Ce n'est pas une économie de mémoire, c'est la règle voulue : deux messages
vocaux qui parlent en même temps ne s'écoutent ni l'un ni l'autre. L'état vit
dans `voicePlaybackProvider` et non dans chaque bulle ; lancer le second arrête
donc le premier sans que rien n'ait à s'en occuper.

`VoiceRecorder` et `VoicePlayer` sont des **interfaces**, pour la même raison
que les dépôts : un test de widget n'a ni micro ni haut-parleur, et `record`
comme `just_audio` y lèveraient sur un canal de plateforme absent.

#### Les bornes

Deux minutes (`AppConfig.chatVoiceMaxDuration`), 32 kbit/s en mono — environ
480 kio, très en deçà des 25 Mio du bucket : c'est bien la durée, et non le
poids, qui borne. L'enregistrement **s'arrête tout seul** au terme : une borne
annoncée et tenue vaut mieux qu'un envoi refusé une fois la parole dite. En
deçà de 0,7 seconde, rien ne part — c'est un doigt qui a glissé, pas un
message.

Les types MIME sonores ont été ajoutés à `chat-media` dans la tranche 7 :
`audio/mp4`, `audio/aac`, `audio/mpeg`, `audio/webm`, `audio/ogg`. La borne
côté serveur est la seule qui protège de plus qu'une requête depuis
l'application.

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
| `chat_message` | Famille | `Julie Martin : On fait un barbecue ?` — ou `a envoyé une photo` / `une vidéo` / `un message vocal` |
| `group_invitation` | Famille | `Julie Martin vous invite dans le groupe` |
| `event_invitation` | Famille | `Julie Martin vous convie à Randonnée du lac Blanc` |
| `task_assigned` | Famille | `Julie Martin vous a confié : Réserver le restaurant` |
| `event_response` | Famille | `Randonnée du lac Blanc — Julie Martin vient` |
| `event_changed` | Famille | `Randonnée du lac Blanc déplacé au 24/08 à 19:30` |
| `reminder` (tâche) | Famille | `Rappel — Réserver le restaurant` |
| `task_response` | Famille | `Léa Marchand accepte : Réserver le restaurant` |
| `reminder` (événement) | Amis | `Rappel — Randonnée du lac Blanc à 09:00` |
| `birthday` | Julie Martin | `fête son anniversaire aujourd'hui` |

Trois conventions cohabitaient avant : le nom du groupe pour les messages, le
titre de l'événement pour les réponses et les changements de date, un mot de
catégorie — « Invitation », « Nouvelle tâche », « Rappel » — pour le reste.
L'empilement se lisait mal et ne se triait pas d'un coup d'œil.

**`birthday` est la seule exception, et elle ne contredit pas la règle.** Un
anniversaire n'appartient à aucun groupe : son titre porte donc le **nom de la
personne**. Ce que la règle demande, c'est que le titre dise de quel coin de sa
vie vient la notification — et pour un anniversaire, ce coin *est* la personne.
Ce qu'elle interdit reste interdit : « Anniversaire » comme titre serait un mot
de catégorie, et c'est précisément ce qui a été écarté.

**Conséquence à tenir pour tout nouveau type** : le corps doit **nommer
l'élément**, puisque le titre ne le fait plus. Le test de fumée éprouve les
deux moitiés de la règle sur `event_invitation` — le titre vaut le nom du
groupe, le corps contient celui de l'événement.

Les corps du tableau ci-dessus sont ceux du **repli français**. Depuis la
traduction, chaque dépôt pose en outre une clé et des paramètres, rendus dans
la langue de l'appareil — voir « Les notifications système aussi, mais pas par
l'ARB » sous Internationalisation.

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

#### Le déploiement de la fonction a échoué en silence pendant trois mois

**Constaté le 20 novembre 2026, et c'est le défaut le plus coûteux de cette
famille.** `fonctions-supabase.yml` échouait à chaque fusion depuis le
23 août, sur une ligne qui n'a rien à voir avec le code :

```
Confirmation required: Deploy 1 Function. This run can't ask because
stdout is not a terminal. Nothing was changed.
Re-run with --yes to confirm.
```

La CLI a **ajouté une confirmation interactive** après le 19 août, et le
workflow installe `version: latest`. Il n'y avait donc rien à changer dans le
dépôt pour que le déploiement cesse de marcher : il a suffi que la CLI bouge.

Ce que cela a coûté, et qui ne se voyait nulle part :

| Ajouté à la fonction | Depuis | Appelé ? |
| --- | --- | --- |
| `empiler_rappels()` | 19 août | **oui** — déjà dans la version 9 |
| vidange de `push_outbox` | 19 août | **oui** |
| `appliquer_adhesions_echues()` | 23 août (tranche 6) | **non, jamais** |
| `empiler_anniversaires()` | 20 novembre (tranche 12) | **non** |

L'adhésion temporaire **révoquait bien l'accès** — ce sont les prédicats SQL
qui le font, et ils n'ont jamais eu besoin du battement. Ce qui ne s'est
jamais produit, c'est la seconde moitié : le *rangement* derrière l'adhésion
échue, décrit sous « Ce qui se passe tout seul, et ce qui demande une
écriture ». Le premier passage après déploiement rattrapera l'arriéré.

Trois leçons, et la troisième est la seule qui se code :

- **la version de la fonction est une donnée à vérifier**, pas à déduire d'une
  fusion. `updated_at` et `version` de l'API Supabase la donnent ; ici elles
  disaient « 19 août, version 9 » alors que six fusions avaient suivi ;
- **un workflow rouge qui ne bloque rien d'autre ne se remarque pas.** Le
  déploiement web était vert, l'auto-merge fonctionnait, les migrations
  passaient : rien ne tirait l'œil vers celui-ci. Le vert d'un workflow ne dit
  rien d'un autre ;
- **`version: latest` sur un outil tiers est une rupture à retardement.**
  `--project-ref` est déjà déprécié au profit de `--remote=<ref>` et sera
  retiré en v4 : ce sera la prochaine, et elle aura la même tête.

##### Et `--yes` n'a pas suffi : un second défaut attendait derrière

**Constaté le 21 novembre 2026, et c'est la suite directe de l'histoire
ci-dessus.** Le `--yes` posé la veille a bien réglé la confirmation
interactive — et le job est resté rouge, pour une raison entièrement
différente :

```
Confirmed by --yes: Deploy 1 Function on project ***
unexpected list functions status 401: {"message":"Invalid access token"}
```

**`SUPABASE_ACCESS_TOKEN` existe mais est refusé** : il a expiré ou été
révoqué. L'étape « Vérifier les secrets » ne contrôle que leur *présence*,
ce qui est tout ce qu'un workflow peut faire sans appeler l'API — un jeton
mort la passe donc sans bruit.

Vérifié à la source plutôt que déduit : l'API Supabase donne toujours
`version: 9`, `updated_at` au 19 août. **La fonction n'a jamais été déployée
depuis**, et le correctif de la veille n'y a rien changé.

Deux conséquences :

- **la correction précédente a été annoncée trop vite.** « Le correctif tient
  en un mot, `--yes` » était vrai de la première cause et faux du résultat :
  un défaut réparé ne prouve pas que la chaîne marche, seule la **version
  déployée** le prouve. C'est la même erreur de méthode que « migrations en
  échec ne veut pas dire migrations non appliquées », dans l'autre sens ;
- **le jeton ne se répare pas depuis le dépôt.** Seul le propriétaire du
  projet peut le régénérer (Supabase → Account → Access Tokens), et le
  reposer dans les secrets. Ce qui se code, c'est de **nommer le coupable** :
  l'étape de déploiement distingue désormais ce 401, l'annonce en toutes
  lettres dans le résumé du job, et dit que la fonction n'est pas déployée.

Ce que cela coûte aujourd'hui : la traduction des notifications système est
livrée côté base — les clés et les paramètres sont déposés — mais la fonction
en place les ignore et sert le texte français. C'est exactement le repli prévu
pour ce cas, et non une panne.

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

---

## Anniversaires

Jour et mois sur le profil, visibles de qui peut lire le profil ; une
notification le jour même et une ligne de calendrier annuelle, **réservées aux
contacts**. `supabase/tranche12_anniversaires.sql`.

### L'année n'est pas collectée, et la forme l'empêche

Deux colonnes `smallint` — `anniversaire_jour`, `anniversaire_mois` — et non
une `date`. Une `date` exige une année, et **toute année sentinelle est une
valeur que quelqu'un finira par lire comme une année de naissance**, puis par
afficher. Deux entiers rendent l'absence d'année structurelle : il n'y a pas
d'année à ignorer, il n'y en a pas du tout.

C'est aussi pourquoi la saisie n'est pas un `showDatePicker` : il demande une
année et il n'y a aucun moyen de la lui retirer. Deux listes déroulantes
suffisent, et elles ne peuvent pas demander ce qu'on ne veut pas savoir.

Une date de naissance complète associée à un nom sert couramment de question
de sécurité ailleurs. Jelvo n'en a aucun besoin : il lui faut savoir **quand
souhaiter**, pas quel âge.

### Le 29 février n'est pas un cas particulier

Une seule règle couvre tout : **le jour fêté est ramené au dernier jour du
mois**. Un anniversaire du 29 février tombe donc le dernier jour de février —
le 29 les années bissextiles, le 28 sinon.

Le reporter au 1er mars était l'autre option, et c'est celle du droit français
pour la majorité. Elle est écartée ici : elle ferait **changer de mois**, et
« mon anniversaire est en février » cesserait d'être vrai. Un anniversaire
n'est pas un seuil juridique, c'est une date qu'on fête.

La règle vit **à deux endroits**, et ne peut pas vivre à un seul :

| Où | Pourquoi |
| --- | --- |
| `public.jour_anniversaire` | l'envoi du jour, côté base |
| `Anniversaire.jourFete` | le calendrier, qui la calcule pour l'année affichée |

Demander la date à la base pour chaque année qu'on fait défiler voudrait dire
une requête par balayage. Ce qui protège de la divergence, c'est que les deux
soient éprouvées sur **les mêmes dates** — 2024 et 2025, plus 1900 et 2000 côté
Dart —, et un test confronte les deux tables de cas pour que la coïncidence ne
se défasse pas en silence.

### Qui voit quoi, et ce que « tout le monde » veut dire

| Surface | Portée |
| --- | --- |
| la date sur un profil | **aucune restriction propre** : elle est aussi visible que la ligne `profiles` qui la porte, donc soi-même et `has_social_link` |
| la notification du jour | **contacts acceptés seulement** |
| la ligne de calendrier | **contacts acceptés seulement** |

La nuance a son importance. La consigne disait « visible par tout le monde »,
et c'est bien ce que fait le SQL : la colonne n'a pas de politique à elle. Mais
`profiles_select` vaut `id = auth.uid() or has_social_link(id)` depuis la
tranche 7 — **Jelvo n'a ni annuaire ni page publique de profil**, et « tout le
monde » y signifie donc « ses contacts et ses co-membres de groupe ».

Les deux autres surfaces sont, elles, volontairement **plus étroites** que
cela : `anniversaires_de_mes_contacts()` exige une ligne `contacts` acceptée,
dans un sens ou dans l'autre. Un co-membre de groupe qui n'est pas un contact
ne reçoit rien et ne voit rien au calendrier. Le test de fumée en fait un
contrôle négatif.

**Il existe désormais un écran de profil d'autrui** — voir « Le profil de
quelqu'un d'autre » —, et la date s'y lit : c'est l'un des cinq champs que
`profil_consultable` rend à tout compte authentifié, ce que rien côté base ne
restreignait déjà. Elle se lit donc sur son propre profil, sur celui de
n'importe qui, et sur la fiche d'un contact (`ContactActionsSheet`).

### Une personne sans date ne coûte rien

`anniversaires_de_mes_contacts()` **ne renvoie que les contacts qui ont une
date**. L'appelant n'a donc rien à écarter, le calendrier n'a rien à
synthétiser, et c'est le cas par défaut — personne n'a renseigné quoi que ce
soit au départ.

Côté écran, la ligne du profil **invite** au lieu d'afficher un vide. C'est la
différence avec les lignes Téléphone et Localisation, écartées faute de
donnée : ici la donnée existe, elle n'est simplement pas remplie.

### Le battement est celui qui existe déjà

`empiler_anniversaires()` est appelée par `envoyer-push`, dans le **même**
passage que `empiler_rappels()` et `appliquer_adhesions_echues()`. Une seconde
planification serait une seconde cadence à tenir d'accord — le reproche déjà
fait, et retenu, deux fois.

**La mémoire est la clé primaire de `push_reminders_sent`**, dont le `kind`
s'élargit à `birthday` comme `push_tokens.platform` s'était élargi à `web`. Pas
de table de plus : le besoin est identique — « ceci a déjà été envoyé pour
cette occurrence » —, et une contrainte d'unicité le tient sans test préalable,
donc sans course entre deux battements. Le contrôle négatif est fait : en
retirant le `continue when not found`, le second passage redépose, et le test
de fumée échoue.

L'insertion de la mémoire est **hors** du bloc qui attrape les erreurs, et
c'est voulu : une notification qui échoue reste comptée comme envoyée. Un
anniversaire manqué vaut mieux qu'un anniversaire annoncé mille quatre cent
quarante fois dans la journée.

La date du jour est prise en **Europe/Paris**, comme les rappels.
`profiles.timezone` existe et n'est lu par personne ; le lire ici seulement
donnerait deux conventions dans le même envoyeur.

### Au calendrier : une journée entière, et rien à ouvrir

La ligne porte `AgendaEntryKind.birthday`, va de 00:00 à 23:59, et sa gouttière
annonce « Journée » plutôt qu'une heure qui serait fausse. Sa teinte est
`warning` — **aucune couleur n'a été ajoutée** : c'était le seul jeton
fonctionnel que le calendrier n'employait pas.

Deux choix à connaître :

- **elle n'ouvre rien** (`isOpenable` est faux, comme pour un créneau). C'était
  faute d'écran de profil d'autrui ; celui-ci existe depuis la tranche 13, et
  l'y brancher se ferait sans SQL de plus — mais une ligne d'agenda annonce
  quelque chose qui *arrive*, et ouvrir un profil depuis une date n'est pas ce
  qu'elle promet. Les anniversaires s'ouvrent depuis leur notification, qui
  mène au calendrier ;
- **elle passe par le filtre de groupe**, sous la clé du personnel, comme un
  rendez-vous personnel. Les créneaux de disponibilité y échappent, mais eux
  décrivent le fond de la journée ; un anniversaire est quelque chose qui
  arrive.

Rien n'est lu de plus pour l'afficher : la lecture est chargée **une fois, sans
borne de dates**, et filtrée en mémoire — même parti que `mes_taches` et
`mon_agenda`.

**Ce qui n'a pas été étendu** : la carte d'agenda de l'accueil et les pastilles
de la semaine. Elles ne montrent pas les anniversaires, la consigne portant sur
le calendrier ; les y ajouter se ferait sans SQL de plus.

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
| ambre | `warning` | anniversaire d'un contact *(tranche 12)* |
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

## Le profil de quelqu'un d'autre

`/personnes/:id`, `PublicProfileScreen`, `supabase/tranche13_profil_consultable.sql`.

Jelvo n'en avait aucun : on ne voyait qu'une **fiche de contact** — épingler,
retirer —, et rien du tout d'une personne absente du carnet. C'est pourtant
l'écran qu'on cherche en touchant un avatar dans une conversation.

### Une seule fonction décide de tout, et ce n'est pas l'écran

C'est le point central de cette tranche. La consigne — « les statistiques et
les disponibilités sont réservées à ses contacts » — **ne peut pas être tenue
par un écran** : PostgREST est atteignable sans lui. Elle est donc tenue par
`profil_consultable`, qui rend la disponibilité à `null` dès que l'appelant
n'est pas un contact accepté. Un appel direct avec un identifiant arbitraire
obtient le même `null`.

| Ce que la fonction rend | À qui |
| --- | --- |
| avatar, nom, pseudo, bio, anniversaire | tout compte authentifié |
| la relation, le favori, les groupes en commun | tout compte authentifié |
| la disponibilité | **contacts acceptés** (et soi-même) |
| l'adresse e-mail | **personne, jamais** |
| les trois statistiques | **plus calculées du tout** — voir ci-dessous |

**`profiles_select` n'est pas desserré.** La tranche 7 l'a resserré à
`id = auth.uid() or has_social_link(id)`, et il le reste : la lecture directe
de la table demeure fermée aux étrangers, et cette fonction est la seule porte.

**La conséquence doit être dite** : les cinq champs publics deviennent
lisibles par tout compte authentifié **qui connaît l'identifiant**. C'est la
consigne — « visible par tout le monde » —, et comme
`chercher_profils_par_pseudo` permet déjà d'énumérer les comptes par préfixe,
ces cinq champs sont en pratique publics entre porteurs d'un compte. Rien
d'autre ne l'est, et le périmètre exact du changement se lit en une ligne : ce
`returns table`.

### L'adresse e-mail est hors de portée par construction

Elle vit dans `auth.users`, pas dans `profiles` : la fonction ne lit pas la
table qui la contient. Ce n'est pas une colonne qu'on s'abstient de
sélectionner, c'est une colonne qui n'existe nulle part dans cette lecture —
et c'est pour cela que le contrôle du test de fumée porte sur la **signature**
(`pg_get_function_result`) plutôt que sur une valeur : il échouerait le jour
où quelqu'un ajouterait un champ de sortie qui en porte une, ce qu'aucun appel
ne révélerait.

### La disponibilité délègue, et la porte posée est plus étroite

`get_availability_status` (schéma initial) reste seule juge de ce qu'elle
révèle, exactement comme `statuts_de_disponibilite` depuis la tranche 4. La
fonction y ajoute une condition **plus stricte** — un contact accepté, là où
la sienne accepte aussi les co-membres de groupe — parce que c'est la consigne.
Réimplémenter sa règle donnerait deux endroits où elle peut diverger, et l'un
des deux finirait par être le plus permissif.

**L'appel se fait par noms d'arguments**, et ce n'est pas du style :
`schema_actuel.sql` donne `(target uuid, at_ts timestamptz)`, tandis que
l'en-tête de la tranche 4 **et** le décor de `verification/` l'écrivaient dans
l'autre sens. Les deux appelants nommant leurs arguments, rien n'avait cassé —
mais un appel positionnel aurait passé le rejeu et échoué en production. Le
décor porte désormais l'ordre réel.

### `null` dit « pas votre affaire », et ce n'est pas « inconnu »

`PeerAvailability.unknown` est une information : rien n'est déclaré. L'absence
de valeur en est une autre. Le modèle garde donc `PeerAvailability?` et non un
`unknown` par défaut, et l'écran n'affiche **aucune pastille** quand la valeur
manque — ni quand elle vaut `unknown`, qui ferait passer un vide pour une
donnée, comme « Non précisé » sur un lieu d'événement.

### La ligne est lisible par les deux parseurs qui existent déjà

Les champs du profil portent les noms de colonnes de `profiles`, ceux de la
relation ceux de `mes_contacts` — `autre_id`, `statut`, `sens`, `favori`,
`groupes_communs`. `Profile.fromMap` et `Contact.fromRow` lisent donc la même
ligne sans une ligne de parsing de plus, et le `Contact` obtenu se donne tel
quel à `ContactActions`, qui sait déjà de quel bout de la relation on se
trouve — donc quelle colonne de favori écrire.

`avatar_url` arrive **composé** (`coalesce('preset:' || avatar_preset,
avatar_url)`), comme dans les onze autres lectures.

**`statut` nul signifie qu'aucune ligne `contacts` ne lie les deux
personnes.** `Contact` n'a pas de valeur pour « aucune relation » et n'a pas à
en avoir : c'est l'absence d'objet qui le dit.

### Un identifiant inconnu rend zéro ligne

Contrairement à `invitation_par_id`, qui rend **toujours** une ligne avec un
mot d'état. La règle de la tranche 8 ne se transpose pas : une invitation a
quatre états dégradés qui se confondaient tous en « introuvable », un profil
n'en a qu'un — il n'existe pas.

### `/personnes/:id` et non `/profil/:id`

`/profil` porte déjà trois enfants littéraux — `modifier`, `avatar`, `qr` —, et
un segment variable déclaré au même niveau les avalerait s'il venait avant.
C'est le piège documenté de `/groupes/nouveau`, qui doit précéder
`/groupes/:id` ; ici il faudrait le tenir pour trois chemins, et pour chacun de
ceux qu'on ajouterait ensuite. Un préfixe à part le rend impossible, et nomme
mieux ce qu'il désigne : une personne, pas « mon profil ».

La route est empilée sur le **navigateur racine**, et l'ouverture passe par
`context.ouvrirProfilDe` (`router/ouvrir_profil.dart`) : cinq endroits y
mènent, et un sixième s'ajoutera.

### Cinq points d'entrée, et toujours la même cible : l'avatar ou le nom

| D'où | Ce qui ouvre le profil |
| --- | --- |
| une conversation | le nom au-dessus de la série, et l'avatar sous la dernière bulle |
| les membres d'un groupe | l'avatar et le nom — pas le menu d'administration |
| les convives d'un événement | l'avatar et le nom — pas la pastille de réponse |
| les assignés d'une tâche | l'avatar et le nom — pas la pastille de statut |
| le carnet | l'avatar et le nom — **pas le chevron** |

**Le carnet garde donc deux cibles, et c'est délibéré.** La fiche
(`ContactActionsSheet`) agit sur le **lien** qu'on a avec quelqu'un, le profil
montre **quelqu'un**. Les confondre obligerait à choisir laquelle disparaît,
alors que « Gérer » de la bande des favoris ouvre déjà la première depuis un
autre endroit. Le test du carnet a changé de cible en conséquence — il touche
le chevron là où il touchait le nom.

### L'allure est celle de « Mon profil », sans ce qui n'a pas de sens ici

| Repris | Écarté, et pourquoi |
| --- | --- |
| la carte d'identité et la carte « À propos » | **la pastille d'appareil photo** : elle changerait la photo de quelqu'un d'autre |
| la rangée d'actions, montée dans `ProfileActionRow` | **Modifier, QR code, Partager** : les trois parlent de son propre profil |
| | **la carte des statistiques** — voir la section suivante |
| | **l'adresse e-mail**, qui n'est lisible nulle part |

`ProfileActionRow` existe parce que les **deux** cartes la portent, avec des
actions différentes : une seule copie de l'allure, qui est ce qui fait
reconnaître l'écran.

**La carte « À propos » disparaît** quand la bio et l'anniversaire sont tous
deux vides. Sur son propre profil une bio vide invite à la remplir ; ici il n'y
a ni texte à lire ni geste à proposer — même règle que le crayon de
description d'un groupe, absent pour un membre simple.

### Les actions suivent la relation, et aucune n'est inerte

| Relation | Actions |
| --- | --- |
| aucune | Ajouter en contact |
| demande reçue | Accepter · Refuser |
| demande envoyée | Annuler la demande |
| contact | Épingler / Épinglé · Retirer |
| soi-même | Mon profil |

« Annuler la demande » passe par `remove`, qui **supprime la ligne** :
`contact_status` ne connaît pas de `declined`, et c'est la suppression qui
tient le refus comme l'annulation. Un bouton grisé « Demande envoyée »
annoncerait une capacité que la base refuse.

**Retirer se confirme**, et c'est la seule action de cet écran qui défait
quelque chose sans moyen de le refaire d'un geste. **Toute action relit le
profil** : la relation vient de la base, et sans relecture l'écran continuerait
d'offrir « Ajouter en contact » à quelqu'un qu'on vient d'ajouter.

**Son propre profil ouvert par ce chemin** — en touchant son avatar dans une
conversation — n'offre aucune action de relation et mène à « Mon profil », qui
est le seul endroit où les statistiques vivent.

### Les groupes en commun se montrent à tout le monde

Sans règle d'accès à poser : ce sont **nos** groupes, dont on peut déjà lire la
liste des membres. Ce que la carte apprend, c'est l'intersection — pas
l'existence d'un groupe qu'on ne connaîtrait pas.

Les trois filtres de la tranche 10 s'appliquent, et aucun n'est décoratif : le
groupe doit être vivant, et **les deux** adhésions actives. Une adhésion
temporaire échue ne compte plus, d'un côté comme de l'autre — c'est la règle de
la tranche 6, et ce profil ne fait pas exception. Le compte (pour
`Contact.fromRow`) et le détail (pour la carte) sortent de la **même** jointure
et ne peuvent donc pas se contredire.

**Zéro se dit**, comme la pastille du carnet : « on se connaît sans rien
organiser ensemble » est une information, là où une carte absente se lirait
comme un chargement qui a échoué.

### Les trois statistiques ont été retirées, et de la base aussi

Elles ont existé une version : groupes, événements, tâches terminées, réservées
aux contacts. **Elles n'apprenaient rien sur quelqu'un d'autre.**

Le retrait va jusqu'au SQL : la fonction ne les *calcule plus*, et la colonne
`statistiques` a quitté sa signature. Ce n'est pas un masquage d'écran — c'étaient
trois sous-requêtes par ouverture de profil, dont une sur `events` et une sur
`tasks` jointe à `task_assignees`, pour un chiffre que plus personne ne lisait.

**C'est leur promesse qui ne se transposait pas.** Sur « Mon profil », chaque
chiffre **ouvre la liste qu'il résume** — un chiffre qu'on ne peut pas ouvrir
n'apprend rien de plus que lui-même. Or les listes de l'application sont celles
de l'utilisateur connecté : « ses groupes » ouvert depuis le profil de Léa
montrerait les miens. La première version l'avait réglé en rendant les
compteurs **inertes** ; les retirer est la conclusion que cela appelait.

`ProfileStatsCard` est donc revenue à sa forme d'avant — trois rappels
**obligatoires**, titre fixe, un seul appelant. Le paramètre `titre` et les
rappels nullables n'avaient plus de second lecteur, et une souplesse sans
lecteur est du code mort qui a l'air d'une intention.

#### Le retrait a coûté un `drop function`

`create or replace` **refuse** de retirer une colonne de sortie : il y voit un
changement de type de retour, et répond `cannot change return type of existing
function`. C'est le prix qu'ont payé `mon_agenda` et `mes_taches` pour en
*gagner* une, en tranche 6 puis en tranche 8 ; la règle ne fait pas de
différence dans l'autre sens.

Le fichier porte donc un `drop function if exists public.profil_consultable(uuid)`
avant son `create`, et **repose son `grant execute` après** — sans quoi la
tranche 7, qui ne se rejoue que si elle change, laisserait la fonction fermée.
`cascade` est volontairement omis : rien ne dépend de cette fonction, et un
`cascade` qui emporterait silencieusement un objet futur serait pire que
l'erreur qui le signale.

**Le rejeu sur base jetable n'éprouve pas ce `drop`** : il part d'une base
neuve, où il ne fait rien. Ce qu'il éprouve, c'est que la signature ne porte
plus `statistiques` — le même genre de contrôle que celui de l'adresse e-mail,
et pour la même raison : aucun appel ne révélerait une colonne de trop. Le
remplacement d'une fonction déjà en place a été vérifié à part, sur un cluster
monté pour l'occasion.

#### L'absence ne s'explique plus, parce qu'il n'y a plus de trou

La version précédente posait une phrase — « ses statistiques et ses
disponibilités sont réservées à ses contacts » — pour qu'un non-contact ne lise
pas la carte manquante comme un chargement raté. **Elle est partie avec la
carte**, et c'est cohérent : sans carte pour personne, il n'y a plus de trou à
expliquer.

Ne reste comme champ réservé que la pastille de disponibilité, et son absence
est **muette par construction** : un contact qui n'a rien déclaré n'en a pas
non plus. Annoncer qu'une donnée est retenue en dirait plus sur la personne
consultée que son absence.

---

## Suppression de compte

Obligation légale, livrée par `supabase/tranche14_suppression_compte.sql` et
l'écran `/parametres/supprimer-mon-compte`. Depuis les paramètres, sans écrire
à personne.

La règle : **tout ce qui l'identifie disparaît, ses messages restent**, signés
« Compte supprimé », pour ne pas trouer les échanges des autres.

### Le schéma impose la forme, elle n'a pas été choisie

`profiles.id` référence `auth.users(id)` **on delete cascade**, et
`messages.sender_id` référence `profiles(id)` **sans cascade**. Supprimer la
ligne d'authentification entraîne donc la suppression du profil, que
PostgreSQL refuse en `23503` tant qu'un seul message subsiste.

« Ses messages restent » et « sa ligne est supprimée » sont **incompatibles
par construction**. Et la voie officielle ne s'en sort pas mieux :
`auth.admin.deleteUser` depuis une fonction Edge échouerait sur exactement la
même contrainte. Ce n'est donc pas un contournement en attendant mieux.

D'où une **pierre tombale** : la ligne survit, son contenu est détruit — y
compris dans `auth`, où `postgres` a `update` et `delete` (vérifié sur le
projet, le propriétaire étant pourtant `supabase_auth_admin`).

### Rien ne cascade, et c'est le piège

Douze tables référencent `profiles(id)` en `on delete cascade`. Il serait
facile d'en conclure qu'elles se vident d'elles-mêmes : **elles ne se vident
pas**, la ligne `profiles` ne partant pas. Tout est donc supprimé
explicitement.

La liste des dix-huit sites vient du **catalogue** — `pg_constraint`, toutes
les clés étrangères pointant vers `profiles` —, pas de mémoire. Et
`verification/fumee.sql` refait cette confrontation à chaque rejeu : une table
ajoutée demain et oubliée dans la migration fait **échouer le rejeu**, au lieu
de laisser une donnée identifiante derrière elle. C'est la méthode de la
requête A0, appliquée à une suppression.

### Ce que chaque cas devient

| Cas | Sort |
| --- | --- |
| nom, prénom, bio, anniversaire, intérêts, fuseau, dernière vue | vidés |
| pseudo | `supprime.<11 hex>` — vingt caractères, ce qui respecte `profiles_pseudo_check`. Son vrai pseudo **redevient libre** |
| e-mail | `auth.users.email` à `null`, ligne `auth.identities` supprimée, mot de passe brouillé, sessions et jetons révoqués. L'adresse **redevient disponible** : elle peut se réinscrire avec |
| avatar | colonnes vidées **et fichiers retirés du bucket** |
| disponibilités, contacts, réactions, accusés de lecture, invitations | supprimés |
| abonnements push, préférences, sa boîte, sa file, sa mémoire de rappels | supprimés |
| notifications **des autres** qui la nomment | purgées |
| adhésions aux groupes | supprimées, **avec les deux garde-fous de `quitter_groupe`** : plus aucun membre actif referme le groupe, plus aucun administrateur promeut le plus ancien |
| ses liens d'invitation | **révoqués** — sinon un lien d'un compte supprimé continuerait d'ouvrir le groupe |
| tâches assignées | l'assignation part ; une tâche qui n'avait qu'elle **retourne au groupe**, et `tache_prise` repasse à faux pour que la carte redonne ses boutons |
| tâches et événements **de groupe** qu'elle a créés | **restent, sans transfert de propriété** : `modifier_evenement` et `supprimer_evenement` acceptent déjà un administrateur du groupe autant que l'auteur |
| événements **personnels** | supprimés — personne d'autre ne les voit |
| ses messages écrits | **restent** |
| ses photos et vidéos de conversation | **restent** : une photo est le plus souvent photo de quelque chose, et l'effacer trouerait l'échange |
| ses **messages vocaux** | fichier retiré, bulle refermée en « message supprimé ». Sa voix l'identifie directement, et ce n'est pas une mémoire partagée |

**La purge des notifications d'autrui part des valeurs du `payload`**, et non
d'une liste de noms de clés : `inviter_id` ici, `requester_id` là, et demain un
troisième auquel personne n'aurait pensé. Un `jsonb_each_text` compare donc
toutes les valeurs à son identifiant. Le contrôle négatif est dans le test de
fumée : une notification qui ne la nomme pas doit survivre.

### Le libellé ne peut pas être stocké

Écrire « Compte supprimé » dans `first_name` était la voie courte, et elle est
fausse : **l'application est en quatre langues**, et un nom écrit côté serveur
s'afficherait en français sur un téléphone allemand. C'est la règle du projet,
celle des couleurs étendue au vocabulaire.

La base porte donc un **drapeau** — `profiles.supprime_le`, et la colonne
`supprime` de `messages_du_groupe` —, et `AppTexts` écrit la phrase.

Un drapeau explicite, et non une identité nulle devinée : un profil absent et
un compte supprimé seraient alors indiscernables, et s'en remettre à cette
coïncidence est exactement ce que ce projet appelle une devinette.

#### `messages_du_groupe` vit dans deux fichiers, et le second gagne

La tranche 5a la crée, **la tranche 9 la redéfinit** pour y ajouter les cartes
de la conversation — et c'est elle qui fait foi, s'appliquant après. Poser
`supprime` dans la 5a a donc été **silencieusement sans effet**, jusqu'à ce
que le rejeu réponde « column m.supprime does not exist ».

Conséquence à connaître, antérieure à cette tranche : rejouer la 5a **seule**
réinstallerait une fonction sans `task_id`, `event_id`, `carte` ni `supprime`,
et la tranche 9, inchangée, ne serait pas rejouée derrière. La 5a porte
désormais un avertissement en tête de sa définition.

**Règle** : une fonction modifiée doit l'être dans le fichier qui la possède —
et le possesseur est le **dernier** fichier qui la crée, pas le premier. Le
filtre de `nom_affiche` vit ainsi dans la tranche 5c,
celui de `profil_consultable` dans la 13, celui de
`chercher_profils_par_pseudo` dans la 2.

### Le stockage ne peut pas être vidé depuis le SQL

Un `delete` sur `storage.objects` retire la ligne et **laisse les octets dans
le bucket** : le fichier devient introuvable, il n'est pas effacé. Seule l'API
Storage supprime l'objet, donc seul le client peut le faire — et **avant**
l'anonymisation, après laquelle la session est révoquée.

L'ordre est donc : les fichiers, puis l'appel SQL. Si le retrait échoue,
l'appel n'a pas lieu : le compte reste entier et la personne peut réessayer,
ce qui vaut mieux que l'inverse — des fichiers qu'elle n'a plus le droit de
supprimer. L'opération n'est donc **pas atomique**, et c'est le prix de cette
contrainte.

C'est la **première suppression de fichier de l'application** : rien n'avait
jamais retiré un ancien avatar. Le dossier `avatars/<id>/` est donc vidé en
entier, et non fichier par fichier.

### `refresh_tokens.user_id` est un `character varying`

Les quatre autres tables de `auth` que la suppression vide portent un `uuid` ;
celle-là non, et c'est gotrue qui en décide. Sans conversion explicite,
PostgreSQL répond « operator does not exist: character varying = uuid »
(`42883`) et la suppression entière échoue.

Le décor de `verification/` le recopie désormais à l'identique. Un décor en
`uuid` aurait laissé passer le défaut, que la vraie base aurait refusé après
fusion : c'est la règle du dimanche de la tranche 4, sur un type au lieu d'une
contrainte.

### Le mot de passe est redemandé, et il contrôle vraiment

`verifierMotDePasse` passe par `signInWithPassword`. **C'est ce qui le
distingue** du champ « mot de passe actuel » écarté du changement de mot de
passe : là, gotrue ne vérifie rien, et un champ qui ne contrôle rien donne un
faux sentiment de sécurité. Ici la vérification est réelle, et la suppression
ne se défait pas.

Un mot de passe refusé **n'est pas une panne** : c'est la réponse à la
question. Tout autre échec remonte — annoncer « mot de passe incorrect » pour
une coupure réseau enverrait chercher le défaut du mauvais côté.

### Immédiate, sans délai de grâce

Un sursis de trente jours signifierait que les données **ne sont pas
effacées**, et elle ne pourrait pas l'annuler : la session est fermée et
l'adresse libérée, donc il n'y a plus de porte pour revenir. Le choix est donc
l'effacement immédiat, et la réinscription comme seul retour — annoncée sur
l'écran.

`deja_supprime` compte comme un succès : le réseau peut avoir perdu la réponse
d'un premier appel, et il faut dans tous les cas refermer la session.

### L'écran, et la ligne qui y mène

Un écran et non une feuille : ce qui disparaît et ce qui reste tient en deux
listes qui doivent pouvoir être lues jusqu'au bout, et une feuille se referme
d'un glissement.

**La ligne des paramètres ouvre cet écran, elle ne supprime rien** — un doigt
qui glisse n'efface donc aucun compte. Elle vit dans sa **propre carte**, et
non sous la déconnexion : les deux sont rouges, et se quitter pour un moment
ne se range pas à un doigt d'écart de se quitter pour de bon. Elle garde son
chevron malgré `destructif`, par `SettingsRow.chevron` : sans lui, elle
promettrait une suppression au premier contact.

Aucune navigation après le succès : la session fermée, la garde du routeur
emmène vers la connexion d'elle-même, et dépiler en plus se battrait avec
elle.

---

## Signaler un abus

Obligation légale, livrée par `supabase/tranche15_signalements.sql` et la
feuille `ReportSheet`. Depuis un message, un groupe ou un profil ; traité
depuis `/parametres/signalements`.

### Une table dans l'application, et non un envoi d'e-mail

Un e-mail aurait demandé une adresse dédiée, un service d'envoi et une clé de
plus dans les secrets. Surtout, il n'aurait porté qu'une **alerte** : le
contenu signalé n'y serait pas, et il ne s'y traiterait pas. Une table lue par
un écran fait les deux, sans dépendance nouvelle.

### La table n'est pas exposée **du tout**

C'est la réponse à « sans que ce soit contournable ». Une politique RLS qui
vérifierait le lecteur serait déjà correcte, et pourtant insuffisante : elle
laisserait la table **atteignable** par PostgREST, et **les politiques
s'additionnent en « ou »**. Une politique de trop posée à côté la rouvrirait
— ce qui n'est pas une hypothèse, c'est ce qui est arrivé au stockage pendant
des mois (voir « Le durcissement du stockage était sans effet »).

`signalements` et `moderateurs` ne reçoivent donc **aucune politique**, et
leur privilège est retiré à `anon` et `authenticated`. Il n'y a pas de
politique à contourner : il n'y a pas de privilège. Cinq fonctions
`security definer` sont la seule porte, et chacune porte sa règle dans son
corps — ce qui est la règle de la tranche 7, appliquée dès la création plutôt
qu'après coup.

| Fonction | Qui peut l'appeler utilement |
| --- | --- |
| `signaler` | tout compte, sur ce qu'il peut voir |
| `est_moderateur` | tout compte, sur lui-même |
| `signalements_a_traiter` | un modérateur ; **zéro ligne** pour les autres |
| `traiter_signalement` | un modérateur ; `non_moderateur` pour les autres |
| `supprimer_message_signale` | idem |

**Zéro ligne et non une erreur** : un appel direct avec un identifiant
arbitraire obtient exactement ce qu'obtient un écran vide, et n'apprend donc
pas qu'il y avait quelque chose à voir. Les deux contrôles négatifs sont dans
le test de fumée — lire la table sous `authenticated` échoue en
`insufficient_privilege`, et s'y inscrire modérateur aussi.

### Qui est modérateur se dit une fois, hors du dépôt

`moderateurs` est **vide à la création**. La désignation est une ligne à
passer dans l'éditeur SQL du projet, prête à copier dans
`supabase/designer_moderateur.sql` — fichier qui n'est pas dans
`migrations.txt`, comme les deux fichiers de diagnostic.

La raison est dirimante : **le dépôt est public.** Ni l'adresse e-mail ni
l'identifiant du propriétaire n'ont à y figurer, et une migration qui
désignerait quelqu'un devrait porter l'un des deux.

**Un secret GitHub a été envisagé et écarté** : le workflow des migrations ne
tourne que sur un push touchant `supabase/`, si bien que poser le secret
n'aurait rien déclenché. La panne aurait été muette, et on l'aurait cherchée
du côté de la fonction plutôt que du côté du déclencheur — exactement le
genre de défaut que ce projet paie cher.

Tant que personne n'est désigné, la ligne des paramètres n'apparaît pour
personne et la file ne rend rien. Les signalements, eux, se déposent
normalement et attendent dans la table : **c'est l'état sûr par défaut**, pas
une panne.

### Le contenu signalé est recopié, et c'est tout l'objet

`signalements.contexte` garde le texte du message au moment du signalement.
Deux raisons, et chacune suffit :

1. **celui qu'on signale est précisément celui qui veut effacer.**
   `supprimer_message` vide `content` — la preuve disparaîtrait avec un geste
   que son auteur peut faire à tout moment ;
2. **le modérateur n'est pas membre du groupe.** `msg_select` ne lui
   laisserait rien lire, et lui ouvrir les conversations du service pour qu'il
   puisse juger un message serait payer bien trop cher.

Sans la recopie, le signalement serait l'alerte sans le contexte — ce que la
consigne écarte en toutes lettres. C'est la raison d'être de la phrase
affichée dans la feuille : elle dispense de faire une capture d'écran avant
de signaler.

**Les messages voisins n'y entrent pas.** Ils sont d'auteurs tiers que
personne n'a signalés, et les recopier mettrait leurs propos dans un dossier
de modération sans qu'ils y soient pour rien. Si le contexte alentour devenait
nécessaire, ce serait une décision à prendre, pas un oubli à combler.

**L'écart entre la recopie et l'état réel est une information** :
`signalements_a_traiter` rend `message_efface`, et la carte dit « ce message a
été effacé depuis ». C'est ce qui distingue « rien à voir » de « il a effacé ».

#### On ne signale que ce qu'on peut voir

`signaler` exige `is_group_member` pour un message comme pour un groupe. Ce
n'est pas du zèle : **sans ce refus, la recopie serait un oracle de lecture**
sur toutes les conversations du service — il suffirait de signaler un
identifiant de message pour en obtenir le texte. Le contrôle négatif est dans
le test de fumée, et c'est le défaut qu'il faut ne pas créer en voulant garder
la preuve.

### Voir **et agir**, pas seulement recevoir une alerte

| Cible | Ce que le modérateur peut faire |
| --- | --- |
| un message | **le supprimer** (suppression douce), et marquer traité |
| un groupe | marquer traité, avec une note |
| un profil | marquer traité, avec une note |

`supprimer_message_signale` existe parce que `supprimer_message` n'obéit qu'à
l'auteur du message, et que le modérateur n'est pas membre du groupe. La
suppression est **douce** comme partout : `content` passe à la chaîne vide —
`messages_check` exige un contenu ou un média —, la bulle se referme en
« message supprimé » chez tout le monde, et la recopie du signalement garde ce
qui avait été écrit. Le fichier d'un média reste dans le bucket : seule l'API
Storage l'efface, et c'est la limite déjà documentée pour la suppression de
compte.

**Fermer un compte et supprimer un groupe ne se font pas d'ici**, et l'écran le
dit plutôt que de laisser chercher le bouton : ce sont des décisions dont la
portée dépasse ce qu'une migration peut trancher. La note est le levier, et le
blocage en sera un autre.

### « Marquer traité pour ne pas le revoir »

C'est `traite_le` qui le porte, et la lecture par défaut ne rend que les
lignes où il est nul. Pas de colonne « vu », pas de table de suivi — même
parti que la suppression de la ligne d'adhésion en tranche 6, qui *est* la
mémoire.

Trois choix à connaître :

- **rouvrir est possible** (`p_traite` à faux) : un traitement posé par erreur
  n'aurait sinon aucun recours. La note posée au traitement **survit** à la
  réouverture — elle dit ce qui a été fait, et le geste ne se défait pas ;
- **la note se demande au moment où l'on décide**, pas après. « Ce que vous
  avez fait » ne se retrouve pas une heure plus tard, et une note facultative
  qu'on ne propose jamais n'est jamais écrite ;
- **`null` et la chaîne vide ne veulent pas dire la même chose** : annuler le
  dialogue ne traite pas, le valider sans écrire traite sans note. Les
  confondre empêcherait de traiter sans commentaire. Même distinction que
  `null` et `[]` pour les assignés de `creer_tache`.

### Deux signalements identiques non traités n'apprennent rien

`signaler` répond `deja_signale`. Le contrôle est dans la fonction et non dans
une contrainte d'unicité, parce que la règle porte sur « non encore traité » —
qu'un index unique partiel dirait mal —, et parce que le second signalement du
même geste, **après** traitement, est légitime.

Côté écran, « déjà signalé » **reste dans la feuille** avec son message : ce
n'est pas une panne, c'est la réponse à la question, et refermer sur une
`SnackBar` furtive laisserait croire à un envoi.

### La feuille est unique, et l'ouverture vit dans `router/`

**Une feuille et non trois.** Ce qui change d'un message à un groupe ou à un
profil, c'est le titre : les six motifs, le champ de précisions et les deux
phrases d'explication sont les mêmes.

`ReportSheet` vit dans la feature, et son ouverture dans
`router/signaler.dart` — **même raison que `ouvrirProfilDe`** : trois features
l'appellent, et *une feature ne lit jamais les widgets d'une autre*. Monter le
widget dans `core/widgets` comme `CoverBanner` était impossible : il écrit,
donc il lit un provider de la feature, et `core` ne connaît aucune feature.
Lui passer un rappel aurait recopié le câblage aux trois sites d'appel.

Les deux phrases de la feuille ne sont pas du remplissage. La première — « la
personne n'est pas prévenue, et ne saura pas qui a signalé » — répond à la
première question de quelqu'un qui hésite. La seconde dit que l'effacement ne
sauvera personne.

**Signaler n'apparaît pas sur son propre message**, et le menu d'un profil ne
s'ouvre pas sur son propre profil : `signaler` refuse `soi_meme`, et offrir le
geste pour obtenir un refus serait promettre ce que la base refuse.

### Ce que la suppression de compte en fait

Trois clés étrangères, trois sorts, et **aucun n'est « supprimer »** — un
dossier de modération ne doit pas s'effacer en fermant un compte, ni celui de
qui a signalé, ni celui de qui est signalé.

| Colonne | Sort |
| --- | --- |
| `signalements.auteur_id` | **`null`** — le dossier reste, son auteur devient anonyme, et l'écran affiche « Compte supprimé » |
| `signalements.traite_par` | **`null`**, même raison |
| `signalements.profil_id` | **conservé** : il pointe vers la pierre tombale, qui ne porte plus de nom. Le mettre à `null` ne protégerait personne et priverait le dossier de son sujet — en plus de taire au modérateur que le compte visé est déjà parti |
| `moderateurs.user_id` | **supprimé** : « ce compte peut lire les signalements » l'identifie autant que le reste |

Le `contexte` recopié n'est pas touché : c'est du **contenu**, et le contenu
reste. Même arbitrage que pour les messages et les photos.

Conséquence assumée de la dernière ligne : si le seul modérateur supprime son
compte, plus personne ne lit la file et il faut en désigner un. L'alternative
— garder un compte supprimé parmi les modérateurs — est pire.

**C'est le filet de la tranche 14 qui a imposé tout cela**, et il a fonctionné
exactement comme prévu : les trois nouvelles clés étrangères ont fait échouer
le rejeu avec « ces colonnes référencent profiles et la suppression de compte
ne dit pas ce qu'elles deviennent », puis `moderateurs.user_id` une seconde
fois. Rien n'a été oublié parce que rien ne *pouvait* l'être.

### Une contrainte qui interdit, et n'exige pas

`signalements_cible_coherente` interdit les clés hors sujet et **n'exige la
présence d'aucune**. Ce n'est pas un relâchement : les trois clés sont
`on delete set null`, et une contrainte exigeant la présence de l'une d'elles
serait réévaluée à la mise à `null` et **refuserait la suppression** de
l'objet visé. Ce qui garantit la bonne clé, c'est que `signaler` est le seul
écrivain possible — la table n'a aucun privilège —, et c'est une garantie plus
forte qu'un `check`.

Un signalement de message porte **aussi** `profil_id`, l'auteur du message :
sans lui, la modération lirait un identifiant brut dans la recopie, et deux
signalements visant la même personne — l'un sur son message, l'autre sur son
profil — ne se rapprocheraient pas.

### Le détecteur de textes a trouvé un vrai défaut, deux heures après

Les guillemets du commentaire étaient écrits dans le widget : `'« … »'`. Ils
sont français — l'anglais écrit « “ … ” », l'allemand « „ … “ » —, et les
laisser là les aurait donnés aux quatre langues. C'est le défaut qu'on venait
de corriger quatre-vingt-onze fois, recréé dans la même journée. Le séparateur
de l'en-tête a suivi le même chemin, par précaution : un `·` est de la
ponctuation, mais une langue pourrait vouloir l'ordre inverse.

---

## Bloquer quelqu'un

Obligation légale, livrée par `supabase/tranche16_blocage.sql`. Depuis le menu
d'un profil ; la liste et le déblocage vivent dans `/parametres/bloques`.

### Le principe, et le cas délicat qu'il tranche

**Un blocage arrête un geste qui m'est adressé ; il ne change pas ce qu'un
groupe fait par défaut pour tous ses membres.**

Ce n'est pas une liste de trois exceptions, c'est une règle — et c'est elle
qui répond au cas délicat, **deux personnes déjà dans le même groupe**.

| Ce que le blocage fait | Ce qu'il ne fait pas, et pourquoi |
| --- | --- |
| refuse une invitation de groupe | **ne retire personne du groupe** : l'adhésion est l'affaire du groupe et de ses administrateurs, pas d'un réglage personnel |
| refuse une demande de contact | **ne masque aucun message** : la conversation se lirait comme des réponses à des propos invisibles |
| refuse une assignation de tâche | **ne retire personne d'un événement de groupe** |

La dernière ligne paraît contredire la troisième — pourquoi refuser une tâche
et pas un événement ? Parce que **l'assignation nomme une personne**, un par
un, alors que `creer_evenement` convie **tous** les membres actifs par défaut.
Et il n'existe aucun événement **personnel** auquel on puisse convier
quelqu'un : un événement sans `group_id` n'est visible que de son
propriétaire. L'invitation à un événement n'existe donc que dans un groupe
déjà partagé, c'est-à-dire exactement l'espace que le blocage ne réécrit pas.
Même raison pour `rejoindre_groupe_par_jeton` : rejoindre un groupe n'est pas
un geste adressé à quelqu'un.

**La conséquence se dit à l'écran.** La confirmation de blocage porte une
seconde phrase — « vous partagez un groupe : elle y restera visible, et la
conversation ne change pas ; pour ne plus la croiser, quittez le groupe » —
qui n'apparaît que lorsqu'un groupe est réellement partagé. Un blocage qui en
promet plus qu'il n'en fait est pire qu'un blocage qui annonce sa limite, et
la suite qui a du sens existe déjà.

### Le prédicat est symétrique

`bloque(a, b)` est vrai dès qu'un blocage existe **dans un sens ou dans
l'autre**. Un seul prédicat, donc une seule règle : avoir bloqué quelqu'un
puis lui envoyer une invitation serait incohérent, et deux prédicats auraient
fini par diverger — le reproche déjà fait, et retenu, aux deux
implémentations de la visibilité des disponibilités.

**Un paramètre nul rend faux**, et ce n'est pas de la complaisance : les
travaux d'entretien tournent sans session, `auth.uid()` y vaut `null`, et un
prédicat qui lèverait là ferait échouer la vidange de la file.

### Trois déclencheurs, et non six fonctions réécrites

Les trois gestes passent par des chemins différents : `inviter_dans_groupe`,
une insertion directe dans `contacts`, et **quatre** fonctions pour
l'assignation — `creer_tache`, `definir_assignes_tache`, `s_attribuer_tache`,
`prendre_tache`. Poser la garde dans chacune, c'est six endroits à tenir
d'accord, dont deux vivent dans un fichier **gelé** qu'il faudrait recopier en
entier.

La garde est donc posée sur les **tables**, en `before insert` :
`invitations`, `contacts`, `task_assignees`. C'est la méthode de la requête A0
appliquée à une interdiction — partir de l'endroit où la donnée atterrit
plutôt que de la liste des chemins auxquels on a pensé. **Un septième chemin
d'écriture ajouté demain est couvert sans qu'on y pense.**

Le déclencheur compare **l'auteur du geste** — `auth.uid()` — à la personne
visée, et non les assignés entre eux. C'est pourquoi un tiers peut
parfaitement assigner la même tâche aux deux personnes qui se bloquent : il
ne s'adresse à aucune des deux en leur nom. Le contrôle positif est dans le
test de fumée.

**Il lève, il ne filtre pas.** Une ligne silencieusement écartée donnerait une
tâche dont l'assigné manque sans que rien ne le dise — le défaut que ce projet
appelle « pire qu'une erreur », et qui a coûté la promotion de membre. Le
SQLSTATE `JB001` est propre à Jelvo, et `AuthFailure` lui donne **son propre
message** : « permission refusée » enverrait chercher un défaut de droits, là
où la cause est une personne qui a fermé la porte.

#### Un `case` plpgsql compile ses branches non prises

Le déclencheur est partagé par trois tables, et sa première version lisait la
colonne visée par un `case tg_table_name when 'invitations' then
new.invitee_id … end`. Elle échouait sur `contacts` :

```
ERROR: record "new" has no field "invitee_id"
```

**Une expression plpgsql est compilée en entier**, branche non prise comprise.
Trois affectations séparées sont trois *instructions*, et chacune n'est
préparée qu'au premier passage dans sa branche. Le test de fumée l'a trouvé —
il insère dans les trois tables, ce qu'une seule n'aurait pas révélé.

### Ce que bloquer défait, et ce qu'il laisse

| Défait | Laissé |
| --- | --- |
| le lien de contact, **dans les deux sens**, avec ses favoris | les messages déjà écrits |
| les invitations encore `pending` entre les deux | les tâches **déjà** assignées |
| | les adhésions aux groupes |

Le lien de contact part parce que c'est le minimum de ce que « bloquer » veut
dire, et `contact_status` ne connaît pas de valeur `blocked` : c'est la
suppression de la ligne qui porte le refus, comme pour une demande déclinée.

Les assignations déjà posées restent : la consigne dit qu'une personne bloquée
ne doit **plus pouvoir** assigner, au futur. Les retirer changerait une tâche
du groupe après coup.

**Débloquer ne rend rien.** Le lien de contact et les invitations supprimés ne
reviennent pas : il faut se redemander en contact. Même parti que l'adhésion
échue et rangée de la tranche 6 — ce qui a été défait ne se reconstitue pas,
et prétendre le contraire demanderait de garder une mémoire de ce qu'on a
effacé, donc de ne pas l'effacer.

### Le profil se ferme, et la liste devient nécessaire

`profil_consultable` rend **zéro ligne** dès qu'un blocage existe, dans un
sens ou dans l'autre : les deux côtés lisent « Profil introuvable », le même
état qu'un identifiant inconnu.

**D'où `/parametres/bloques`, qui n'est pas du confort.** Le profil n'étant
plus un chemin, sans cette liste on se serait enfermé dans son propre
réglage : il n'y aurait eu aucun moyen de débloquer quelqu'un. `mes_blocages()`
joint le profil pour la même raison que les autres lectures `security
definer` — bloquer **supprime** le lien de contact qui aurait pu rendre la
ligne `profiles` lisible.

La ligne des paramètres est **toujours présente**, contrairement à celle de la
modération : une liste vide n'est pas un écran qui ne mène nulle part, c'est
la réponse à « qui ai-je bloqué ? ». **Zéro ne s'affiche pas** à droite — un
« 0 » s'y lirait comme une alerte —, et l'état vide dit où l'on bloque.

**Cela ne cache pas le blocage à la personne bloquée**, et il ne faut pas s'en
flatter : elle continue de voir l'autre dans un groupe partagé et en tirera la
conclusion. Ce que la fonction garantit, c'est qu'elle ne lira plus ni la bio,
ni l'anniversaire, ni la disponibilité — pas qu'elle ignorera l'existence du
blocage, ce qu'aucune requête ne peut promettre.

### Le sélecteur d'assignés écarte, l'écran n'interdit pas

`task_form_sheet` retire les personnes bloquées de ses candidats. Elles
restent membres du groupe et visibles partout ailleurs : ce qui est écarté,
c'est **le geste** — proposer un avatar pour obtenir un refus serait promettre
ce que la base refuse, comme un bouton grisé.

**Le filtre ne vaut que pour celui qui a bloqué.** La personne bloquée n'est
pas prévenue, et rencontrera le refus `JB001` si elle tente l'assignation.
C'est le prix de ne pas lui annoncer le blocage, et le message qu'elle lit —
« cette personne ne peut pas être ajoutée » — ne nomme pas la cause.

### Ce que la suppression de compte en fait

`blocages.bloqueur_id` et `blocages.bloque_id` sont **tous deux supprimés** :
« ce compte a bloqué X » l'identifie autant que le reste, et un blocage posé
par un compte parti ne protège plus personne — il n'y a plus personne à
protéger. Le filet de la tranche 14 l'a imposé, comme pour les signalements.

### Ce qui n'est pas couvert, et pourquoi

| Écarté | La raison |
| --- | --- |
| masquer les messages dans un groupe partagé | la conversation deviendrait des réponses à des propos invisibles, et elle appartient à tout le groupe |
| exclure d'un événement de groupe | il convie tous les membres par défaut : ce n'est pas un geste adressé à quelqu'un |
| empêcher de rejoindre un groupe par lien | rejoindre n'est pas un geste adressé à quelqu'un |
| retirer les assignations déjà posées | la consigne porte sur ce qui ne sera **plus** possible |

Les quatre lignes disent la même chose sous quatre formes, et c'est voulu :
**un blocage n'est pas un pouvoir sur un espace partagé.** Le jour où il
faudrait davantage, c'est « quitter le groupe » ou une exclusion par un
administrateur — deux gestes qui existent déjà et qui, eux, s'annoncent.

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

**Quatre langues : français, anglais, espagnol, allemand.** Le français est la
langue de référence — `template-arb-file` de `l10n.yaml` —, et les quatre
fichiers `lib/l10n/app_{fr,en,es,de}.arb` portent les **985 mêmes clés**, dont
162 paramétrées et 25 en pluriel ICU. `AppTexts` est la classe générée.

Les délégués de Material et de Cupertino ne sont pas décoratifs : sans eux, un
`showDatePicker(locale: Locale('fr'))` reste en anglais quand il ne lève pas.

**Ajouter une cinquième langue = déposer `app_<code>.arb` et l'inscrire dans
`LanguageStorage.languesPrisesEnCharge`.** Deux endroits, pas un : la liste
sert aussi la feuille des paramètres et la résolution de la langue du
téléphone.

`core/core.dart` **exporte `AppTexts`**, pour la même raison qu'il exporte la
palette : un écran lit ses mots au contexte comme il y lit ses couleurs, et un
seul import doit suffire.

### La langue vient du téléphone, et se choisit sur l'appareil

| Situation | Langue servie |
| --- | --- |
| rien de choisi, téléphone dans les quatre | celle du téléphone |
| rien de choisi, téléphone ailleurs (japonais…) | **l'anglais** |
| une langue choisie dans les paramètres | celle-là, quel que soit le téléphone |

**L'anglais est le repli, et non le français** bien qu'il soit la langue de
référence du projet : quelqu'un dont le téléphone est en japonais a plus de
chances de lire l'anglais.

Flutter, lui, retombe sur `supportedLocales.first`, c'est-à-dire sur le
français : il faut donc un `localeListResolutionCallback` explicite. Il a un
second effet, qui vaut à lui seul : il est **rappelé à chaque
`didChangeLocales`**, si bien qu'un téléphone qui change de langue en cours de
route est suivi sans redémarrage.

**La correspondance se fait sur le code de langue seul.** Un téléphone en
`es_MX` doit obtenir l'espagnol ; exiger la région reviendrait à servir
l'anglais à tout le Mexique pour une variante que Jelvo ne distingue pas.

#### Le réglage vit sur l'appareil, pas sur le compte

`LanguageStorage` reprend la brique de `ThemeStorage` — un `LocalStorage` de
gotrue détourné, clé `jelvo-langue` — et pour la **même** raison : un seul
compte peut être ouvert sur un téléphone acheté en Espagne et sur
l'ordinateur d'un bureau français. Un réglage de compte imposerait la même
langue aux deux.

Ce qui est écrit est un **code de langue** (`fr`, `en`, `es`, `de`, ou
`systeme`), jamais un rang : un index se décalerait à la cinquième langue, et
l'appareil se réveillerait dans une langue qu'il n'a pas choisie. C'est la
leçon des trois mots d'apparence, appliquée avant d'en avoir payé le prix.

Il est lu dans `main()` **avant `runApp`**, comme la session, la bienvenue et
l'apparence : s'ouvrir en français pour basculer en espagnol à la première
image serait le même clignotement, et il ne se rattrape pas après coup.

**Contrairement à l'apparence, `web/index.html` n'a rien à lire ici.** Le fond
de la page et le bandeau de la barre d'état sont décidés avant que Flutter
démarre ; la langue ne se voit qu'une fois qu'il y a du texte, donc après. Il
n'y a **aucun contrat recopié** de ce côté, et rien à tenir d'accord.

#### La feuille applique sur place, et nomme chaque langue dans sa langue

« Celle du téléphone » en tête — c'est le défaut, et le seul choix qui n'en
est pas un —, puis `Français`, `Deutsch`, `English`, `Español`. **Le nom natif
ne passe pas par l'ARB** : traduit, il changerait de mot selon la langue
courante, et « German » ne sert à rien à quelqu'un qui cherche l'allemand sans
parler anglais. Le nom dans la langue courante est en aide, sous le nom natif.

Pas de drapeau : **un drapeau nomme un État, pas une langue**, et l'espagnol
en couvre vingt. Comme l'apparence, le choix s'applique sans bouton
« Enregistrer » — une langue se juge en la voyant.

### Les dates et les heures sont le vrai piège, pas les mots

`AppDates` ne porte plus de `locale` : **chaque méthode prend l'`AppTexts`**,
dont elle lit `localeName`. Lui faire lire `Intl.defaultLocale` aurait été la
variable globale qu'on écarte pour les couleurs — avec le même défaut, un
écran à moitié reconstruit dans l'ancienne langue.

**Les squelettes l'emportent sur les motifs littéraux**, et c'est ce qui
distingue une date traduite d'une date française écrite en allemand :

| Besoin | Squelette | fr | en |
| --- | --- | --- | --- |
| l'heure | `jm` | 14:00 | 2:00 PM |
| la date complète | `yMMMMEEEEd` | Jeudi 6 août 2026 | Thursday, August 6, 2026 |
| jour et mois | `MMMMEEEEd` | Jeudi 6 août | Thursday, August 6 |

`'HH:mm'` aurait donné « 14:00 » à un anglophone, et `'EEEE d MMMM y'` aurait
privé l'espagnol des « de » qu'il intercale — *jueves, 6 de agosto de 2026*.

`initializeDateFormatting()` est appelée **sans argument** : avec `'fr_FR'`,
elle ne charge que les symboles français, et les trois autres langues
formateraient en anglais sans rien dire.

#### Une plage horaire ne porte son marqueur qu'une fois

« 9:00 AM – 10:30 AM » débordait la carte d'agenda de l'accueil à 360 dp.
`AppDates.timeRange` écrit donc **« 9:00 – 10:30 AM »** quand les deux heures
partagent leur demi-journée — c'est ce que font les formats d'intervalle du
CLDR (`h:mm – h:mm a`), que `DateFormat` n'expose pas. Un intervalle qui
change de demi-journée garde les deux marqueurs : « 11:30 AM – 1:00 PM ».

Le marqueur est trouvé en comparant `jm` à `Hm` plutôt que codé par langue :
une liste de langues à 24 heures serait fausse à la cinquième.

### « Bon week-end », et aucune fête nationale

La salutation de l'accueil connaît quatre moments : matin, après-midi, soir,
**week-end**. Le soir l'emporte sur le week-end — « Bon week-end » à 23 h un
samedi serait étrange, « Bonsoir » est juste tous les jours.

**Les fêtes nationales sont écartées, et c'est un choix de fond.** Une fête
dépend du **pays**, pas de la langue : l'espagnol couvre vingt pays,
l'allemand trois, l'anglais aucun en particulier — et le 14 juillet ne dit
rien à un francophone belge ou québécois. Or Jelvo ne sait pas où vous êtes :
ni localisation, ni numéro de téléphone, et `profiles.timezone` que personne
ne lit. Déduire le pays de la langue serait exactement la devinette qu'on
écarte partout ailleurs — les icônes de catégorie déduites du nom d'un groupe,
la pastille de présence sans `last_seen_at`.

Demander le pays serait **une donnée de plus à collecter** pour une phrase de
salutation, et Jelvo collecte le minimum : c'est la raison pour laquelle
l'anniversaire n'a pas d'année. Samedi et dimanche, eux, sont les mêmes dans
les quatre langues.

#### L'après-midi espagnol commence plus tard, et c'est une donnée de langue

*Buenas tardes* commence après le déjeuner — vers 14 h —, et servir « buenas
tardes » à midi est quelque chose qu'aucun hispanophone n'écrit. Les deux
bornes horaires vivent donc dans l'ARB (`coreDebutApresMidi`,
`coreDebutSoiree`), au même titre qu'un format de date :

| | fr | en | es | de |
| --- | --- | --- | --- | --- |
| après-midi | 12 | 12 | **14** | 12 |
| soir | 18 | 18 | **20** | 18 |

C'est la seule raison pour laquelle `greetingProvider` prend la langue.

### Le contrôle est dans la CI, et il échoue sur un texte en dur

`tool/verifier_textes.py` est la cinquième étape de `tool/verifier.sh` et de
`deploy-web.yml`, posée **avant** l'analyse parce qu'elle est instantanée.

**Aucune règle de `flutter analyze` ne dit « cette chaîne atteint l'écran ».**
Un texte écrit en dur compile, passe l'analyse, passe les tests, et ne se
constate qu'à l'écran de quelqu'un qui a choisi une autre langue. Sans ce
contrôle, la migration se déferait à la prochaine fonctionnalité — c'est le
même genre de panne silencieuse que la publication `supabase_realtime`
manquante.

**La détection se fait par la position, pas par le contenu.** Une chaîne est
suspecte parce qu'elle occupe un emplacement de texte — premier argument d'un
`Text(`, `EmojiText(`, `SelectableText(`, ou valeur d'un paramètre nommé dont
le nom dit qu'il s'affiche (`label`, `titre`, `message`, `tooltip`,
`semanticsLabel`, `hint`…). Le contraire — chercher ce qui *ressemble* à du
français — attrape les noms de colonnes SQL, les clés de stockage et les trois
mots du contrat d'apparence (`clair`, `sombre`, `systeme`), qui doivent
précisément rester en dur.

Une seconde règle rattrape ce que la position ne voit pas : **une chaîne de
deux mots dont l'un fait au moins deux lettres** est une phrase, où qu'elle
soit. C'est ce qui a trouvé les libellés rendus par un modèle ou un provider,
loin de tout widget. La première version du détecteur n'exigeait qu'un accent,
et laissait donc passer toute phrase française sans accent.

#### Il a laissé passer 170 mots d'un seul tenant

**Deux trous, trouvés par la traduction et non par le détecteur**, et c'est le
plus instructif de ce chantier : la migration a été annoncée terminée alors
que les quatre onglets de la barre de navigation étaient encore en français.

| Le trou | Ce qu'il laissait passer |
| --- | --- |
| `IDENTIFIANT` valait `^[\w./:+${}#&?=@~%-]*$` | **tout mot d'un seul tenant** : `Accueil`, `Calendrier`, `Retour`, `Profil`. `\w` couvrant les lettres accentuées en Python, `Créer` et `Filtres` passaient aussi |
| `POSITIONS` n'acceptait que `nom:` | une **valeur par défaut**, écrite avec `=` : `this.createLabel = 'Créer'` |

Le premier est le plus cher : il visait les chemins (`assets/avatars/$id.png`,
`jelvo-apparence`), et un mot de lettres seules en avait la forme. Il exige
désormais **un caractère non-lettre** — un mot pur retombe sur les deux règles
suivantes, où seule la *position* peut le signaler. Les trois mots du contrat
d'apparence restent donc tranquilles : `clair`, `sombre` et `systeme`
n'apparaissent jamais en position de texte.

Ce que cela a coûté : 170 sites dans 60 fichiers, 52 clés de plus, et une
restructuration — `NavDestination` portait son libellé en `static const`, là
où aucun `BuildContext` n'existe. Elle porte désormais un `NavTab` et rend
`label(AppTexts t)`, ce qui est la règle du projet appliquée au vocabulaire.

**Règle de méthode** : un détecteur qui écarte une forme doit écarter *cette*
forme, pas la classe de caractères qui la contient. Les deux trous étaient des
écartements trop larges, et un écartement trop large ne se voit jamais — il
rend le vert.

#### Puis 91 de plus, et ce sont les trois trous suivants

**Le détecteur était vert sur `main`, et quatre-vingt-onze chaînes françaises
atteignaient l'écran dans les quatre langues** — 37 fichiers. Le chiffre est
mesuré, pas estimé : l'ancien détecteur et le renforcé ont été lancés côte à
côte sur le même arbre, et c'est l'écart entre les deux.

| Le trou | Ce qu'il laissait passer |
| --- | --- |
| `POSITIONS` exigeait la chaîne **adjacente** à la position | tout ce qui passe par un opérateur : `name ?? 'Membre'`, `x ? 'Épinglé' : 'Épingler'`, `() => 'Personnel'`. Un relais — `(?:[^,]*?(?:\?\?|\?|:|=>)\s*)*` — le rattrape |
| les paramètres nommés ne couvraient ni `name`, ni `nom`, ni `emptyMessage` | `AvatarData(name: 'Membre')`, et les états vides d'une liste |
| aucune règle ne voyait **un mot seul en position de texte** | `'Haute'`, `'Terminée'`, `'Oui'`, `'Jeudi'`, `'février'`. La règle des deux mots demande une espace, et celle de l'accent aussi |

Le troisième est celui qui coûtait le plus, et il demandait de rouvrir ce que
le premier correctif avait fermé trop large : un mot d'un seul tenant avait été
rendu *indétectable* pour protéger les chemins et les clés de stockage.
`ressemble_a_un_libelle` le reprend par l'autre bout — un mot capitalisé, en
PascalCase ou tout en majuscules **en position de texte** est un libellé —, et
`IDENTIFIANT_TIRET` ne laisse le tiret désigner un identifiant que dans une
chaîne entièrement en minuscules ASCII. `clair`, `sombre`, `systeme` et
`jelvo-apparence` restent donc tranquilles.

**C'étaient les libellés rendus par une méthode `label(AppTexts t)`** : les
neuf énumérations avaient bien gagné le paramètre, et leur `switch` renvoyait
toujours du français en dur. Le reste est de la même eau — les sept jours de la
semaine et les douze mois en listes `const`, « Admin » et « Membre » portés par
`GroupRole`, les trois mots de `PeerAvailability`, « Oui · Peut-être · Non ».
D'où `AppDates.weekdayName` et `AppDates.monthName`, qui construisent le nom
depuis une date de référence plutôt que depuis une liste : il n'y a plus de
liste à tenir.

`GroupRole` a **perdu** son libellé au lieu d'en recevoir un : personne ne le
lisait, la pastille d'administrateur passant déjà par l'ARB. Un champ mort qui
mente est pire qu'un champ absent.

**Le balayage a aussi trouvé un défaut laissé par la passe précédente** :
`navigateur.maybePop()` y était devenu `navigateur.maybePop(AppTexts.of(context))`,
un remplacement mécanique qui compile — `maybePop` prend un résultat facultatif
— et qui passait donc l'analyse. Sans conséquence visible, la feuille étant
ouverte en `showModalBottomSheet<void>` : personne ne lit ce résultat. C'est
le genre de dégât qu'un script de remplacement fait en silence, et la raison
de lire son diff.

### Un modèle ne choisit pas ses mots

**C'est la règle des couleurs, étendue au vocabulaire.** Un modèle dit *ce que
la chose est* ; l'appelant en tire le libellé. Conséquences portées par le
code :

| Avant | Après |
| --- | --- |
| `AuthFailure` portait son message | il porte un `AuthFailureKind`, et `message(AppTexts t)` en déduit la phrase |
| neuf énumérations portaient leur libellé en `const` | elles rendent `label(AppTexts t)` — une valeur d'énumération est constante par construction, un mot ne l'est pas |
| `Group.memberLabel` était un getter | c'est `memberLabel(AppTexts t)`, qui appelle le pluriel ICU |
| `greetingProvider` rendait « Bonjour » | il rend un `MomentDuJour`, dont `salutation(t)` tire le mot |
| `groupActivityProvider` composait « 3 tâches en cours » | il a disparu : l'écran lit les deux nombres de `groupOngoingProvider` et bâtit la phrase |
| `CredentialsRules.pseudoError` rendait un message | il y a d'abord `pseudoProbleme`, pur, puis `pseudoError(value, t)` |
| neuf `label(AppTexts t)` prenaient la langue **et renvoyaient du français en dur** | leur `switch` lit l'ARB ; le paramètre ne suffisait pas, c'est le corps qui comptait |
| `AvailabilitySlot.nomsDeJour` listait sept jours, `anniversaire_sheet` douze mois | `AppDates.weekdayName` et `AppDates.monthName`, bâtis sur une date de référence : plus aucune liste à tenir |
| `GroupRole` portait « Admin » et « Membre » | il ne porte **plus rien** : personne ne les lisait |
| `GroupMember.displayName` repliait sur « Membre » | `displayName(AppTexts t)`, comme `TaskAssignee` et `EventParticipant` |

Le bénéfice est immédiat sur les tests : `test/credentials_rules_test.dart`
éprouve les conditions **sans aucun `AppTexts`**, là où un message en dur
l'aurait obligé à en fabriquer un.

### Un provider qui assemble du texte prend la langue en argument de famille

`dayAgendaProvider` bâtit des lignes qui portent des phrases — « Personnel »,
« Terminée », « Journée », « X fête son anniversaire ». Un provider n'a pas de
`BuildContext` d'où les tirer, et `AgendaEntry` ne peut pas les porter sans
redevenir un sac de dix champs descriptifs.

La clé de famille devient donc `(DateTime, AppTexts)` — **exactement comme
`nowProvider` pour l'heure courante** : la dépendance est explicite, le
résultat reste mis en cache, et un changement de langue reconstruit les lignes
au lieu de les laisser dans l'ancienne. `agendaForSelectedDayProvider`,
`calendarCountersProvider`, `todayAgendaProvider` et `homeTaskRowsProvider`
suivent.

L'instance d'`AppTexts` est stable pour une locale donnée : `Localizations` la
met en cache, et la clé de famille ne change donc qu'au changement de langue.

### Une valeur par défaut ne peut pas lire le contexte

`PasswordField.label`, `GroupSelector.label`, `MembershipTermPicker.label`,
`AssigneePicker.titre`, `AppBottomNav.createLabel` et
`ExpandableOptions.title` passent à `null`, résolu au `build`. C'est le même
arbitrage que pour `AppCard`, `EventCard` et `NavBadge`, dont les couleurs par
défaut avaient dû quitter la liste de paramètres : **le contexte n'y existe
pas.**

### Les langues longues débordent, et le balayage le dit

**L'allemand est de 20 à 30 % plus long que le français**, et un débordement
ne se voit ni à l'analyse ni dans un test qui vise un texte. `test/langues_test.dart`
ouvre donc **30 écrans dans les quatre langues à 360 dp** — la largeur
minimale que le projet se donne — et échoue sur tout `RenderFlex overflowed`.

Ce n'est pas un test qui *vérifie* quelque chose en plus : c'est l'ouverture
de l'écran qui est le contrôle. Flutter consigne un débordement par
`FlutterError.reportError`, que le harnais de test transforme en échec, et le
message nomme le fichier et la ligne du widget fautif.

Quatre défauts trouvés, et **deux précédaient la traduction** :

| Où | fr | de | La cause |
| --- | --- | --- | --- |
| « Tout voir » d'un `SectionHeader` | **18 px** | 83 px | le `TextButton` était posé nu dans la `Row` |
| les deux boutons d'un créneau | **3 px** | 3 px | deux `IconButton` de 48 dp, passés en `compact` |
| plage horaire de la carte d'agenda | — | 16 px (en) | « 9:00 AM – 10:30 AM », voir ci-dessus |
| « Tout marquer comme lu » | — | 79 px | les `actions` d'un `AppBar` prennent leur largeur naturelle |

Les deux premières lignes disent l'essentiel : **ces écrans débordaient déjà
en français**, à 360 dp, et personne ne l'avait vu. Traduire n'a pas créé le
défaut, il a créé le balayage qui le trouve.

Les corrections sont structurelles — `Flexible` et `overflow: ellipsis`, la
règle du projet sur les `Row` — sauf pour l'`AppBar`, dont les actions ne sont
pas élastiques : le libellé y est borné à 150 dp, et les traductions ont été
raccourcies. Une borne, pas une traduction courte, parce qu'une traduction
courte est une convention que la cinquième langue ne connaîtra pas.

#### Deux de plus, et la seconde ne se corrigeait pas par un `Flexible`

Le balayage des 91 chaînes a rendu variables des textes qui étaient jusque-là
de largeur **constante**, et il en a trouvé deux autres :

| Où | La cause | La correction |
| --- | --- | --- |
| le libellé d'un `StatusDot` | il était en dur, donc de largeur fixe ; traduit, c'est un texte de longueur variable dans une `Row` | un `Flexible` en `loose` autour du `Text`, **dans `StatusDot`** et non aux onze sites d'appel |
| la ligne d'un créneau de disponibilité | 27 px en allemand | la pastille est passée **au-dessus** de l'horaire |

La seconde est la plus instructive. La ligne portait un mot de statut, une
plage horaire et deux boutons d'icône — et en allemand, `● Nicht verfügbar`,
`09:00 – 12:30` et les deux boutons demandent **314 px pour 296 disponibles**
à 360 dp. Mesuré avec les métriques d'Inter, pas avec la police du harnais de
test, qui rend chaque caractère large d'un cadratin et exagère : le compte est
juste même en vraie police, **le test n'était pas pessimiste**.

Aucun `Flexible` ne règle cela, et c'est le point : le flex ne sait pas dire
« rogne celui-ci en dernier ». Avec un seul enfant élastique, l'autre déborde ;
avec deux, le `flex` plafonne les deux *même quand il y a de la place*, donc
tronque en français aussi. **Un `Flexible` répare une `Row` sous-contrainte, il
ne répare pas une `Row` trop chargée.** La hauteur, elle, ne coûte rien sur cet
écran : la pastille monte d'une ligne, les deux textes restent entiers dans les
quatre langues, et les deux assertions qui visent `'Disponible'` et
`'09:00 – 12:00'` séparément continuent de passer.

**Règle** : quand le balayage redéborde après un `Flexible`, se demander ce que
la ligne porte de trop avant d'en rogner le contenu.

### Les quatre fichiers ARB ne peuvent pas diverger en silence

Une clé ajoutée au français sans traduction **ne lève pas** : `gen-l10n`
avertit, et l'application sert la valeur française. Trois contrôles tiennent
donc le contrat, dans `test/langues_test.dart` :

- **les mêmes clés**, exactement, dans les quatre fichiers ;
- **les mêmes paramètres et les mêmes branches `=N`.** Un paramètre renommé
  n'affiche rien, et une branche `=0` perdue ne se verrait qu'à zéro —
  c'est-à-dire sur un compte neuf, chez quelqu'un qui découvre
  l'application ;
- **aucune valeur française laissée en place** au-delà de deux mots. En deçà,
  l'identité est souvent juste — « Description » en anglais, « Admin »
  partout — et deux clés sont nommément exemptées.

**Le zéro n'est pas traité pareil d'une langue à l'autre**, et c'est le piège
des pluriels : le CLDR français met le singulier après 0 (« 0 tâche »), alors
que l'anglais, l'espagnol et l'allemand y mettent le pluriel (« 0 tasks »).
Les branches `one`/`other` suffisent donc, et les branches `=0` explicites
— « Aucune tâche » — sont traduites en toutes lettres.

### `AppTexts.of` se lit avant l'attente, jamais après

Après un `await`, le `BuildContext` peut avoir disparu — la garde du routeur a
pu quitter l'écran. C'est la règle déjà tenue pour `ScaffoldMessenger`, et
`use_build_context_synchronously` la signale : 38 membres déclarent donc
`final AppTexts t = AppTexts.of(context);` **en tête**, avant tout `await`.

### Les tests doivent brancher les délégués, **et épingler la langue**

Deux fichiers montent leur propre `MaterialApp.router` plutôt que `JelvoApp` :
sans `localizationsDelegates`, `AppTexts.of` n'a rien à rendre et **tout écran
qui lit un mot lève sur un `null`**. Hors widget, `AppTexts.delegate.load(const
Locale('fr'))` donne une instance.

Depuis qu'il y a quatre langues, tout harnais de widget surcharge en outre
`languageStorageProvider` avec `EphemeralLanguageStorage(langue: Locale('fr'))` :

```dart
languageStorageProvider.overrideWithValue(
  EphemeralLanguageStorage(langue: const Locale('fr')),
),
```

Sans cela, l'application suit la langue de la **machine de test** — `en_US`
sur le harnais —, et les 443 tests qui affirment des phrases exactes échouent
sur du bon anglais. C'est arrivé : 212 échecs d'un coup, tous du même défaut.

`test/langues_harnais.dart` porte le harnais partagé des tests de langue, et
c'est le seul endroit où la langue est un **paramètre** plutôt qu'un réglage
épinglé.

### Ce qui reste en dur, et pourquoi

Trente chaînes portent `// texte-en-dur-autorise: <raison>`, dans dix-neuf
fichiers. Le marqueur vaut pour sa ligne et les six qui la précèdent — une
longue chaîne est coupée en morceaux, et la raison s'écrit **une fois**,
au-dessus de l'instruction. Il demande une raison écrite : c'est ce qui
distingue une exception d'un oubli.

| Famille | Exemples |
| --- | --- |
| détail technique du mode diagnostic | `AuthException code=… — …`, `PostgrestException code=…` |
| console de développement | le bandeau `[jelvo:diagnostic]` |
| `toString()` de débogage | `AuthFailure`, `Anniversaire`, `EmojiRun` |
| état impossible | le `StateError` d'un profil absent |
| filtre ou colonnes PostgREST | `expires_at.is.null,expires_at.gt.…`, les listes de `select` |
| chemin dans un bucket | `$userId/avatar_….jpg` — le premier segment porte l'autorisation |
| clé de stockage | `sb-<hôte>-auth-token`, dont changer déconnecterait tout le monde |
| requête de média CSS | `(display-mode: standalone)` |
| chiffres sans mot | « 1:07 » d'un message vocal, « 09:00 – 12:00 » d'un créneau, un emoji suivi de son compte |
| nom d'une langue dans sa langue | `Français`, `Deutsch`, `English`, `Español` — les traduire ferait chercher « Allemand » à la lettre A dans une liste en espagnol |

Trois recopies de plus vivent dans `web/index.html`, inévitables puisqu'elle
est servie avant tout Dart : la clé de stockage, les trois mots d'apparence et
les deux fonds. `test/launch_screen_test.dart` les confronte au Dart — voir
« Le thème sombre ».

### Deux incohérences que l'extraction a mises au jour

Elles portaient sur **zéro**, et le CLDR français met le singulier après « 0 » :

- la carte « Mes tâches » de l'accueil disait « 0 tâches », là où `/taches`
  disait « 0 tâche » pour le même compte ;
- la carte des groupes communs disait « 0 groupes en commun », là où la
  pastille du carnet disait « 0 groupe ».

Un pluriel ICU ne peut pas dire deux choses du même nombre : le singulier
l'emporte, et deux tests ont changé d'attente.

### Les notifications système aussi, mais pas par l'ARB

Elles sont composées **en SQL**, par les déclencheurs de
`tranche5c_notifications_push.sql` et des suivantes : `Julie Martin vous
convie à Randonnée du lac Blanc` est écrit par `push_invitation_evenement`,
pas par Dart. Un fichier ARB ne pouvait donc rien pour elles, et l'écran de
verrouillage d'un téléphone allemand recevait du français.

La base dépose désormais une **clé de gabarit et des paramètres**
(`push_outbox.cle`, `push_outbox.params`), et le rendu se fait dans
`supabase/functions/envoyer-push/traductions.ts`.

#### La langue est une colonne de l'appareil, pas du compte

`push_tokens.langue`, renseignée par `enregistrer_push`. C'est le point qui
fait tenir le reste : **le réglage de langue vit sur l'appareil, et
`push_tokens` a une ligne par appareil** — les deux granularités coïncident
exactement. Une colonne `profiles.langue` aurait repris d'une main ce que le
réglage par appareil donne de l'autre.

Côté Dart, `langueEffectiveProvider` résout le choix délégué par la **même**
fonction que le `localeListResolutionCallback` — `LanguageStorage.resoudre` —,
et `pushRegistrationProvider` l'**observe** : changer de langue réenregistre
l'abonnement, et la notification suivante arrive dans la nouvelle langue.
Sans ce `watch`, elle n'aurait changé qu'à la session d'après.

#### Le rendu se fait dans la fonction Edge, et non dans le service worker

C'était la voie évidente, et elle est écartée pour trois raisons dont deux
rédhibitoires :

| | |
| --- | --- |
| **un service worker ne lit pas `localStorage`** | l'API est synchrone et n'existe pas dans un worker. Il faudrait une base IndexedDB écrite par la page, donc un **second stockage de la langue** à tenir d'accord avec `jelvo-langue` |
| **un worker installé est en cache** | une application ajoutée à l'écran d'accueil garde le sien jusqu'à sa mise à jour, et sur iOS cela peut demander de réinstaller. Le rendu n'y serait arrivé qu'à ceux qui réinstallent — la leçon des icônes et des écrans de lancement, payée deux fois |
| la fonction Edge **joint déjà `push_tokens`** | pour signer l'envoi : la langue y est sans une lecture de plus |

#### Le texte français reste déposé, et c'est le filet

`title` et `body` continuent d'être rédigés par chaque déclencheur. Une
fonction Edge peut être **en retard d'un déploiement sur la base** — c'est
arrivé, pendant trois mois —, et une clé qu'elle ne connaît pas retombe sur le
texte. Une file qui ne porterait qu'une clé n'enverrait alors plus rien du
tout.

#### Un horodatage part en ISO, jamais formaté

`to_char(…, 'DD/MM à HH24:MI')` est un format **français**. Les deux
paramètres qui portent un instant — `instant`, `heure` — arrivent donc en ISO,
et c'est `Intl.DateTimeFormat` qui écrit « 24/08 19:30 », « 08/24, 7:30 PM »
ou « 24.08., 19:30 », séparateur compris. `timeStyle: 'short'` pour une heure
seule, qui est le motif court du CLDR — celui que rend `DateFormat.jm` côté
Dart ; avec `hour: '2-digit'`, l'anglais écrivait « 07:30 PM », que personne
n'écrit.

Le fuseau reste **Europe/Paris**, comme pour les rappels et les
anniversaires : le schéma ne porte aucun fuseau par événement.

#### Un seul paramètre a un repli

`auteur` absent fait écrire « Quelqu'un » par l'envoyeur, dans sa langue. Les
autres — un titre de tâche, un nom de groupe — sont des **données**, et une
donnée absente fait **changer de clé** plutôt que de prendre une valeur par
défaut : `push.tache.confieeSansAuteur` et non `push.tache.confiee` avec un
trou. C'est la règle « on n'invente pas de sujet à la phrase », rendue
traduisible — une langue ne peut pas deviner qu'un paramètre va manquer.

Le titre suit la même logique : ce n'est pas un gabarit mais `params.titre`,
et `push.personnel` le remplace quand il n'y en a pas. Une seule règle, aucune
branche par type — y compris pour l'anniversaire, dont le titre est le nom de
la personne.

#### Ce qui a fait revenir le travail dans la tranche 5c

Il avait d'abord été écrit dans un `tranche14_notifications_traduites.sql`
séparé, et **un cluster monté pour l'occasion l'a réfuté** : la tranche 5c
rejouée ensuite — ce qui arrive dès qu'on la corrige — échoue net.

```
ERROR: cannot change return type of existing function
HINT:  Use DROP FUNCTION push_a_envoyer(integer) first.
```

`push_a_envoyer` y gagne trois colonnes de sortie, et `create or replace`
refuse de changer un type de retour : la 5c recréait l'ancienne, la 14 la
nouvelle, et **l'ordre des deux fichiers condamnait l'un ou l'autre**. Un
second fichier ne peut pas réparer le premier, puisque le premier est rejoué
sans lui.

Les trois signatures changent donc **dans la 5c**, chacune précédée de son
`drop function if exists` et suivie de son `grant` — la tranche 7 ne se
rejouant que si son propre contenu change. C'est exactement ce que le rejeu
par empreinte existe pour permettre, et ce que la tranche 3 a déjà fait deux
fois.

**Règle** : une migration qui change la signature d'une fonction qu'elle
possède déjà porte son `drop`, et se vérifie sur une base **déjà à jour** —
le rejeu sur base neuve part d'un catalogue vide, où un `drop` ne fait rien et
ne prouve donc rien.

#### Rien ne part avant que la fonction soit déployée

C'est le seul vrai prérequis de cette traduction : le SQL dépose la clé dès la
fusion, mais c'est `fonctions-supabase.yml` qui porte le rendu. Tant qu'il n'a
pas tourné, la fonction en place ignore `cle` et sert le texte français — ce
qui est précisément le filet décrit plus haut, et non une panne.

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
`event_invitation` et `birthday` → Calendrier, `task_assigned` et
`task_response` → Accueil, comme le reste : les tâches n'ont pas d'onglet, et
c'est de l'accueil que leur liste s'ouvre.

`birthday` va au **calendrier** et non aux contacts, parce que c'est là que
l'anniversaire se regarde : le carnet n'en montre pas la liste, et y envoyer
donnerait un chemin qui ne mène pas à ce qu'il annonce.
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
| `profiles` | tout sauf `id` — `anniversaire_jour` et `anniversaire_mois` compris, ajoutés en tranche 12 |

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

#### Le durcissement du stockage était sans effet — constaté le 21 novembre 2026

Le tableau ci-dessus décrivait l'intention, pas la base. Cinq politiques
posées **à la main dans l'éditeur SQL** quand les buckets ont été créés, avant
qu'il n'y ait des migrations, étaient toujours là :

| Politique | Ce qu'elle laissait faire à tout porteur d'un compte |
| --- | --- |
| `lecture chat media` | lire **tout** `chat-media`, sans condition d'appartenance |
| `maj avatars` | UPDATE sur les trois buckets **sans `with check`** — donc déplacer un objet |
| `ecriture avatars` | écrire dans les trois buckets à n'importe quel chemin |
| `suppression avatars` | supprimer tout objet dont on est le propriétaire, quel que soit le bucket |
| `lecture publique avatars` | redondante : `avatars_lecture` et `group_photos_lecture` ouvrent déjà ces deux buckets à `anon` |

**Les politiques RLS s'additionnent : elles ne se remplacent pas.** Poser
`chat_media_lecture` à côté de `lecture chat media` ne resserrait donc rien,
les deux étant évaluées en « ou ». La tranche 5b et la tranche 7 n'ont jamais
retiré que **leurs propres** politiques, par le `drop policy if exists` qui
précède chaque `create` — une habitude qui protège du rejeu, et qui ne voit
pas ce qu'elle n'a pas écrit.

Les deux premières se combinaient en une fuite complète : il suffisait de
connaître l'identifiant d'un groupe — et les identifiants circulent, c'est
écrit plus haut — pour lister son dossier, lire ses photos, ses vidéos et ses
messages vocaux sans en être membre, puis **déplacer** l'un d'eux vers
`group-photos`, qui est public en lecture. La photo privée devenait alors
lisible par n'importe qui, sans jeton.

C'est exactement le défaut que ce chapitre documente sous « Une politique
UPDATE sans `with check` autorise le déplacement » — présent une sixième fois,
et manqué parce que la politique n'était pas la nôtre.

**Ce qui l'a laissé passer, c'est le relevé.** `schema_actuel.sql` s'arrêtait
au schéma `public` : rien ne montrait les politiques de stockage, et la
tranche 5b avait dû **sonder** le bucket par deux requêtes HTTP pour savoir
s'il existait et s'il était privé. Une politique de trop ne se voit pas en
lisant les fichiers de migration — elle ne se voit qu'en lisant la base.
`extraire_schema.sql` relève donc désormais les trois buckets et toutes les
politiques de `storage.objects`, et une sixième politique apparaîtrait dans un
diff sur `main`.

**Deux règles** :

- **une politique qu'on resserre doit être retirée, pas doublée** ; un
  `create policy` ne dit rien de ce qui existe déjà à côté, seul `pg_policy`
  le dit ;
- **ce qui n'est pas relevé n'est pas vérifié.** La règle valait déjà pour les
  colonnes — c'est tout l'objet de `schema_actuel.sql` — et elle ne s'arrêtait
  au schéma `public` que par accident.

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
| Apparence (thème sombre) | **ajoutée** | trois choix — Clair, Sombre, Automatique — mémorisés sur l'appareil ; voir « Le thème sombre » |
| Langue | **ajoutée** | quatre langues, le choix mémorisé sur l'appareil, « Celle du téléphone » par défaut ; voir « Internationalisation » |
| Fuseau horaire | écartée | `profiles.timezone` **existe** et vaut `Europe/Paris`, mais **rien ne le lit** : les rappels sont rendus en Europe/Paris en dur, côté SQL. L'afficher laisserait croire à un réglage sans effet |
| Aide et support | écartée | il n'y a ni adresse de support ni page d'aide à ouvrir |
| Supprimer mon compte | **ajoutée** | obligation légale — voir « Suppression de compte ». Dans sa propre carte, rouge, avec chevron : elle **ouvre un écran** et ne supprime rien |

Les deux dernières se rejoignent : ce ne sont pas des chantiers techniques,
ce sont des décisions produit — quelle adresse, quel contenu — qui ne se
devinent pas.

### Les neuf types, rangés en trois familles

La ligne du haut **coupe tout** : sans autorisation, aucun type ne part, quel
que soit son interrupteur. Les trois suivantes détaillent.

| Famille | Types |
| --- | --- |
| Groupes et discussions | `chat_message`, `group_invitation` |
| Événements | `event_invitation`, `event_response`, `event_changed`, `birthday` |
| Tâches et rappels | `task_assigned`, `task_response`, `reminder` |

**Aucun type n'est fusionné en base.** `types_de_notification()` reste la
seule source ; une famille n'est qu'une liste de ses noms, et les neuf
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
- **Couleurs, typographie, ombres** : `context.couleurs.x`, `context.typo.x`,
  `context.ombres.x`. Aucune valeur statique, aucun `Color(0x…)` hors de
  `core/theme/`. Un modèle ou un provider ne choisit **jamais** une couleur :
  il dit ce que la chose est, le widget en tire la teinte.
- **Dates** : passer par `AppDates`, qui prend l'`AppTexts` — jamais
  `DateFormat` directement, et jamais un motif littéral : `'HH:mm'` écrirait
  « 14:00 » à un anglophone. `initializeDateFormatting()` est appelée **sans
  argument** dans `main()` ; un test qui formate une date doit faire de même.
- **Textes** : tout texte affiché vient de l'ARB et se lit
  `AppTexts.of(context).<cle>`. Un modèle ou un provider ne choisit **jamais**
  ses mots : il dit ce que la chose est, l'appelant en tire le libellé — même
  règle que pour les couleurs. `tool/verifier_textes.py` le tient.
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
  de l'en-tête qui ouvre les **paramètres** — et l'absence de celui du
  calendrier, qui doublait l'onglet de la barre du bas —, la bande des
  groupes — nom, nombre de membres,
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
- `test/profil_consultable_test.dart` couvre le profil de quelqu'un d'autre.
  Sans widget : les cinq champs publics lus sous les noms de colonnes de la
  fonction SQL — c'est là que se verrait un changement de vocabulaire, les
  deux parseurs réutilisés cessant de la lire —, l'avatar prédéfini qui arrive
  déjà composé, l'absence de relation qui n'est pas une relation vide, une
  demande reçue distinguée d'une envoyée, et **le contrôle qui porte la
  consigne** : `statistiques` et `disponibilite` nuls restent nuls, et non
  « inconnu », qui dirait « rien de déclaré » là où l'absence dit « pas votre
  affaire ». Côté écran : les cinq champs, **aucune adresse e-mail** — le seul
  « @ » de l'écran est celui du pseudo —, l'absence des trois boutons de son
  propre profil, la pastille de disponibilité pour une contact, **aucune
  statistique même pour une contact** — le contrôle négatif du retrait —, le
  non-contact qui garde les champs publics **sans qu'une phrase annonce ce
  qu'on lui retient**, « Inconnu » qui ne s'affiche pas comme une donnée,
  l'identifiant inconnu et la lecture qui échoue. Côté groupes
  communs : la liste, le singulier, et **zéro qui se dit**. Côté actions : les
  cinq relations et leur écriture, le retrait qui se confirme — avec le
  contrôle négatif d'un « Annuler » qui n'écrit rien —, et son propre profil
  qui n'offre aucune action de relation et **n'y montre pas non plus les
  statistiques**, qui apparaissent une fois sur « Mon profil ». Côté points d'entrée : le nom dans le
  carnet, le nom d'un membre dans un groupe, et le chevron du carnet qui, lui,
  ouvre toujours la fiche. Celui de la conversation vit dans
  `test/chat_test.dart`, avec ses messages.
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
  Côté écran refondu : l'en-tête qui porte le nom et l'effectif **sans aucun
  pictogramme d'appel**, l'en-tête et le chevron qui mènent tous deux au
  groupe, les deux compteurs de la barre de raccourcis — sans liste ni
  dépense —, le groupe sans rien qui ne dit pas « 0 tâche » tout en gardant
  son chevron, le séparateur qui coiffe chaque journée, et le changement de
  jour qui recoupe la série. Côté couleurs : deux expéditeurs, deux teintes,
  et jamais le gris de légende qui ne distinguait personne.
  Côté emojis : le panneau qui s'ouvre et se referme, l'emoji inséré **à
  l'endroit du curseur** plutôt qu'à la fin, et le cœur tapé au clavier qui
  ressort de la bulle avec la police d'emojis en principale — le texte autour
  gardant la sienne. Côté messages vocaux : le micro
  qui remplace l'avion tant qu'on n'a rien écrit, l'enregistrement envoyé en
  `audio` avec sa durée et le chemin à la convention du bucket, l'annulation
  qui n'envoie rien, le micro refusé qui renvoie aux réglages du navigateur,
  la bulle qui annonce sa durée **sans rien télécharger**, et l'écoute qui
  demande l'URL signée.

- `test/push_notifications_test.dart` couvre les réglages de notification :
  l'activation qui enregistre l'abonnement en base, le refus et sa marche à
  suivre, la désactivation des deux côtés, la consigne d'installation iOS sans
  bouton, les huit types désactivables, l'interrupteur qui revient si l'écriture
  échoue, et le réenregistrement au démarrage. Côté écran refondu : les trois
  cartes titrées, l'absence de toute ligne qui ne mènerait nulle part, le
  rangement des huit types dans leurs trois familles, le changement de mot de
  passe enfin atteignable, et la version annoncée par « À propos ».
- `test/emoji_font_test.dart` couvre la police d'emojis et son câblage : la
  variante COLRv1 au dépôt, le repli posé sur tous les styles de l'échelle et
  sur le thème, puis **le découpage** — le cœur du clavier qui devient un
  emoji quand `❤` nu n'en est pas un, un emoji composé qui reste d'un seul
  tenant (famille, ton de peau, séquence ZWJ), un drapeau qui n'est pas deux
  lettres, le texte et les emojis séparés dans l'ordre, `©` et `1` qui restent
  du texte quand `1️⃣` n'en est pas, et `⬜` que la seule règle du sélecteur
  laisserait passer. Côté widget : un texte sans emoji qui reste un `Text`
  ordinaire, un cœur qui reçoit bien la police en **principale** avec son
  repli vidé, un emoji seul qui garde un `Text`, et le champ de saisie qui
  colore ce qu'on tape.
- `test/dark_theme_test.dart` couvre le thème sombre. Les contrastes sont
  **recalculés** dans le test plutôt que recopiés en commentaire : un chiffre
  écrit à la main ne proteste jamais quand il devient faux. Sont éprouvés le
  texte à 4,5:1 sur les deux fonds, les teintes fonctionnelles sur leur fond
  teinté — des deux côtés, y compris en clair où elles échouaient —, l'encre
  des aplats saturés, les huit teintes d'expéditeur, les six accents de groupe
  sous une icône blanche, et la bulle de l'utilisateur qui garde son encre
  blanche. Côté réglage : « Apparence » annonce le choix courant, la feuille
  propose les trois et dit qu'ils ne valent que sur cet appareil, choisir
  « Sombre » bascule l'écran **et** s'enregistre, et une apparence déjà
  enregistrée s'applique dès le premier rendu, et **changer d'apparence le dit
  à la page** — « Sombre » puis le retour à « Automatique », par un faux pont
  qui retient ce qu'on lui dit. Le crochet ne se constaterait sinon que sur
  l'appareil de quelqu'un. Enfin le contrôle négatif : un widget sans notre
  thème se rend en clair plutôt que de lever.
- `test/launch_screen_test.dart` tient le contrat entre `web/index.html` et le
  Dart, sans widget : la clé de stockage lue est celle de `ThemeStorage`, les
  trois mots d'apparence sont parcourus depuis `ThemeMode.values` — une valeur
  ajoutée à l'énumération fait donc échouer le test —, les deux fonds de la
  page sont ceux de `JelvoColors`, et le violet de la marque n'est plus la
  couleur du bandeau. Côté écran de lancement : le voile et le logo fourni,
  qui doit exister au dépôt, le relais sur `flutter-first-frame` plutôt que
  sur une minuterie, et le retrait du document plutôt qu'une simple
  transparence. Côté bandeau : la requête de média qui couvre le mode
  Automatique sans script, la déclaration propre à l'iOS installé que
  `theme-color` ne couvre pas, et — c'est le mécanisme qui le fait suivre à
  chaud depuis iOS 26 — **le fond posé en clair sur `html` et sur `body`**, et
  non seulement en méta. Côté écrans de lancement d'iOS : il y en a **deux, un
  par apparence**, chaque fichier a sa balise et chaque balise son fichier, et
  le contrôle négatif qui empêche la liste de modèles de revenir — **aucune
  déclaration ne porte de dimension**. Les deux images sont **décodées** pour
  vérifier que ce sont des aplats de la teinte de `JelvoColors` : un logo qui y
  reviendrait ramènerait les deux tailles à faire coïncider, et un nom de
  fichier ne le dirait pas. Leur proportion est celle des iPhone, non une
  taille de modèle. Côté préparation : sans session l'application est prête
  tout de suite, et le
  contrôle négatif qui compte — **avec** session, elle ne l'est pas avant que
  les quatre lectures aient répondu, ce qui est exactement l'instant où
  l'accueil s'affichait vide.
- `test/anniversaires_test.dart` couvre les anniversaires. Sans widget : la
  règle du jour fêté sur une table de cas — 29 février bissextile et ordinaire,
  **1900 et 2000**, décembre qui franchit l'année —, ce qui est une date et ce
  qui n'en est pas (30 février refusé, 29 accepté), une **moitié de date** qui
  vaut une absence, le libellé sans année qui ne glisse pas au 1er mars, et
  **la confrontation des deux tables de cas** : la règle vit en SQL et en Dart,
  et le test vérifie que `fumee.sql` éprouve les mêmes dates — faute de quoi la
  coïncidence se déferait sans que rien ne proteste. Côté notification :
  l'onglet Calendrier, l'absence de bouton d'action, un type voisin qui ne
  devient pas un anniversaire, et la famille « Événements » qui le porte sans
  qu'il tombe dans « Autres ». Côté saisie : la ligne vide qui **invite** au
  lieu d'afficher une fausse date, la date affichée sans aucune année à
  l'écran, la feuille qui annonce ne pas demander l'année et **ne porte aucun
  sélecteur de date**, l'enregistrement de la paire, le contrôle négatif d'une
  moitié de date qui n'écrit rien, « Retirer » absent sans valeur puis qui
  efface **vraiment** — un drapeau distingue « appelé avec null » d'une
  inertie —, l'échec qui reste dans la feuille avec son message, le 29 février
  qui annonce ce qu'il fera les autres années, et un jour devenu impossible
  ramené plutôt que vidé en changeant de mois. Côté calendrier : la ligne au
  bon jour et sur toute la journée, son absence les autres jours, le 29 février
  fêté le 28 en 2026 et le 29 en 2028, **personne sans date qui ne produit
  aucune ligne**, et l'ambre de la palette plutôt qu'une teinte nouvelle.
- `test/suppression_compte_test.dart` couvre la suppression de compte. Côté
  chemin : la ligne existe dans les paramètres et **ouvre un écran sans rien
  supprimer**, les deux listes y sont — l'adresse e-mail et les messages
  vocaux du côté qui part, la signature « Compte supprimé » et les photos du
  côté qui reste —, et la réinscription est annoncée. Côté confirmation : un
  bouton sans mot de passe n'agit pas, **un mot de passe faux ne supprime
  rien** — le contrôle qui dit que la vérification n'est pas décorative —, le
  bon referme la session, et un refus de la base reste sur l'écran avec son
  message, session intacte. Côté conversation : son message survit, signé
  « Compte supprimé » et **non « Membre »**, et son nom n'ouvre plus de
  profil.
- `test/signalements_test.dart` couvre le signalement d'abus **et le
  blocage**. Côté blocage, sans widget : les mots d'état qui disent la réponse
  et non une panne, un mot inconnu de la base qui ne lève pas, et **`JB001`
  qui a son propre message** — le contrôle qui dit que « permission refusée »
  n'est pas la bonne phrase. Côté écran : le menu du profil qui l'offre, la
  confirmation qui dit ce que le blocage fait, « Annuler » qui n'écrit rien,
  **le cas délicat qui se dit** — « vous partagez un groupe » et « quittez le
  groupe » — avec son contrôle négatif, la phrase absente quand aucun groupe
  n'est partagé. Côté liste : la ligne des paramètres qui annonce le compte,
  **zéro qui ne s'affiche pas**, l'état vide qui dit où l'on bloque, et le
  déblocage qui se confirme en disant ce qui ne revient pas. Côté sélecteur :
  une personne bloquée qui n'est plus proposée en assignée, avec **le contrôle
  négatif qui compte** — sans blocage, elle l'est.
- `test/signalements_test.dart` couvre aussi le signalement. Sans widget :
  « déjà signalé » qui **n'est pas une réussite et n'est pas une panne**, un
  mot d'état inconnu du client qui ne lève pas, les quatre seuls mots qui
  comptent pour une réussite, les six motifs qui portent un libellé et une
  aide pris dans l'ARB, et la lecture d'une ligne — la recopie, `auteur_nom`
  nul qui **est** une information, et un média recopié qui n'a pas de texte
  sans que ce soit un vide. Côté signalement : la feuille ouverte depuis un
  message d'autrui avec ses deux phrases — celle qui dit que la personne n'est
  pas prévenue, celle qui dispense de la capture d'écran —, **son propre
  message qui ne l'offre pas**, le contrôle négatif d'un envoi sans motif qui
  n'écrit rien, la cible et le motif qui arrivent au dépôt, « déjà signalé »
  qui **reste dans la feuille** au lieu de se refermer, un groupe signalé
  depuis son menu, un profil signalé — et **jamais le sien**, dont le menu
  n'existe pas. Côté modération : la ligne des paramètres absente sans être
  modérateur, présente avec, **l'URL forcée qui donne un écran vide et non un
  accès**, la carte qui porte qui signale et qui est visé, un compte supprimé
  qui signe le dossier sans le faire disparaître, un message effacé depuis le
  signalement qui se dit — la recopie restant lisible, ce qui est toute sa
  raison d'être —, et un groupe signalé qui annonce que la note est le seul
  levier. Côté action : la suppression qui se confirme avec son contrôle
  négatif, la note demandée **avant** l'écriture, la ligne qui sort de la file
  et l'archive relue avec elle, « Annuler » sur la note qui ne traite pas —
  le contrôle qui distingue `null` de la chaîne vide —, la réouverture qui ne
  redemande pas de note, et une lecture qui échoue qui le dit au lieu de se
  rendre vide.
- `test/app_version_test.dart` confronte `AppConfig.version` au `pubspec.yaml`,
  sans widget : la version est recopiée à la main, et une version fausse est
  pire qu'une version absente.
- `test/langues_test.dart` couvre les quatre langues. **Le contrat entre les
  fichiers ARB** : les mêmes clés, les mêmes paramètres, les mêmes branches
  `=N`, aucun pluriel aplati en phrase fixe, et aucune valeur française
  laissée en place au-delà de deux mots — deux clés exemptées, nommément.
  Côté réglage, sans widget : ce qui est écrit est un code et non un rang, un
  stockage abîmé suit le téléphone plutôt que de lever, `es_MX` donne
  l'espagnol, une langue inconnue donne **l'anglais et non le français**, et
  la clé de stockage ne change pas. Côté écran : l'application qui suit le
  téléphone, l'anglais servi à un téléphone japonais, un choix enregistré qui
  l'emporte, la ligne « Langue » qui annonce « Celle du téléphone » plutôt
  que « Français » quand rien n'est choisi — ce n'est pas un choix, c'est une
  délégation —, la feuille qui nomme chaque langue dans sa langue, le
  basculement en allemand qui change l'écran **et** s'enregistre, et le
  retour au téléphone. Côté dates : l'heure en 24 h d'un côté et en 12 h de
  l'autre, les « de » que l'espagnol intercale, et le mois sans année qui n'en
  porte dans aucune langue. Côté salutation : le week-end, le soir qui
  l'emporte sur lui, **aucune fête nationale** — le contrôle porte sur
  l'énumération, quatre moments et pas un cinquième —, et l'après-midi
  espagnol qui commence plus tard. Enfin **30 écrans ouverts dans les quatre
  langues à 360 dp**, où l'ouverture est le contrôle : c'est ce balayage qui a
  trouvé quatre débordements, dont deux antérieurs à la traduction.
- `test/notifications_traduites_test.dart` couvre les notifications système
  dans les quatre langues. **Le contrat entre `traductions.ts` et le SQL** :
  le fichier TypeScript est **lu**, pas recopié — les quatre langues portent
  les mêmes clés et les mêmes paramètres, aucune ne laisse traîner le
  français, toute clé que le SQL dépose y est connue, et tout gabarit a un
  déposant **sauf les deux que l'envoyeur rend lui-même** (`push.personnel`,
  `push.quelquun`). Puis les invariants de la migration : la langue est une
  colonne de l'appareil et non du compte, elle n'est jamais écrasée par un
  client plus ancien, les horodatages partent en ISO, les trois signatures
  changées portent leur `drop` — **le contrôle qui vient d'un échec réel** —
  et leurs `grant` sont reposés. Côté application : la langue part avec le
  réenregistrement du démarrage, et **changer de langue réenregistre**.
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

Quinze faux vivent dans `test/fakes/` — douze dépôts, l'enregistreur et le
lecteur audio (`fake_voice.dart`), et le pont vers la page (`fake_pont_navigateur.dart`), sans lesquels ouvrir la conversation
lèverait une `MissingPluginException` : un test de widget n'a ni micro ni
haut-parleur. La liste : authentification, profil, groupes,
contacts, notifications, tâches, agenda, disponibilités, chat, signalements,
navigateur (`FakePushService`) et préférences de notification. **Tous les
fichiers de test les surchargent tous** — un provider oublié tombe sur
`Supabase.instance`, absent en test.

`FakeSignalementRepository` **déplace vraiment la ligne** quand on la traite,
au lieu de se contenter de compter l'appel : sans cela, l'assertion « un
signalement traité ne revient plus » passerait parce que rien n'a été relu, et
non parce que la règle tient.

`FakeChatRepository` simule le temps réel par un `StreamController` : un vrai
canal Realtime demande une socket, que le harnais de test n'a pas. Ce qui est
éprouvé, c'est donc que **l'écran réagit au signal** — pas que le signal
arrive, ce qui ne se vérifie qu'à l'usage.

L'oubli ne se voit pas toujours : un `AsyncNotifier` qui échoue à la
construction donne un `AsyncValue` en erreur, dont le `.value` nul retombe sur
la liste vide de repli. L'écran s'affiche, vide, et le test passe pour de
mauvaises raisons.

Cinq points à respecter dans tout nouveau test de widget :

1. Surcharger l'horloge — les données de démonstration et les libellés
   « Aujourd'hui »/« Demain » en dépendent :
   ```dart
   ProviderScope(
     overrides: [clockProvider.overrideWithValue(FixedClock(dateFigee))],
     child: const JelvoApp(),
   )
   ```
   **Et épingler la langue au français**, juste à côté : sans cela
   l'application suit celle de la machine de test, et un test qui affirme une
   phrase échoue sur du bon anglais.
   ```dart
   languageStorageProvider.overrideWithValue(
     EphemeralLanguageStorage(langue: const Locale('fr')),
   ),
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
  exécution. Les photos, elles, sont complètes : vignette et plein écran, et
  les messages vocaux aussi : enregistrement, envoi et lecture.
- **Les messages vocaux n'ont été éprouvés que par les tests.** Ils passent par
  `record` et `just_audio`, deux paquets qui embarquent du natif : comme
  `mobile_scanner`, ni la cible Android ni la cible iOS n'ont pu être compilées
  ici. Sur le web, le format dépend du navigateur — voir « Messages vocaux ».
  Le point à surveiller est **la lecture croisée** : un navigateur qui
  n'accepte que l'Opus en WebM produit un fichier qu'un Safari ancien peut
  refuser de lire, la prise en charge de WebM y étant récente et variable
  selon la version. L'inverse ne pose pas de question — l'AAC se lit partout.
  C'est précisément pourquoi l'encodeur est négocié **AAC d'abord** : les
  navigateurs qui savent l'écrire, Safari comme les Chrome récents, produisent
  alors un fichier universel, et le repli WebM ne sert que ceux qui n'ont pas
  le choix. La solution complète serait un transcodage côté serveur, qu'aucune
  fonction Edge ne fait aujourd'hui.
- **Le temps réel n'est pas éprouvé automatiquement.** Les tests simulent le
  flux par un `StreamController` ; qu'un événement arrive réellement dépend de
  la publication `supabase_realtime` et d'une socket, et ne se constate qu'à
  l'usage. Un défaut de publication est muet : le canal s'abonne et rien
  n'arrive.
- Les notifications sont **relues à la demande**, pas poussées : la liste se
  rafraîchit à l'ouverture de l'écran, au geste de traction et après chaque
  action. Le temps réel et les notifications système (`push_tokens`) ne sont pas
  au périmètre.
- **L'application est en quatre langues** — français, anglais, espagnol,
  allemand —, elle suit celle du téléphone, retombe sur l'anglais, et le
  choix se règle dans les paramètres et se mémorise sur l'appareil. 985 clés
  dans quatre fichiers, 162 paramétrées, 25 pluriels ICU ;
  `tool/verifier_textes.py` fait échouer la CI si un texte en dur revient, et
  `test/langues_test.dart` si les quatre fichiers divergent.

  **Les notifications système suivent aussi**, mais par un autre chemin : la
  base dépose une clé et des paramètres, la langue voyage avec l'abonnement
  (`push_tokens.langue`), et le rendu se fait dans la fonction Edge — voir
  « Les notifications système aussi, mais pas par l'ARB ». Deux réserves :
  **rien ne change tant que `fonctions-supabase.yml` n'a pas déployé**, et il
  ne le peut pas aujourd'hui — `SUPABASE_ACCESS_TOKEN` est refusé en `401`,
  premier des prérequis manuels ci-dessous. D'ici là la fonction en place
  ignore la clé et sert le texte français, qui reste déposé exprès ; et ces phrases vivent dans
  `supabase/functions/envoyer-push/traductions.ts`, hors de l'ARB, parce que
  l'application ne les affiche jamais. Un test confronte les quatre langues
  entre elles et aux clés que le SQL dépose réellement.

  Trois réserves de plus : les traductions n'ont été relues **que par
  l'auteur**, pas par un locuteur natif ; le balayage des débordements porte
  sur 30 écrans à 360 dp, et non sur tous les états de chacun — une liste
  très longue ou un nom de groupe inhabituel peut encore déborder ailleurs ;
  et l'espagnol et l'allemand n'ont été vus que sur un **rendu de test**,
  jamais sur un appareil.
- Tâches et événements ont leur écran de détail (`/taches/:id`,
  `/evenements/:id`), leur formulaire en feuille et leur liste (`/taches`).
  Restent hors périmètre : les notifications système, et la modification d'une
  seule occurrence d'un élément récurrent — la `rrule` vaut pour toute la
  série.
- **Cinq prérequis manuels subsistent, et rien ne les remplace :**
  0. **régénérer `SUPABASE_ACCESS_TOKEN`** — le secret existe mais est refusé
     en `401`, et la fonction Edge n'a donc **pas été déployée depuis le
     19 août** (API Supabase : `version: 9`). Supabase → Account → Access
     Tokens, puis le reposer dans les secrets du dépôt. Tant qu'il n'est pas
     refait, les notifications système partent en français quelle que soit la
     langue de l'appareil, et `appliquer_adhesions_echues()` comme
     `empiler_anniversaires()` ne sont pas appelées. Voir « Et `--yes` n'a pas
     suffi » ;
  1. faire émettre `{{ .Token }}` au modèle d'e-mail de confirmation, pour le
     code à 6 chiffres ;
  2. ~~planifier `envoyer-push` toutes les minutes~~ — **c'est fait, et
     constaté le 20 novembre 2026.** La tâche `pg_cron` nº 1 existe,
     s'appelle `envoyer-push`, est `active`, et tourne `* * * * *` : 120
     passages en deux heures, dont **117 réponses `202`** portant l'accusé de
     réception de la fonction, et une file à zéro en attente vidée en sept
     secondes. Ce prérequis a été annoncé comme manquant pendant des mois
     alors qu'il était posé depuis le début ; cette ligne est ce qui le
     faisait répéter. **Ne plus le redemander.**
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

  4. **désigner un modérateur**, sans quoi personne ne lit les signalements.
     Une ligne à passer une fois dans l'éditeur SQL du projet, prête à copier
     dans `supabase/designer_moderateur.sql`. Elle n'est pas dans le
     manifeste, et ne peut pas l'être : **le dépôt est public**, et elle
     porterait une adresse e-mail ou un identifiant. Tant qu'elle n'est pas
     passée, la ligne des paramètres n'apparaît pour personne et la file ne
     rend rien — mais les signalements se déposent et attendent dans la table.
     C'est l'état sûr par défaut, non une panne. Voir « Signaler un abus ».

  Les migrations, elles, s'appliquent seules à chaque push sur `main`.
- **Une migration n'est éprouvée contre la vraie base qu'après fusion.** Le
  workflow qui l'applique ne peut pas tourner sur une pull request — le dépôt
  est public et le secret y serait exposé. Avant fusion, il reste
  `supabase/verification/rejouer.sh`, sur schéma factice : il compile *et*
  appelle les fonctions, mais son décor est recopié de cette documentation, et
  ne dit donc rien des colonnes réelles. C'est `supabase/schema_actuel.sql`,
  relevé après coup, qui fait foi.
- Le test de fumée couvre les tranches 3, 3b, 4, 5a, 5b, 5c, 5d, 6, 8, 13, 14,
  15 et 16 — dont, pour la 13, deux contrôles qui portent sur la **signature** de
  `profil_consultable` plutôt que sur une valeur : aucun appel ne révélerait
  une colonne de trop, qu'elle porte une adresse e-mail ou des compteurs
  retirés. Pour la 14, c'est **la confrontation du catalogue au code** : toute
  clé étrangère pointant vers `profiles` doit avoir un sort décidé, si bien
  qu'une table ajoutée plus tard et oubliée fait échouer le rejeu ; plus les
  deux contrôles négatifs qui comptent — un message ordinaire survit, et une
  notification qui ne nomme pas le compte supprimé n'est pas purgée avec les
  autres. Plus
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
- **Les disponibilités se lisent à la création d'un événement et sur le profil
  d'un contact** — voir « Le profil de quelqu'un d'autre ». Ce qui reste : le
  statut n'apparaît ni sur la fiche d'un contact, ni dans la liste du carnet.
  C'est la suite naturelle, et elle ne demande aucun SQL de plus —
  `statuts_de_disponibilite` accepte déjà une liste.
- **Le profil de quelqu'un d'autre est livré**, avec sa règle d'accès tenue
  par la base. Deux réserves. D'abord, les cinq champs publics sont lisibles
  par **tout compte authentifié qui connaît l'identifiant** : c'est la consigne
  produit, et `chercher_profils_par_pseudo` les rendait déjà énumérables, mais
  cela se dit. Ensuite l'écran n'a été éprouvé que par les tests : les huit
  contrôles du rejeu portent sur la fonction SQL, et la **vraie** base ne la
  voit qu'après fusion, comme toute migration ici.

  Les trois statistiques ont été retirées de cet écran **et de la base** après
  une version : elles n'apprenaient rien sur quelqu'un d'autre, et leur
  promesse — ouvrir la liste qu'elles résument — ne se transposait pas. Elles
  restent sur « Mon profil ».
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
- **Un seul endroit dessine le logo de lancement**, et c'est ce qui a supprimé
  le saut de taille : les captures par modèle ne pouvaient pas y suffire, et
  la liste de douze iPhone a été retirée. Les images de lancement sont deux
  aplats, et **rien ne dépend d'elles**. Tout est éprouvé dans un vrai
  navigateur, mais **rien ne l'a été sur un vrai iPhone** : ni l'aplat, ni le
  bandeau ne s'observent ailleurs. Deux réserves qui comptent : une
  application **installée avant ce changement ne l'a jamais lu**, iOS figeant
  ses métadonnées — il faut retirer l'icône et réinstaller —, et la
  **transition d'ouverture d'iOS** reste celle du système.
- **Le bandeau de la barre d'état ne suit le thème à chaud qu'à partir d'iOS
  26.** C'est là que WebKit a cessé de lire `theme-color` et
  `apple-mobile-web-app-status-bar-style` pour échantillonner le fond de la
  page, que l'application pose désormais en clair sur `html` et `body`. Sur
  iOS 25 et avant, la méta est lue **au lancement et jamais relue** : il n'y a
  pas de correctif, seulement un contournement — `black-translucent` — qui
  imposerait un texte de barre d'état toujours blanc, illisible sur le fond
  clair. C'est une limite de la plateforme, pas un chantier en attente.
- **Le thème sombre est livré**, avec son réglage. Deux réserves : les
  captures ont été relues écran par écran mais **sur un rendu de test**, pas
  sur un vrai appareil ; et une photo de couverture très sombre, fournie par
  l'utilisateur, reste sombre — le voile noir et les pastilles blanches
  gardent le titre lisible, mais la carte a moins de relief qu'en clair.
- **`profiles.timezone` existe et n'est lu par personne.** Les rappels sont
  rendus en Europe/Paris en dur, côté SQL. Offrir un sélecteur de fuseau
  demanderait de le lire dans `empiler_rappels` **et** de formater les dates
  côté client dans cette zone — deux chantiers, pas un réglage.
- **Les anniversaires sont livrés** — voir leur section. Leur envoi a demandé
  une correction qui n'était pas dans leur périmètre : le déploiement de la
  fonction Edge échouait depuis le 23 août, si bien que `empiler_anniversaires`
  n'aurait jamais été appelée. Voir « Le déploiement de la fonction a échoué en
  silence pendant trois mois ». Quatre réserves :
  ~~il n'existe pas d'écran de profil d'autrui~~ — **la tranche 13 l'a
  apporté**, et la date y figure ; la carte d'agenda de l'accueil et les pastilles de la
  semaine ne les montrent pas ; l'envoi du jour se fait en **Europe/Paris** en
  dur, comme les rappels, si bien que quelqu'un à l'autre bout du monde est
  prévenu à l'heure de Paris ; et la règle du jour fêté vit **des deux côtés**,
  en SQL pour l'envoi et en Dart pour le calendrier, faute de pouvoir demander
  une date par année affichée — ce sont les tables de cas, confrontées par un
  test, qui tiennent les deux d'accord.
- **Rien ne prévient que l'anniversaire d'un contact approche.** La
  notification part le jour même et pas la veille : ajouter une avance
  demanderait de choisir laquelle, et ce n'est pas une décision technique.
- **La suppression de compte est livrée** — voir sa section. Quatre réserves.
  D'abord l'**opération n'est pas atomique** : le stockage ne pouvant être
  vidé que par l'API Storage, les fichiers partent avant l'appel SQL, et une
  interruption entre les deux laisse un compte entier dont les vocaux sont
  déjà partis. La personne peut réessayer, c'est le sens de cet ordre-là.
  Ensuite une trace de l'adresse e-mail **subsiste dans le journal d'audit de
  gotrue** (`auth.audit_log_entries.payload`, avec l'adresse IP) : c'est un
  journal d'exploitation que Supabase fait tourner sur une fenêtre glissante,
  il n'est pas réécrit, et c'est un choix — réécrire un journal
  d'authentification est une intrusion, et il sert aussi à constater un accès
  frauduleux. Puis les notifications **déjà empilées** qui la nomment peuvent
  encore partir : la file se vide chaque minute, la fenêtre est donc d'au plus
  une minute, et rien de ce qui est déjà délivré ne se rappelle. Enfin l'écran
  n'a été éprouvé que par les tests et le rejeu sur base jetable : la **vraie**
  base ne voit la migration qu'après fusion, comme toujours ici.
- **Le signalement d'abus est livré** — voir sa section. Cinq réserves.
  D'abord **personne n'est modérateur tant que la ligne de désignation n'a pas
  été passée** : c'est le cinquième prérequis manuel, et jusque-là les
  signalements s'accumulent sans être lus. Ensuite, **la modération ne sait
  agir que sur un message** : fermer un compte et supprimer un groupe ne se
  font pas d'ici, et la note est le seul levier pour un groupe ou un profil —
  ce sont des décisions produit, pas un chantier technique. Puis **le fichier
  d'un média supprimé reste dans le bucket** : seule l'API Storage l'efface, et
  un modérateur n'a pas de session de l'auteur — même limite que pour la
  suppression de compte, sans la parade qu'elle a (l'intéressé fait le retrait
  lui-même avant l'appel SQL). Ensuite **rien ne prévient le modérateur** qu'un
  signalement est arrivé : il faut ouvrir l'écran. Une notification relèverait
  de la file de la tranche 5c et n'est pas au périmètre — et elle serait
  trompeuse tant que la fonction Edge n'est pas déployée. Enfin l'écran n'a été
  éprouvé que par les tests et le rejeu sur base jetable : la **vraie** base ne
  voit la migration qu'après fusion, comme toujours ici.
- **Le blocage est livré** — voir sa section. Quatre réserves. D'abord **il ne
  touche pas un groupe partagé** : la personne y reste visible, la
  conversation ne change pas, et l'écran le dit au lieu de le taire. Ce n'est
  pas une limite technique mais un choix — masquer ses messages ferait de la
  conversation des réponses à des propos invisibles, et l'exclure du groupe
  est l'affaire d'un administrateur. Ensuite **la personne bloquée n'est pas
  prévenue, et le prétendre serait faux** : elle continue de voir l'autre dans
  un groupe partagé et en tirera la conclusion ; ce qui est garanti, c'est
  qu'elle ne lira plus sa bio, son anniversaire ni sa disponibilité. Puis
  **les assignations déjà posées restent** — la consigne porte sur ce qui ne
  sera plus possible —, et **débloquer ne rend ni le lien de contact ni les
  invitations supprimées**. Enfin l'écran n'a été éprouvé que par les tests et
  le rejeu sur base jetable : la **vraie** base ne voit la migration qu'après
  fusion.
- **Les contrôles de non-contournement portent sur le rejeu, pas sur la
  production.** Que `signalements` soit hors de portée de PostgREST est
  éprouvé sous `authenticated` dans `fumee.sql` — `insufficient_privilege`
  sur la lecture comme sur l'inscription d'un modérateur. Ce n'est pas la même
  chose qu'un appel HTTP réel contre le projet, qui ne peut être fait
  qu'**après** fusion ; c'est la limite de tout le SQL de ce dépôt.
- **Les trois trous du détecteur sont refermés, et les 91 chaînes qu'ils
  laissaient passer sont traduites** — voir « Puis 91 de plus ». Ce qui reste
  n'est pas un trou connu mais la limite de la méthode : la détection se fait
  **par la position**, et une chaîne qui n'occupe aucune position de texte
  reconnue ne sera signalée que si elle fait deux mots ou ressemble à un
  libellé. Un paramètre nommé au nom inattendu — ni `label`, ni `titre`, ni
  `message`, ni `name`… — portant un mot seul en minuscules passerait encore.
  La parade n'est pas un motif plus large, qui rendrait le vert comme les trois
  fois précédentes : c'est d'ajouter le nom à `PARAMETRES` le jour où il
  apparaît.
- **Les sessions actives ne sont pas listables depuis le client** : gotrue ne
  les expose qu'à la clé `service_role`. Il faudrait une fonction Edge.
- `google_fonts` télécharge Inter au premier lancement. Pour un fonctionnement
  hors ligne garanti, il faudra embarquer la police dans `assets/`.
- Les dossiers `android/` et `ios/` sont générés et configurés (`com.jelvo.jelvo`,
  libellé « Jelvo »), mais seule la cible **web** a été compilée et vérifiée ici :
  le SDK Android et la chaîne iOS ne sont pas disponibles dans l'environnement de
  développement utilisé.
