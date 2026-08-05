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
`contacts`, `tasks` (sans écran propre, exposée dans `home` et `groups`),
`create`.

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
- Le bouton central **[+]** n'est pas un onglet : il empile `/creer` sur le
  navigateur racine (`parentNavigatorKey: _rootNavigatorKey`), ce qui recouvre
  la barre de navigation.
- La barre est un widget maison (`AppBottomNav`) et non un `NavigationBar` :
  le bouton central ne rentre pas dans le modèle « un index par destination ».
- Naviguer avec `context.goNamed(AppRoutes.calendar)` / `pushNamed`, jamais avec
  une chaîne littérale. Les chemins vivent dans `router/app_routes.dart`.
- Sur le web, une URL inconnue affiche `_RouteErrorScreen`. Le workflow copie
  `index.html` en `404.html` pour que l'accès direct à `/calendrier` fonctionne
  sur GitHub Pages.

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
  affiche `error.toString()` est un bug.
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
  personnelle. Les jeux `demo…` restent dans un registre **familial et amical**
  — famille, amis, colocation, voyage, sport. Le registre professionnel
  (réunion, sprint, point hebdo, syndic, copropriété) est **hors périmètre
  produit** et ne doit pas réapparaître, pas plus dans les libellés que dans les
  énumérations : c'est la raison pour laquelle `ContactRelation` propose `Coloc`
  et non `Travail`.

---

## Tests

- `test/widget_test.dart` couvre le parcours principal : accueil, navigation
  entre les quatre onglets, ouverture de `/creer`, validation du formulaire et
  filtrage des contacts.
- `test/auth_flow_test.dart` couvre la garde de navigation, les erreurs de
  connexion, la disponibilité du pseudo et la déconnexion.
- `test/credentials_rules_test.dart` couvre les règles de validation, sans
  widget.

Trois points à respecter dans tout nouveau test de widget :

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

---

## État actuel et limites connues

- **Authentification et profil** sont branchés sur Supabase et persistés. Tout
  le reste — groupes, événements, tâches, contacts — est **en mémoire** et
  regénéré à chaque démarrage.
- Deux prérequis côté projet Supabase, non vérifiables depuis le code :
  exécuter `supabase/email_pour_pseudo.sql` pour la connexion par pseudo, et
  faire émettre `{{ .Token }}` au modèle d'e-mail de confirmation pour le code
  à 6 chiffres.
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
