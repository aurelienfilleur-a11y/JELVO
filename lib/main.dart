import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/core.dart';
import 'data/app_config.dart';
import 'data/data_providers.dart';
import 'data/language_storage.dart';
import 'data/onboarding_storage.dart';
import 'data/theme_storage.dart';
import 'demarrage.dart';
import 'data/session_persistence.dart';
import 'data/diagnostic_mode.dart';
import 'features/notifications/providers/push_providers.dart';
import 'router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Avant tout le reste : une erreur survenue pendant l'initialisation doit
  // déjà pouvoir être lue en clair.
  DiagnosticMode.lireDepuisUrl();

  // Charge les symboles de date **des quatre langues** avant le premier
  // rendu : sans cela, `DateFormat(..., 'de')` lève au premier appel. Sans
  // argument, `initializeDateFormatting` les charge toutes — une cinquième
  // langue ne demanderait donc rien ici.
  await initializeDateFormatting();

  // `Supabase.initialize` restaure la session persistée : l'utilisateur reste
  // connecté d'un lancement à l'autre — sauf s'il a décoché « Se souvenir de
  // moi », auquel cas `SessionPersistence` n'a rien écrit à retrouver.
  final SessionPersistence persistance = SessionPersistence();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
    authOptions: FlutterAuthClientOptions(localStorage: persistance),
  );

  // La redirection lit ce drapeau de façon synchrone dès le premier `build` :
  // il doit être chargé avant `runApp`, comme la session.
  //
  // Une session déjà ouverte vaut présentation faite, mais cette règle-là vit
  // dans `welcomeSeenProvider` : deux endroits qui décident de la même chose
  // finiraient par diverger.
  final OnboardingStorage accueil = OnboardingStorage();
  await accueil.initialize();

  // L'apparence est lue avant `runApp` pour la même raison : sans cela,
  // l'application s'ouvrirait en clair puis basculerait en sombre à la
  // première image. Le clignotement ne se rattrape pas après coup — il faut
  // connaître le réglage avant le premier rendu.
  final ThemeStorage apparence = ThemeStorage();
  await apparence.initialize();

  // La langue, pour la même raison exactement : s'ouvrir en français pour
  // basculer en espagnol à la première image serait le même clignotement.
  final LanguageStorage langue = LanguageStorage();
  await langue.initialize();

  runApp(
    ProviderScope(
      // `Override` n'est pas exporté par Riverpod 3 : inférence, comme dans
      // les tests.
      overrides: [
        sessionPersistenceProvider.overrideWithValue(persistance),
        onboardingStorageProvider.overrideWithValue(accueil),
        themeStorageProvider.overrideWithValue(apparence),
        languageStorageProvider.overrideWithValue(langue),
      ],
      // L'enfant est **constant** : le signal de démarrage observe les
      // lectures du premier écran, et n'a donc pas à faire reconstruire
      // l'application chaque fois que l'une d'elles se termine.
      child: const SignalDeDemarrage(child: JelvoApp()),
    ),
  );
}

class JelvoApp extends ConsumerWidget {
  const JelvoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(routerProvider);

    // Repose l'abonnement aux notifications à chaque ouverture de session : un
    // abonnement révoqué ne prévient personne.
    ref.watch(pushRegistrationProvider);

    // Sur le web, le fond de la page et la couleur du bandeau de la barre
    // d'état sont posés par `web/index.html` **avant** que Flutter démarre :
    // c'est ce qui évite le flash blanc, et aucun code Dart ne peut arriver
    // assez tôt pour le faire. Ils sont donc déjà justes en arrivant ici.
    //
    // Ce qui reste à dire au navigateur, c'est qu'on vient de **changer** de
    // réglage. `ref.listen` et non `ref.watch` : c'est un effet de bord sur la
    // page, pas une valeur dont dépend cet arbre de widgets.
    ref.listen<ThemeMode>(themeModeProvider, (ThemeMode? _, ThemeMode mode) {
      ref
          .read(pontNavigateurProvider)
          .appliquerApparence(ThemeStorage.jeton(mode));
    });

    return MaterialApp.router(
      onGenerateTitle: (BuildContext context) => AppTexts.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Clair, sombre, ou celui du téléphone. Le réglage vit sur l'appareil
      // — voir `ThemeStorage` — et il est déjà chargé quand on arrive ici.
      themeMode: ref.watch(themeModeProvider),
      // Les délégués de Material et de Cupertino ne sont pas décoratifs :
      // sans eux, les sélecteurs de date et d'heure restent en anglais quand
      // ils ne lèvent pas.
      localizationsDelegates: AppTexts.localizationsDelegates,
      supportedLocales: LanguageStorage.languesPrisesEnCharge,
      // `null` veut dire « celle du téléphone », et c'est le défaut. La
      // résolution passe alors par le rappel ci-dessous.
      locale: ref.watch(localeProvider),
      // **Flutter retomberait sur `supportedLocales.first`**, c'est-à-dire sur
      // le français : un téléphone en japonais obtiendrait donc du français.
      // La consigne est l'anglais, et c'est `LanguageStorage.resoudre` qui la
      // porte — au même endroit que la liste des quatre langues, pour qu'une
      // cinquième n'ait qu'un fichier à toucher.
      //
      // Ce rappel suit aussi le téléphone **à chaud** : Flutter le rappelle à
      // chaque `didChangeLocales`, là où lire la langue une fois dans `main()`
      // l'aurait figée jusqu'au prochain lancement.
      localeListResolutionCallback:
          (List<Locale>? preferees, Iterable<Locale> _) =>
              LanguageStorage.resoudre(preferees),
      routerConfig: router,
      builder: (BuildContext context, Widget? child) {
        // Neutralise la mise à l'échelle extrême du texte : au-delà de 1,3 la
        // barre de navigation et les cartes cassent leur mise en page.
        final MediaQueryData data = MediaQuery.of(context);
        final Widget contenu = MediaQuery(
          data: data.copyWith(
            textScaler: data.textScaler.clamp(
              minScaleFactor: 1,
              maxScaleFactor: 1.3,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );

        // Un mode diagnostic silencieux resterait allumé sans qu'on le sache,
        // et les messages techniques passeraient pour l'affichage normal. Le
        // bandeau dit qu'on n'est pas dans l'état nominal.
        if (!DiagnosticMode.isActive) return contenu;
        return Banner(
          message: 'DIAGNOSTIC',
          location: BannerLocation.topStart,
          color: context.couleurs.danger,
          child: contenu,
        );
      },
    );
  }
}
