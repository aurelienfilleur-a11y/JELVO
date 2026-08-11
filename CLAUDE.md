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

### Fusion automatique des pull requests

Les pull requests de l'assistant activent l'**auto-merge natif de GitHub** :
elles se fusionnent seules dès que « Compiler la version web » passe au vert,
sans intervention.

Deux façons de garder la main :

| Signal | Effet |
| --- | --- |
| étiquette **`arbitrage-requis`** sur la PR | l'auto-merge n'est pas activé, la PR attend |
| PR ouverte en **brouillon** | GitHub n'auto-fusionne jamais un brouillon |

L'étiquette est posée dès l'ouverture, jamais après coup : une PR déjà
auto-fusionnée ne se rattrape pas. Sont concernées les livraisons dont le
choix, et non l'exécution, mérite un avis — un arbitrage de produit, une
migration destructrice, un changement de dépendance.

L'auto-merge natif est préféré à un workflow maison pour une raison précise :
une fusion faite par `GITHUB_TOKEN` **ne déclenche aucun workflow en aval**.
Le déploiement des pages et l'application des migrations ne partiraient pas.

Il exige que « Allow auto-merge » soit coché dans les réglages du dépôt.

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
`contacts`, `notifications`, `tasks`, `availability`, `create`.

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

`weekday` est un entier que le schéma initial ne documente pas. L'application
retient la **convention ISO — 1 = lundi … 7 = dimanche**, la même que
`DateTime.weekday`. Le seul endroit à changer si la base attendait
`extract(dow)`, où dimanche vaut 0, est `AvailabilitySlot.weekday`.

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
`AppBottomNav.destinations` ; `AppShell` les lui passe. `NavBadge` ne peint rien
quand le compteur vaut zéro.

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
- `test/groups_contacts_test.dart` couvre la liste et le détail d'un groupe, la
  création, le départ, les cinq états d'un lien d'invitation, les demandes de
  contact, l'encodage du QR code, et le « + » contextuel : depuis l'écran d'un
  groupe il n'offre plus d'en créer un, sa feuille ouvre `/creer` déjà réglée
  sur ce groupe, et les deux sections portent leur propre action « Ajouter ».
- `test/notifications_test.dart` couvre la cloche, la répartition des pastilles
  par onglet, leur extinction, la liste et le marquage comme lu.
- `test/tasks_events_test.dart` couvre les écrans de détail, l'assignation et
  l'administration des groupes.
- `test/availability_calendar_test.dart` couvre la semaine d'accueil (sept
  jours, marqueurs, ouverture du calendrier à la date touchée), les quatre
  compteurs, l'agrégation d'un événement, d'une tâche et d'un créneau sur la
  même journée, le filtre par groupe — qui ne masque pas les créneaux —, et
  l'écran de disponibilités ouvert depuis le profil.

Huit faux dépôts vivent dans `test/fakes/` : authentification, profil, groupes,
contacts, notifications, tâches, agenda et disponibilités. **Tous les fichiers
de test les surchargent tous** — un provider oublié tombe sur
`Supabase.instance`, absent en test.

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
   `eventRepositoryProvider` et `availabilityRepositoryProvider`, avec les faux
   dépôts de `test/fakes/`. L'accueil et le calendrier les lisent tous les six.

Le `+` central de la barre et le bouton « Nouveau groupe » portent la même
icône : viser un bouton d'en-tête par `find.byTooltip`, pas par `find.byIcon`.
L'infobulle du `+` change avec l'écran, ce qui en fait aussi le moyen le plus
sûr d'éprouver son caractère contextuel.

---

## État actuel et limites connues

- **Tout le domaine est branché sur Supabase** : authentification, profil,
  groupes, contacts, invitations, notifications, tâches, événements et
  disponibilités. Il n'y a plus aucun jeu de données de démonstration dans
  `lib/` — les seuls restants vivent dans `test/fakes/`.
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
- **Un seul prérequis manuel subsiste côté projet Supabase** : faire émettre
  `{{ .Token }}` au modèle d'e-mail de confirmation, pour le code à 6 chiffres.
  Les migrations, elles, s'appliquent seules à chaque push sur `main`.
- **Une migration n'est éprouvée contre la vraie base qu'après fusion.** Le
  workflow qui l'applique ne peut pas tourner sur une pull request — le dépôt
  est public et le secret y serait exposé. Avant fusion, il reste
  `supabase/verification/rejouer.sh`, sur schéma factice : il compile *et*
  appelle les fonctions, mais son décor est recopié de cette documentation, et
  ne dit donc rien des colonnes réelles. C'est `supabase/schema_actuel.sql`,
  relevé après coup, qui fait foi.
- Le test de fumée couvre les tranches 3, 3b et 4 — vingt-quatre fonctions
  réellement appelées. Les fonctions des tranches 2 et antérieures ne sont
  éprouvées que par l'usage en production.
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
- Le rappel est enregistré, mais **rien ne l'envoie encore** : `reminder_at` et
  `reminder_minutes` sont stockés, la notification système n'est pas au
  périmètre.
- Le mode sombre n'est pas au périmètre : `themeMode` est figé sur
  `ThemeMode.light`.
- `google_fonts` télécharge Inter au premier lancement. Pour un fonctionnement
  hors ligne garanti, il faudra embarquer la police dans `assets/`.
- Les dossiers `android/` et `ios/` sont générés et configurés (`com.jelvo.jelvo`,
  libellé « Jelvo »), mais seule la cible **web** a été compilée et vérifiée ici :
  le SDK Android et la chaîne iOS ne sont pas disponibles dans l'environnement de
  développement utilisé.
