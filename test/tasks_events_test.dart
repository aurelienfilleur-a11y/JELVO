import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jelvo/core/core.dart';
import 'package:jelvo/data/clock.dart';
import 'package:jelvo/data/data_providers.dart';
import 'package:jelvo/features/auth/providers/auth_providers.dart';
import 'package:jelvo/features/availability/providers/availability_providers.dart';
import 'package:jelvo/features/calendar/models/calendar_event.dart';
import 'package:jelvo/features/calendar/models/recurrence.dart';
import 'package:jelvo/features/calendar/providers/calendar_providers.dart';
import 'package:jelvo/features/chat/providers/chat_providers.dart';
import 'package:jelvo/features/contacts/providers/contact_providers.dart';
import 'package:jelvo/features/groups/providers/group_providers.dart';
import 'package:jelvo/features/notifications/providers/notification_providers.dart';
import 'package:jelvo/features/notifications/providers/push_providers.dart';
import 'package:jelvo/features/profile/providers/profile_providers.dart';
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

Future<({FakeTaskRepository taches, FakeEventRepository agenda})> _pumpApp(
  WidgetTester tester,
) async {
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final FakeAuthRepository auth = FakeAuthRepository(signedIn: true);
  addTearDown(auth.dispose);
  final FakeTaskRepository taches = FakeTaskRepository();
  final FakeEventRepository agenda = FakeEventRepository();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(FixedClock(_testNow)),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        groupRepositoryProvider.overrideWithValue(FakeGroupRepository()),
        taskRepositoryProvider.overrideWithValue(taches),
        eventRepositoryProvider.overrideWithValue(agenda),
        contactRepositoryProvider.overrideWithValue(FakeContactRepository()),
        chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
        pushServiceProvider.overrideWithValue(FakePushService()),
        pushRepositoryProvider.overrideWithValue(FakePushRepository()),
        availabilityRepositoryProvider.overrideWithValue(
          FakeAvailabilityRepository(),
        ),
        notificationRepositoryProvider.overrideWithValue(
          FakeNotificationRepository(),
        ),
      ],
      child: const JelvoApp(),
    ),
  );
  await tester.pumpAndSettle();
  return (taches: taches, agenda: agenda);
}

