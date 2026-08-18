import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jelvo/core/core.dart';
import 'package:jelvo/data/clock.dart';
import 'package:jelvo/data/data_providers.dart';
import 'package:jelvo/data/session_persistence.dart';
import 'package:jelvo/features/auth/models/auth_failure.dart';
import 'package:jelvo/features/auth/providers/auth_providers.dart';
import 'package:jelvo/features/availability/providers/availability_providers.dart';
import 'package:jelvo/features/auth/repository/auth_repository.dart';
import 'package:jelvo/features/contacts/providers/contact_providers.dart';
import 'package:jelvo/features/calendar/providers/calendar_providers.dart';
import 'package:jelvo/features/chat/providers/chat_providers.dart';
import 'package:jelvo/features/groups/providers/group_providers.dart';
import 'package:jelvo/features/tasks/providers/task_providers.dart';
import 'package:jelvo/features/profile/providers/profile_providers.dart';
import 'package:jelvo/main.dart';

import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_availability_repository.dart';
import 'fakes/fake_chat_repository.dart';
import 'fakes/fake_contact_repository.dart';
import 'fakes/fake_event_repository.dart';
import 'fakes/fake_group_repository.dart';
import 'fakes/fake_task_repository.dart';

final DateTime _testNow = DateTime(2026, 8, 3, 9);

/// Réglage observé par les tests de « Se souvenir de moi ». Il n'écrit nulle
/// part : ses deux stockages sont éphémères.
late SessionPersistence _persistance;

Future<FakeAuthRepository> _pumpApp(
  WidgetTester tester, {
  required bool signedIn,
  Set<String> pseudosTaken = const <String>{},
  SignUpOutcome signUpOutcome = SignUpOutcome.codeSent,
}) async {
  _persistance = SessionPersistence(
    session: const EphemeralSessionStorage(),
    drapeau: const EphemeralSessionStorage(),
  );
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final FakeAuthRepository auth = FakeAuthRepository(
    signedIn: signedIn,
    pseudosTaken: pseudosTaken,
    signUpOutcome: signUpOutcome,
  );
  addTearDown(auth.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionPersistenceProvider.overrideWithValue(_persistance),
        // Les tests tournent sur la VM : sans cela, la consigne réservée au
        // web ne serait jamais éprouvée.
        estSurLeWebProvider.overrideWithValue(true),
        clockProvider.overrideWithValue(FixedClock(_testNow)),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        groupRepositoryProvider.overrideWithValue(FakeGroupRepository()),
        taskRepositoryProvider.overrideWithValue(FakeTaskRepository()),
        eventRepositoryProvider.overrideWithValue(FakeEventRepository()),
        contactRepositoryProvider.overrideWithValue(FakeContactRepository()),
        chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
        availabilityRepositoryProvider.overrideWithValue(
          FakeAvailabilityRepository(),
        ),
      ],
      child: const JelvoApp(),
    ),
  );
  await tester.pumpAndSettle();
  return auth;
}

