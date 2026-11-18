import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/core.dart';
import 'l10n/app_localizations.dart';
import 'data/app_config.dart';
import 'data/data_providers.dart';
import 'data/onboarding_storage.dart';
import 'data/theme_storage.dart';
import 'data/session_persistence.dart';
import 'data/diagnostic_mode.dart';
import 'features/notifications/providers/push_providers.dart';
import 'router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Avant tout le reste : une erreur survenue pendant l'initialisation doit
  // déjà pouvoir être lue en clair.
  DiagnosticMode.lireDepuisUrl();

  // Charge les symboles de date français avant le premier rendu : sans cela,
  // `DateFormat(..., 'fr_FR')` lève une exception au premier appel.
  await initializeDateFormatting(AppDates.locale);

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

  runApp(
    ProviderScope(
      // `Override` n'est pas exporté par Riverpod 3 : inférence, comme dans
      // les tests.
      overrides: [
        sessionPersistenceProvider.overrideWithValue(persistance),
        onboardingStorageProvider.overrideWithValue(accueil),
        themeStorageProvider.overrideWithValue(apparence),
      ],
      child: const JelvoApp(),
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

    return MaterialApp.router(
      onGenerateTitle: (BuildContext context) => AppTexts.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Clair, sombre, ou celui du téléphone. Le réglage vit sur l'appareil
      // — voir `ThemeStorage` — et il est déjà chargé quand on arrive ici.
      themeMode: ref.watch(themeModeProvider),
      // Une seule langue pour l'instant. Les délégués de Material et de
      // Cupertino sont néanmoins nécessaires : sans eux, les sélecteurs de
      // date et d'heure restent en anglais — quand ils ne lèvent pas.
      localizationsDelegates: AppTexts.localizationsDelegates,
      supportedLocales: AppTexts.supportedLocales,
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