void main() {
  setUpAll(() => initializeDateFormatting(AppDates.locale));

  group('Détail d’une tâche', () {
    testWidgets('taper sur la ligne ouvre le détail', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);

      await tester.tap(find.text('Réserver le restaurant pour samedi'));
      await tester.pumpAndSettle();

      expect(find.text('Tâche'), findsOneWidget);
      expect(find.text('Échéance'), findsOneWidget);
      expect(find.text('Priorité'), findsOneWidget);
      expect(find.text('Haute'), findsOneWidget);
      expect(find.text('Assignée à'), findsOneWidget);
      expect(find.text('Marquer comme terminée'), findsOneWidget);
    });

    testWidgets('la case à cocher propose Terminée ou Supprimer', (
      WidgetTester tester,
    ) async {
      final ({FakeEventRepository agenda, FakeTaskRepository taches}) faux =
          await _pumpApp(tester);

      // La case porte une étiquette d'accessibilité : c'est la façon la plus
      // sûre de la viser, la ligne entière étant elle aussi tactile.
      await tester.tap(
        find.bySemanticsLabel('Marquer la tâche comme terminée').first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Terminée'), findsOneWidget);
      expect(find.text('Supprimer'), findsOneWidget);

      await tester.tap(find.text('Terminée'));
      await tester.pumpAndSettle();

      expect(faux.taches.lastToggledDone, isTrue);
      // Terminer ne supprime pas : les deux gestes restent distincts.
      expect(faux.taches.lastDeletedId, isNull);
    });

    testWidgets('modifier une tâche ouvre la feuille pré-remplie', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);

      await tester.tap(find.text('Réserver le restaurant pour samedi'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Modifier la tâche'));
      await tester.pumpAndSettle();

      expect(find.text('Modifier la tâche'), findsWidgets);
      expect(find.text('Enregistrer les modifications'), findsOneWidget);
      // Le rappel et la répétition sont désormais réglables.
      expect(find.text('Rappel'), findsOneWidget);
      expect(find.text('Répéter'), findsOneWidget);
    });

    testWidgets('supprimer demande confirmation avant d’agir', (
      WidgetTester tester,
    ) async {
      final ({FakeEventRepository agenda, FakeTaskRepository taches}) faux =
          await _pumpApp(tester);

      await tester.tap(find.text('Réserver le restaurant pour samedi'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Supprimer la tâche'));
      await tester.pumpAndSettle();

      expect(faux.taches.lastDeletedId, isNull);

      await tester.tap(find.text('Supprimer').last);
      await tester.pumpAndSettle();

      expect(faux.taches.lastDeletedId, 't1');
    });
  });

  group('Détail d’un événement', () {
    testWidgets('taper sur un événement l’ouvre avec ses réponses', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);

      await tester.tap(find.text('Brunch chez les parents'));
      await tester.pumpAndSettle();

      expect(find.text('Événement'), findsOneWidget);
      expect(find.text('Votre réponse'), findsOneWidget);
      expect(find.text('Oui'), findsWidgets);
      expect(find.text('Peut-être'), findsWidgets);
      expect(find.text('Non'), findsWidgets);
      expect(find.text('Participants'), findsOneWidget);
    });

    testWidgets('répondre enregistre la réponse', (WidgetTester tester) async {
      final ({FakeEventRepository agenda, FakeTaskRepository taches}) faux =
          await _pumpApp(tester);

      await tester.tap(find.text('Brunch chez les parents'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Peut-être').last);
      await tester.pumpAndSettle();

      expect(faux.agenda.lastRespondedId, 'e1');
      expect(faux.agenda.lastResponse, EventResponse.maybe);
    });
  });

  group('Cartes de l’accueil', () {
    testWidgets('la carte des tâches ouvre la liste des tâches', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);

      await tester.tap(find.text('Voir toutes mes tâches'));
      await tester.pumpAndSettle();

      expect(find.text('Tâches'), findsWidgets);
    });

    testWidgets('la bande des groupes ouvre la liste des groupes', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);

      await tester.tap(find.text('Voir tout'));
      await tester.pumpAndSettle();

      expect(find.text('Famille Rousseau'), findsWidgets);
    });
  });

  group('Récurrence et rappel', () {
    test('une rrule connue se relit, une inconnue ne casse rien', () {
      expect(Recurrence.fromRrule('FREQ=WEEKLY'), Recurrence.hebdomadaire);
      expect(Recurrence.fromRrule('freq=monthly'), Recurrence.mensuelle);
      expect(Recurrence.fromRrule(null), Recurrence.aucune);
      // Une règle écrite ailleurs, non reconnue : on retombe sur « Jamais »
      // plutôt que de lever.
      expect(Recurrence.fromRrule('FREQ=DAILY;BYSETPOS=2'), Recurrence.aucune);
    });

    test('le rappel se convertit dans les deux sens', () {
      final DateTime echeance = DateTime(2026, 8, 10, 18);

      expect(
        ReminderOffset.uneHeure.instantAvant(echeance),
        DateTime(2026, 8, 10, 17),
      );
      expect(
        ReminderOffset.fromInstants(DateTime(2026, 8, 10, 17), echeance),
        ReminderOffset.uneHeure,
      );
      // Sans échéance, il n'y a rien à quoi accrocher un rappel.
      expect(ReminderOffset.laVeille.instantAvant(null), isNull);
      expect(ReminderOffset.aucun.instantAvant(echeance), isNull);
    });

    test('une seconde d’écart ne fait pas retomber sur « Aucun »', () {
      // Un aller-retour par la base peut décaler les secondes.
      expect(
        ReminderOffset.fromInstants(
          DateTime(2026, 8, 10, 17, 0, 30),
          DateTime(2026, 8, 10, 18),
        ),
        ReminderOffset.uneHeure,
      );
    });
  });
}
