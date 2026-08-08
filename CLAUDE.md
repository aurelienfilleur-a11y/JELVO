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
```

La CI (`.github/workflows/deploy-web.yml`) exécute `dart format
--set-exit-if-changed`, `flutter analyze`, `flutter test` puis `flutter build
web`. Ces quatre commandes doivent passer avant tout push sur `main`.

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
`contacts`, `notifications`, `tasks` (sans écran propre, exposée dans `home` et
`groups`), `create`.

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
  la barre de navigation. Il est **contextuel** — `AppShell._createAction` :
  Accueil et Groupes créent un groupe, Calendrier ouvre `/creer`, Contacts mène
  à l'ajout de contact. L'écran ouvert dit déjà ce que l'on veut créer ; le
  demander serait une question de trop. Son infobulle nomme l'action, l'icône
  seule ne disant pas ce qui va s'ouvrir.
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
  affiche `error.toString()` est un bug. Seule exception, temporaire et
  explicite : `--dart-define=JELVO_DIAGNOSTIC=true` accole l'erreur brute —
  SQLSTATE, message, détail, indice — sous le message français, et la consigne
  dans la console. `AuthFailure.technical` est toujours renseigné ; seul son
  affichage dépend du drapeau. À remettre à `false` dès le diagnostic fini.
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

### Migrations à exécuter

**`supabase/tranche2_groupes_et_invitations.sql`**,
**`supabase/correctif_creation_groupe.sql`**,
**`supabase/notifications.sql`**,
**`supabase/correctif_notifications.sql`**, puis
**`supabase/correctif_invitations_type.sql`**, dans cet ordre, dans l'éditeur
SQL du projet. Idempotentes.

`supabase/diagnostic_invitation.sql` n'est pas une migration : il rejoue un
appel dans une transaction annulée, pour faire remonter une erreur serveur. Elle apporte les favoris personnels, `expires_at`,
la table `group_invite_links` avec ses politiques, et les fonctions ci-dessous.

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
  contact et l'encodage du QR code.
- `test/notifications_test.dart` couvre la cloche, la répartition des pastilles
  par onglet, leur extinction, la liste et le marquage comme lu.

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
4. Surcharger les groupes, les contacts et les notifications, pour la même
   raison : `groupRepositoryProvider`, `contactRepositoryProvider` et
   `notificationRepositoryProvider`, avec les faux dépôts de `test/fakes/`.

Le `+` central de la barre et le bouton « Nouveau groupe » portent la même
icône : viser un bouton d'en-tête par `find.byTooltip`, pas par `find.byIcon`.

---

## État actuel et limites connues

- **Authentification, profil, groupes, contacts, invitations et notifications**
  sont branchés sur Supabase et persistés. **Événements, tâches et calendrier**
  restent **en mémoire** et regénérés à chaque démarrage.
- Les notifications sont **relues à la demande**, pas poussées : la liste se
  rafraîchit à l'ouverture de l'écran, au geste de traction et après chaque
  action. Le temps réel et les notifications système (`push_tokens`) ne sont pas
  au périmètre.
- Conséquence du point précédent : les tâches et événements de démonstration
  citent les groupes `g1`…`g4`, qui n'existent plus côté Supabase.
  `groupByIdProvider` renvoie donc `null` pour eux — pas de pastille de groupe
  sur ces cartes, plutôt qu'un plantage. Le recâblage viendra avec leur passage
  sur Supabase.
- Six prérequis côté projet Supabase, non vérifiables depuis le code :
  exécuter `supabase/email_pour_pseudo.sql` pour la connexion par pseudo,
  `supabase/tranche2_groupes_et_invitations.sql` pour les groupes et les
  invitations, `supabase/correctif_creation_groupe.sql` pour la création de
  groupe, `supabase/notifications.sql` puis
  `supabase/correctif_notifications.sql` pour les notifications,
  `supabase/correctif_invitations_type.sql` pour l'invitation nominative, et
  faire émettre `{{ .Token }}` au modèle d'e-mail de confirmation pour le code
  à 6 chiffres.
- Le scan de QR code demande une caméra : il est désactivé proprement sur le web
  et sur ordinateur, où l'écran renvoie vers la recherche par pseudo. Les cibles
  Android et iOS n'ont pas pu être compilées ici — `mobile_scanner` embarque du
  natif, et ni le SDK Android ni la chaîne iOS ne sont disponibles dans
  l'environnement de développement utilisé.
- L'adhésion temporaire n'a pas d'interface : la colonne
  `group_members.expires_at` existe et **toute lecture filtre déjà les adhésions
  échues**, mais rien ne permet encore de fixer un terme depuis l'application.
- L'écran `/creer` **valide** le titre mais **n'enregistre pas** encore : il
  affiche une `SnackBar`. Le câblage vers les dépôts reste à faire.
- Le partage d'un événement avec un groupe et le choix des participants ne sont
  pas implémentés.
- Le mode sombre n'est pas au périmètre : `themeMode` est figé sur
  `ThemeMode.light`.
- `google_fonts` télécharge Inter au premier lancement. Pour un fonctionnement
  hors ligne garanti, il faudra embarquer la police dans `assets/`.
- Les dossiers `android/` et `ios/` sont générés et configurés (`com.jelvo.jelvo`,
  libellé « Jelvo »), mais seule la cible **web** a été compilée et vérifiée ici :
  le SDK Android et la chaîne iOS ne sont pas disponibles dans l'environnement de
  développement utilisé.
