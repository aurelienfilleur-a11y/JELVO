import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jelvo/core/core.dart';
import 'package:jelvo/data/clock.dart';
import 'package:jelvo/data/data_providers.dart';
import 'package:jelvo/features/auth/models/auth_failure.dart';
import 'package:jelvo/features/auth/providers/auth_providers.dart';
import 'package:jelvo/features/auth/repository/auth_repository.dart';
import 'package:jelvo/features/contacts/providers/contact_providers.dart';
import 'package:jelvo/features/calendar/providers/calendar_providers.dart';
import 'package:jelvo/features/groups/providers/group_providers.dart';
import 'package:jelvo/features/tasks/providers/task_providers.dart';
import 'package:jelvo/features/profile/providers/profile_providers.dart';
import 'package:jelvo/main.dart';

import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_contact_repository.dart';
import 'fakes/fake_event_repository.dart';
import 'fakes/fake_group_repository.dart';
import 'fakes/fake_task_repository.dart';

final DateTime _testNow = DateTime(2026, 8, 3, 9);

Future<FakeAuthRepository> _pumpApp(
  WidgetTester tester, {
  required bool signedIn,
  Set<String> pseudosTaken = const <String>{},
  SignUpOutcome signUpOutcome = SignUpOutcome.codeSent,
}) async {
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
        clockProvider.overrideWithValue(FixedClock(_testNow)),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        groupRepositoryProvider.overrideWithValue(FakeGroupRepository()),
        taskRepositoryProvider.overrideWithValue(FakeTaskRepository()),
        eventRepositoryProvider.overrideWithValue(FakeEventRepository()),
        contactRepositoryProvider.overrideWithValue(FakeContactRepository()),
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
