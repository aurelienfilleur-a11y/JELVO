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

Le remède ne se code pas : il faut ajouter **`github-actions` à la liste de
contournement** de la règle — Settings → Rules → règle de `main` → *Bypass
list*. Tant que ce n'est pas fait, le job échoue à chaque migration ayant
changé le schéma.

Ce qui se code, en revanche, c'est de ne pas mentir sur le coupable. L'étape
distingue désormais ce refus, l'annonce en toutes lettres — « les migrations
SONT appliquées » —, et l'instantané part en **pièce jointe du job** pour ne
pas être perdu. Le premier diagnostic avait conclu à une migration ratée et
au SQL absent de la base ; il était faux, et il l'était parce que l'échec
brut ne nommait que la dernière commande.

**Règle** : lire le journal jusqu'à la ligne `OK <fichier>` avant de conclure
qu'une migration n'est pas passée. Le rouge du job ne désigne pas l'étape qui
compte.

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

Features existantes : `auth`, `profile`, `home`, `groups`, `calendar`,
`contacts`, `notifications`, `tasks`, `availability`, `chat`, `create`.

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
à faire » de l'écran de groupe portent leur propre action « Ajouter », et leurs
états vides une action pleine. Une fonctionnalité qui n'est atteignable que par
un bouton d'icône dans une barre est, en pratique, intestable.

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
  `/connexion` ;
- session présente → un chemin public renvoie vers `/`.

`AuthRefreshNotifier` est un `ChangeNotifier` alimenté par un `ref.listen` :
GoRouter ne sait pas observer un provider, il faut ce pont. Le statut est un
`Notifier` et non un `StreamProvider` parce qu'une redirection ne peut pas
attendre un `AsyncValue`.

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

Prépare l'adhésion temporaire — un membre invité le temps d'un voyage. `null`
signifie « sans terme ». **Toute lecture de `group_members` filtre les adhésions
échues**, en SQL comme côté client (`_activeMembership` dans le dépôt). Une
adhésion échue laisse sa ligne : les fonctions d'adhésion la suppriment avant de
réinsérer, la clé primaire étant le couple groupe / utilisateur.

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
| `mes_contacts` | carnet + profil d'en face + favori du bon côté |
| `chercher_profils_par_pseudo` | recherche par début de pseudo |
| `apercu_groupe_par_jeton` | aperçu public d'un lien |
| `rejoindre_groupe_par_jeton` | valide le jeton et insère le membre |
| `quitter_groupe` | départ, promotion, suppression — en une transaction |
| `mes_invitations`, `inviter_dans_groupe`, `accepter_invitation`, `refuser_invitation` | invitations nominatives |
| `creer_groupe` | groupe + adhésion admin en une transaction (voir ci-dessus) |

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
| `messages` | `id`, `group_id`, `sender_id`, `content`, `media_url`, `media_kind`, `created_at`, `deleted_at` | `CHECK (content is not null or media_url is not null)`, contenu ≤ 2000 |
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

Les six déclencheurs empilent dans `push_outbox` ; la fonction Edge la vide.
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

### La semaine sur l'accueil

`WeekOverview`, posé **sous le bandeau violet**, montre les sept jours de la
semaine en cours : initiale, quantième, jour courant plein, et deux marqueurs
par jour — violet pour les événements, vert pour les tâches. Toucher un jour
règle `selectedDayProvider` puis ouvre le calendrier à cette date.

Les marqueurs sont des pastilles et non des chiffres : à cette taille, un « 3 »
et un « 8 » ne se distinguent pas d'un coup d'œil, alors qu'une pastille
présente ou absente, si. Le compte exact est à une touche. Il est en revanche
porté par l'étiquette `Semantics`, qu'une pastille ne dit pas à un lecteur
d'écran.

La hauteur des marqueurs est **réservée en permanence** : sans cela, les
colonnes chargées et les colonnes vides n'auraient pas la même hauteur et la
ligne des quantièmes danserait.

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

Les trois derniers ne sont pas du confort : sans eux, une invitation acceptée
laisserait sa pastille allumée indéfiniment. **Un compteur doit refléter ce qui
reste à faire, pas ce qui est arrivé un jour.**

**Une notification est un effet de bord, elle ne doit jamais faire échouer
l'écriture principale.** Les cinq déclencheurs attrapent donc toute erreur, la
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
`group_invitation` → Groupes, `contact_request` → Contacts, le reste → Accueil.
Un élément n'est donc jamais compté deux fois, et le total de la cloche reste
exactement la somme des pastilles. Ajouter un type impose de lui choisir un
onglet — c'est voulu.

