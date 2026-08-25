import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jelvo/core/core.dart';
import 'package:jelvo/data/clock.dart';
import 'package:jelvo/data/data_providers.dart';
import 'package:jelvo/features/auth/providers/auth_providers.dart';
import 'package:jelvo/features/availability/providers/availability_providers.dart';
import 'package:jelvo/features/calendar/providers/calendar_providers.dart';
import 'package:jelvo/features/chat/providers/chat_providers.dart';
import 'package:jelvo/features/contacts/providers/contact_providers.dart';
import 'package:jelvo/features/groups/providers/group_providers.dart';
import 'package:jelvo/features/notifications/providers/notification_providers.dart';
import 'package:jelvo/features/notifications/providers/push_providers.dart';
import 'package:jelvo/features/profile/models/profile.dart';
import 'package:jelvo/features/profile/providers/profile_providers.dart';
import 'package:jelvo/features/tasks/models/task.dart';
import 'package:jelvo/features/tasks/providers/task_providers.dart';
import 'package:jelvo/main.dart';

import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_availability_repository.dart';
import 'fakes/fake_chat_repository.dart';
import 'fakes/fake_contact_repository.dart';
import 'fakes/fake_event_repository.dart';
import 'fakes/fake_group_repository.dart';
import 'fakes/fake_notification_repository.dart';
import 'fakes/fake_push.dart';
import 'fakes/fake_task_repository.dart';

final DateTime _testNow = DateTime(2026, 8, 3, 9);

Future<FakeProfileRepository> _ouvrirProfil(
  WidgetTester tester, {
  Profile? profile,
  FakeTaskRepository? taskRepository,
}) async {
  tester.view.physicalSize = const Size(420, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final FakeAuthRepository auth = FakeAuthRepository(signedIn: true);
  addTearDown(auth.dispose);
  final FakeProfileRepository profils = FakeProfileRepository(profile: profile);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(FixedClock(_testNow)),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(profils),
        groupRepositoryProvider.overrideWithValue(FakeGroupRepository()),
        taskRepositoryProvider.overrideWithValue(
          taskRepository ?? FakeTaskRepository(),
        ),
        eventRepositoryProvider.overrideWithValue(FakeEventRepository()),
        contactRepositoryProvider.overrideWithValue(FakeContactRepository()),
        chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
        availabilityRepositoryProvider.overrideWithValue(
          FakeAvailabilityRepository(),
        ),
        notificationRepositoryProvider.overrideWithValue(
          FakeNotificationRepository(),
        ),
        pushServiceProvider.overrideWithValue(FakePushService()),
        pushRepositoryProvider.overrideWithValue(FakePushRepository()),
      ],
      child: const JelvoApp(),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byTooltip('Profil'));
  await tester.pumpAndSettle();
  return profils;
}

