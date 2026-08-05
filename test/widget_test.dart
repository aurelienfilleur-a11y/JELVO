import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jelvo/core/core.dart';
import 'package:jelvo/data/clock.dart';
import 'package:jelvo/data/data_providers.dart';
import 'package:jelvo/features/auth/providers/auth_providers.dart';
import 'package:jelvo/features/profile/providers/profile_providers.dart';
import 'package:jelvo/main.dart';

import 'fakes/fake_auth_repository.dart';

/// Date figée : les libellés « Aujourd'hui » / « Demain » et le jeu de données
/// de démonstration sont tous calculés à partir de l'horloge.
final DateTime _testNow = DateTime(2026, 8, 3, 9);

/// Lance l'application avec des dépôts simulés.
///
/// L'authentification et le profil sont surchargés : sans cela, les providers
/// iraient chercher `Supabase.instance`, qui n'est pas initialisé en test.
Future<FakeAuthRepository> _pumpApp(
  WidgetTester tester, {
  bool signedIn = true,
}) async {
  // La surface de test par défaut (800 × 600) place la moitié des écrans sous
  // la ligne de flottaison ; on prend un viewport haut pour que les listes
  // soient entièrement construites.
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final FakeAuthRepository auth = FakeAuthRepository(signedIn: signedIn);
  addTearDown(auth.dispose);

  await tester.pumpWidget(
    ProviderScope(
      // `Override` n'est pas exporté par Riverpod 3 : on laisse l'inférence.
      overrides: [
        clockProvider.overrideWithValue(FixedClock(_testNow)),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
      ],
      child: const JelvoApp(),
    ),
  );
  await tester.pumpAndSettle();
  return auth;
}

void main() {
  setUpAll(() => initializeDateFormatting(AppDates.locale));

  testWidgets('l’accueil affiche le résumé et l’agenda du jour', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    expect(find.textContaining('Bonjour'), findsOneWidget);
    expect(find.text('Brunch chez les parents'), findsOneWidget);
    // « Aujourd'hui » titre la section agenda et sert aussi de pastille
    // d'échéance sur les tâches du jour.
    expect(find.text("Aujourd'hui"), findsWidgets);
    expect(find.text('Réserver le restaurant pour samedi'), findsOneWidget);
  });

  testWidgets('la barre inférieure navigue vers chaque onglet', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Groupes'));
    await tester.pumpAndSettle();
    expect(find.text('Famille Rousseau'), findsOneWidget);

    await tester.tap(find.text('Calendrier'));
    await tester.pumpAndSettle();
    expect(find.text('Août 2026'), findsWidgets);

    await tester.tap(find.text('Contacts'));
    await tester.pumpAndSettle();
    expect(find.text('Camille Rousseau'), findsOneWidget);
  });

  testWidgets('le bouton « + » ouvre l’écran de création', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Que voulez-vous créer ?'), findsOneWidget);
    expect(find.text('Événement'), findsOneWidget);
  });

  testWidgets('créer sans titre affiche une erreur de validation', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Créer l’événement'));
    await tester.pump();

    expect(find.text('Ce champ est obligatoire.'), findsOneWidget);
  });

  testWidgets('la recherche filtre la liste des contacts', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Contacts'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'yanis');
    await tester.pumpAndSettle();

    expect(find.text('Yanis Bertrand'), findsOneWidget);
    expect(find.text('Camille Rousseau'), findsNothing);
  });
}