`unreadByTabProvider` renvoie les quatre compteurs dans l'ordre de
`AppBottomNav.destinations`. C'est `navBadgesProvider` qui y ajoute les
conversations non lues de la messagerie et que lit `AppShell` — voir « Deux
compteurs qui répondent à deux questions ». `NavBadge` ne peint rien quand le
compteur vaut zéro.

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
- `test/auth_flow_test.dart` couvre la garde de navigation, les erreurs de
  connexion, la disponibilité du pseudo et la déconnexion.
- `test/credentials_rules_test.dart` couvre les règles de validation, sans
  widget.
- `test/session_persistence_test.dart` couvre « Se souvenir de moi » sans
  widget : le défaut coché, l'écriture ou non de la session, l'effacement au
  décochage, la survie du *choix* alors que la session ne survit pas, et la
  déconnexion qui efface quel que soit le réglage.
- `test/groups_contacts_test.dart` couvre la liste et le détail d'un groupe, la
  création, le départ, les cinq états d'un lien d'invitation, les demandes de
  contact, l'encodage du QR code, et le « + » contextuel : depuis l'écran d'un
  groupe il n'offre plus d'en créer un, sa feuille ouvre `/creer` déjà réglée
  sur ce groupe, et les deux sections portent leur propre action « Ajouter ».
- `test/notifications_test.dart` couvre la cloche, la répartition des pastilles
  par onglet, leur extinction, la liste et le marquage comme lu.
- `test/tasks_events_test.dart` couvre les écrans de détail, l'assignation et
  l'administration des groupes.
- `test/availability_weekday_test.dart` couvre la conversion ISO ↔
  `extract(dow)`, sans widget : les six jours identiques, le dimanche qui ne
  l'est pas, la réversibilité, et la relecture d'une ligne de la base.
- `test/availability_calendar_test.dart` couvre la semaine d'accueil (sept
  jours, marqueurs, ouverture du calendrier à la date touchée), les quatre
  compteurs, l'agrégation d'un événement, d'une tâche et d'un créneau sur la
  même journée, le filtre par groupe — qui ne masque pas les créneaux —, et
  l'écran de disponibilités ouvert depuis le profil.

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
  et d'extension, sans widget.

- `test/push_notifications_test.dart` couvre les réglages de notification :
  l'activation qui enregistre l'abonnement en base, le refus et sa marche à
  suivre, la désactivation des deux côtés, la consigne d'installation iOS sans
  bouton, les six types désactivables, l'interrupteur qui revient si l'écriture
  échoue, et le réenregistrement au démarrage.

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
  3. ajouter **`github-actions` à la liste de contournement** de la règle de
     protection de `main`, sans quoi `schema_actuel.sql` ne peut plus y être
     publié.

  Les migrations, elles, s'appliquent seules à chaque push sur `main`.
- **Une migration n'est éprouvée contre la vraie base qu'après fusion.** Le
  workflow qui l'applique ne peut pas tourner sur une pull request — le dépôt
  est public et le secret y serait exposé. Avant fusion, il reste
  `supabase/verification/rejouer.sh`, sur schéma factice : il compile *et*
  appelle les fonctions, mais son décor est recopié de cette documentation, et
  ne dit donc rien des colonnes réelles. C'est `supabase/schema_actuel.sql`,
  relevé après coup, qui fait foi.
- Le test de fumée couvre les tranches 3, 3b, 4, 5a, 5b, 5c et 5d — plus de
  trente fonctions réellement appelées, contrôles négatifs de l'accès au
  bucket et de la mémoire des rappels compris. Les fonctions des tranches 2 et
  antérieures ne sont éprouvées que par l'usage en production.
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
- L'adhésion temporaire n'a pas d'interface : la colonne
  `group_members.expires_at` existe et **toute lecture filtre déjà les adhésions
  échues**, mais rien ne permet encore de fixer un terme depuis l'application.
- L'écran `/creer` enregistre désormais pour de bon : événement ou tâche, avec
  choix du groupe — ou « Personnel » — et de la date. Le choix « Groupe »
  redirige vers l'écran de création dédié. Ouvert depuis un groupe, il arrive
  pré-rempli par l'URL (`?type=…&groupe=…`).
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
  `ThemeMode.light`.
- `google_fonts` télécharge Inter au premier lancement. Pour un fonctionnement
  hors ligne garanti, il faudra embarquer la police dans `assets/`.
- Les dossiers `android/` et `ios/` sont générés et configurés (`com.jelvo.jelvo`,
  libellé « Jelvo »), mais seule la cible **web** a été compilée et vérifiée ici :
  le SDK Android et la chaîne iOS ne sont pas disponibles dans l'environnement de
  développement utilisé.