void main() {
  setUpAll(() => initializeDateFormatting(AppDates.locale));

  testWidgets('sans session, la garde redirige vers la connexion', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, signedIn: false);

    expect(find.text('Content de vous revoir'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    // La barre de navigation ne doit pas apparaître avant la connexion.
    expect(find.text('Groupes'), findsNothing);
  });

  testWidgets('avec session, la garde laisse accéder à l’accueil', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, signedIn: true);

    expect(find.text('Content de vous revoir'), findsNothing);
    expect(find.text('Brunch chez les parents'), findsOneWidget);
  });

  testWidgets('un champ vide est signalé en français', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, signedIn: false);

    await tester.tap(find.text('Se connecter'));
    await tester.pump();

    expect(
      find.text('Renseignez votre pseudo ou votre adresse e-mail.'),
      findsOneWidget,
    );
    expect(find.text('Renseignez votre mot de passe.'), findsOneWidget);
  });

  group('Se souvenir de moi', () {
    testWidgets('la case est cochée par défaut', (WidgetTester tester) async {
      await _pumpApp(tester, signedIn: false);

      final Checkbox case_ = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(case_.value, isTrue);
      expect(find.text('Se souvenir de moi'), findsOneWidget);
      expect(
        find.text('Vous resterez connecté jusqu’à la déconnexion.'),
        findsOneWidget,
      );
    });

    testWidgets('décocher annonce la déconnexion à la fermeture', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester, signedIn: false);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect(
        find.text('Vous serez déconnecté à la fermeture de l’application.'),
        findsOneWidget,
      );
    });

    testWidgets('la session installée est annoncée comme distincte', (
      WidgetTester tester,
    ) async {
      // Sans cette précision, quelqu'un qui coche dans Safari puis ouvre
      // l'application de l'écran d'accueil conclut que la case ne marche pas.
      await _pumpApp(tester, signedIn: false);

      expect(find.textContaining('a sa propre session'), findsOneWidget);
      expect(find.textContaining('distincte de Safari'), findsOneWidget);
    });

    testWidgets('le réglage est posé avant la connexion', (
      WidgetTester tester,
    ) async {
      // L'ordre compte : gotrue écrit la session dans la foulée de `signIn`.
      // Régler après persisterait la session que l'on vient de refuser.
      await _pumpApp(tester, signedIn: false);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'camille.rousseau');
      await tester.enterText(find.byType(TextField).at(1), 'Motdepasse1');
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();

      expect(_persistance.seSouvenir, isFalse);
    });
  });

  testWidgets('des identifiants incorrects affichent un message en français', (
    WidgetTester tester,
  ) async {
    final FakeAuthRepository auth = await _pumpApp(tester, signedIn: false);
    auth.signInFailure = const AuthFailure(
      'Identifiants incorrects. Vérifiez votre saisie, puis réessayez.',
      kind: AuthFailureKind.invalidCredentials,
    );

    await tester.enterText(find.byType(TextField).first, 'camille.rousseau');
    await tester.enterText(find.byType(TextField).at(1), 'MauvaisMotDePasse1');
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Identifiants incorrects. Vérifiez votre saisie, puis réessayez.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('une connexion réussie mène à l’accueil', (
    WidgetTester tester,
  ) async {
    final FakeAuthRepository auth = await _pumpApp(tester, signedIn: false);

    await tester.enterText(find.byType(TextField).first, 'camille.rousseau');
    await tester.enterText(find.byType(TextField).at(1), 'Motdepasse1');
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();

    expect(auth.lastSignInIdentifier, 'camille.rousseau');
    expect(find.text('Brunch chez les parents'), findsOneWidget);
  });

  testWidgets('l’inscription signale un pseudo déjà pris', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      signedIn: false,
      pseudosTaken: <String>{'camille.rousseau'},
    );

    await tester.tap(find.text("S'inscrire"));
    await tester.pumpAndSettle();
    expect(find.text('Créer votre compte'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'camille.rousseau');
    // Laisse passer le débounce de la vérification de disponibilité.
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('Ce pseudo est déjà pris.'), findsOneWidget);
  });

  testWidgets('l’inscription accepte un pseudo libre', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, signedIn: false);

    await tester.tap(find.text("S'inscrire"));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'nouveau.pseudo');
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('Ce pseudo est disponible.'), findsOneWidget);
  });

  testWidgets('sans confirmation d’e-mail, l’inscription mène à l’accueil', (
    WidgetTester tester,
  ) async {
    final FakeAuthRepository auth = await _pumpApp(
      tester,
      signedIn: false,
      signUpOutcome: SignUpOutcome.sessionOpened,
    );

    await tester.tap(find.text("S'inscrire"));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'nouveau.pseudo');
    await tester.enterText(find.byType(TextField).at(1), 'nouveau@example.com');
    await tester.enterText(find.byType(TextField).at(2), 'Motdepasse1');
    await tester.pumpAndSettle(const Duration(seconds: 1));

    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Camille');
    await tester.enterText(find.byType(TextField).at(1), 'Rousseau');
    await tester.tap(find.text('Créer mon compte'));
    await tester.pumpAndSettle();

    // L'écran de saisie du code reste en place mais n'est pas traversé.
    expect(find.text('Vérifiez votre e-mail'), findsNothing);
    expect(auth.completeSignUpCalled, isTrue);
    expect(find.text('Brunch chez les parents'), findsOneWidget);
  });

  testWidgets('avec confirmation d’e-mail, le code reste demandé', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, signedIn: false);

    await tester.tap(find.text("S'inscrire"));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'nouveau.pseudo');
    await tester.enterText(find.byType(TextField).at(1), 'nouveau@example.com');
    await tester.enterText(find.byType(TextField).at(2), 'Motdepasse1');
    await tester.pumpAndSettle(const Duration(seconds: 1));

    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Camille');
    await tester.enterText(find.byType(TextField).at(1), 'Rousseau');
    await tester.tap(find.text('Créer mon compte'));
    await tester.pumpAndSettle();

    expect(find.text('Vérifiez votre e-mail'), findsOneWidget);
  });

  testWidgets('la déconnexion ramène à l’écran de connexion', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, signedIn: true);

    await tester.tap(find.byIcon(Icons.person_outline_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('Camille Rousseau'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Se déconnecter').last);
    await tester.pumpAndSettle();
    // Confirme dans la boîte de dialogue.
    await tester.tap(find.text('Se déconnecter').last);
    await tester.pumpAndSettle();

    expect(find.text('Content de vous revoir'), findsOneWidget);
  });
}
