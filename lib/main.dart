import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/core.dart';
import 'l10n/app_localizations.dart';
import 'data/app_config.dart';
import 'data/diagnostic_mode.dart';
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
  // connecté d'un lancement à l'autre.
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: JelvoApp()));
}

class JelvoApp extends ConsumerWidget {
  const JelvoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(routerProvider);

    return MaterialApp.router(
      onGenerateTitle: (BuildContext context) => AppTexts.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // L'application ne propose qu'un thème clair pour l'instant.
      themeMode: ThemeMode.light,
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
          color: AppColors.danger,
          child: contenu,
        );
      },
    );
  }
}