void main() {
  setUpAll(() => initializeDateFormatting(AppDates.locale));

  group('Carte d’identité', () {
    testWidgets('le nom, le pseudo et les trois actions sont là', (
      WidgetTester tester,
    ) async {
      await _ouvrirProfil(tester);

      expect(find.text('Mon profil'), findsOneWidget);
      expect(find.text('Camille Rousseau'), findsOneWidget);
      expect(find.text('@camille.rousseau'), findsWidgets);

      expect(find.text('QR Code'), findsOneWidget);
      expect(find.text('Modifier'), findsOneWidget);
      expect(find.text('Partager profil'), findsOneWidget);
    });

    testWidgets('« QR Code » ouvre le code à faire scanner', (
      WidgetTester tester,
    ) async {
      await _ouvrirProfil(tester);

      await tester.tap(find.text('QR Code'));
      await tester.pumpAndSettle();

      expect(find.text('Mon QR code'), findsWidgets);
      // Le code ne porte que le pseudo : ni adresse, ni agenda.
      expect(find.textContaining('ne contient'), findsOneWidget);
    });

    testWidgets('« Modifier » ouvre le formulaire pré-rempli', (
      WidgetTester tester,
    ) async {
      await _ouvrirProfil(tester);

      await tester.tap(find.text('Modifier'));
      await tester.pumpAndSettle();

      expect(find.text('Modifier le profil'), findsOneWidget);
      expect(find.text('Camille'), findsOneWidget);
      expect(find.text('Rousseau'), findsOneWidget);
      expect(find.text('Enregistrer'), findsOneWidget);
    });

    testWidgets('modifier enregistre et referme sur le profil', (
      WidgetTester tester,
    ) async {
      final FakeProfileRepository profils = await _ouvrirProfil(tester);

      await tester.tap(find.text('Modifier'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Camille-Anne');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      final Profile? apres = await profils.fetchProfile('utilisateur-test');
      expect(apres!.firstName, 'Camille-Anne');
      // On revient au profil : rester sur le formulaire laisserait douter de
      // l'effet de l'enregistrement.
      expect(find.text('Mon profil'), findsOneWidget);
    });

    testWidgets('la pastille ouvre le choix photo ou avatar Jelvo', (
      WidgetTester tester,
    ) async {
      await _ouvrirProfil(tester);

      await tester.tap(find.byTooltip('Changer de photo'));
      await tester.pumpAndSettle();

      expect(find.text('Choisir une photo'), findsOneWidget);
      expect(find.text('Choisir un avatar Jelvo'), findsOneWidget);
      // Rien à retirer tant qu'il n'y a ni photo ni avatar.
      expect(find.text('Retirer'), findsNothing);
    });

    testWidgets('avec un avatar, la feuille propose de le retirer', (
      WidgetTester tester,
    ) async {
      await _ouvrirProfil(
        tester,
        profile: const Profile(
          id: 'utilisateur-test',
          pseudo: 'camille.rousseau',
          firstName: 'Camille',
          lastName: 'Rousseau',
          avatarPreset: 'p3_05',
        ),
      );

      await tester.tap(find.byTooltip('Changer de photo'));
      await tester.pumpAndSettle();

      expect(find.text('Retirer'), findsOneWidget);
    });
  });

  group('Carte « À propos »', () {
    testWidgets('la bio et l’e-mail s’y lisent', (WidgetTester tester) async {
      await _ouvrirProfil(tester);

      expect(find.text('À propos'), findsOneWidget);
      expect(find.text('Bio'), findsOneWidget);
      expect(find.text('Toujours partante pour une rando.'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
    });

    testWidgets('ni téléphone ni localisation', (WidgetTester tester) async {
      await _ouvrirProfil(tester);

      // Jelvo ne collecte pas ces informations : les afficher vides aurait
      // suggéré qu'il manque quelque chose à remplir.
      expect(find.text('Téléphone'), findsNothing);
      expect(find.text('Localisation'), findsNothing);
      // Pas davantage de badge de présence : `last_seen_at` n'est écrit nulle
      // part, et une pastille verte permanente serait un mensonge.
      expect(find.text('En ligne'), findsNothing);
    });

    testWidgets('sans bio, la ligne invite à la remplir', (
      WidgetTester tester,
    ) async {
      await _ouvrirProfil(
        tester,
        profile: const Profile(
          id: 'utilisateur-test',
          pseudo: 'camille.rousseau',
          firstName: 'Camille',
          lastName: 'Rousseau',
        ),
      );

      expect(find.text('Bio'), findsOneWidget);
      expect(find.text('Ajoutez quelques mots sur vous'), findsOneWidget);
    });

    testWidgets('la ligne Bio ouvre la modification', (
      WidgetTester tester,
    ) async {
      await _ouvrirProfil(tester);

      await tester.tap(find.text('Bio'));
      await tester.pumpAndSettle();

      expect(find.text('Modifier le profil'), findsOneWidget);
    });
  });

  group('Carte « Mes statistiques »', () {
    testWidgets('les trois compteurs viennent des listes chargées', (
      WidgetTester tester,
    ) async {
      await _ouvrirProfil(tester);

      expect(find.text('Mes statistiques'), findsOneWidget);
      expect(find.text('Groupes'), findsOneWidget);
      expect(find.text('Événements'), findsOneWidget);
      // « Terminées » et non « réalisées » : `tasks` ne porte pas de
      // `completed_by`, et attribuer l'action serait une invention.
      expect(find.text('Tâches terminées'), findsOneWidget);

      // Deux groupes de démonstration.
      expect(
        find.descendant(
          of: find
              .ancestor(of: find.text('Groupes'), matching: find.byType(Column))
              .first,
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('sans tâche terminée, le compteur affiche zéro', (
      WidgetTester tester,
    ) async {
      await _ouvrirProfil(
        tester,
        taskRepository: FakeTaskRepository(tasks: <Task>[]),
      );

      expect(find.text('Tâches terminées'), findsOneWidget);
      expect(find.text('0'), findsWidgets);
    });

    testWidgets('un compteur ouvre la liste qu’il résume', (
      WidgetTester tester,
    ) async {
      await _ouvrirProfil(tester);

      await tester.tap(find.text('Groupes'));
      await tester.pumpAndSettle();

      expect(find.text('Famille Rousseau'), findsWidgets);
    });
  });

  group('Disponibilités', () {
    testWidgets('la ligne reste atteignable depuis le profil', (
      WidgetTester tester,
    ) async {
      // Absente de la maquette, gardée : c'est le seul chemin vers cet écran.
      await _ouvrirProfil(tester);

      expect(find.text('Mes disponibilités'), findsOneWidget);
    });
  });
}
