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
import 'package:jelvo/features/notifications/push/push_service.dart';
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

Future<({FakePushService service, FakePushRepository depot})> _pumpApp(
  WidgetTester tester, {
  PushStatus statut = PushStatus.aAutoriser,
  bool autorisationAccordee = true,
  FakePushRepository? depot,
}) async {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final FakeAuthRepository auth = FakeAuthRepository(signedIn: true);
  addTearDown(auth.dispose);
  final FakePushService service = FakePushService(
    statut: statut,
    autorisationAccordee: autorisationAccordee,
  );
  final FakePushRepository push = depot ?? FakePushRepository();

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
        chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
        availabilityRepositoryProvider.overrideWithValue(
          FakeAvailabilityRepository(),
        ),
        notificationRepositoryProvider.overrideWithValue(
          FakeNotificationRepository(),
        ),
        pushServiceProvider.overrideWithValue(service),
        pushRepositoryProvider.overrideWithValue(push),
      ],
      child: const JelvoApp(),
    ),
  );
  await tester.pumpAndSettle();
  return (service: service, depot: push);
}

/// Accueil → Profil → Paramètres.
Future<void> _ouvrirParametres(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Profil'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Paramètres'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting(AppDates.locale));

  group('Autorisation', () {
    testWidgets('un bouton propose d’activer, et l’abonnement part en base', (
      WidgetTester tester,
    ) async {
      final ({FakePushRepository depot, FakePushService service}) faux =
          await _pumpApp(tester);
      await _ouvrirParametres(tester);

      expect(find.text('Notifications désactivées'), findsOneWidget);

      await tester.tap(find.text('Activer les notifications'));
      await tester.pumpAndSettle();

      expect(faux.service.abonnements, 1);
      expect(
        faux.depot.lastRegisteredEndpoint,
        FakePushService.abonnementDemo.endpoint,
      );
      expect(find.text('Notifications actives'), findsOneWidget);
    });

    testWidgets('un refus est annoncé, avec la marche à suivre', (
      WidgetTester tester,
    ) async {
      // L'API ne permet plus de redemander après un refus : dire seulement
      // « refusé » laisserait dans une impasse.
      await _pumpApp(tester, autorisationAccordee: false);
      await _ouvrirParametres(tester);

      await tester.tap(find.text('Activer les notifications'));
      await tester.pumpAndSettle();

      expect(find.text('Notifications refusées'), findsOneWidget);
      expect(find.textContaining('réglages de votre navigateur'), findsWidgets);
    });

    testWidgets('désactiver retire l’abonnement des deux côtés', (
      WidgetTester tester,
    ) async {
      final ({FakePushRepository depot, FakePushService service}) faux =
          await _pumpApp(tester, statut: PushStatus.actif);
      await _ouvrirParametres(tester);

      await tester.tap(find.text('Désactiver sur cet appareil'));
      await tester.pumpAndSettle();

      expect(faux.service.desabonnements, 1);
      expect(
        faux.depot.lastForgottenEndpoint,
        FakePushService.abonnementDemo.endpoint,
      );
    });
  });

  group('iOS : l’installation est un préalable', () {
    testWidgets('la marche à suivre est écrite, pas un bouton', (
      WidgetTester tester,
    ) async {
      // iOS n'expose pas `beforeinstallprompt` : proposer l'installation
      // depuis la page est **impossible**, la consigne est tout ce qui reste.
      await _pumpApp(tester, statut: PushStatus.installationRequise);
      await _ouvrirParametres(tester);

      expect(find.text('Installez Jelvo pour les recevoir'), findsOneWidget);
      expect(find.textContaining('Sur l’écran d’accueil'), findsOneWidget);
      expect(
        find.textContaining('son propre stockage, distinct de Safari'),
        findsOneWidget,
      );
      // Aucun bouton d'activation : il n'aurait rien à activer.
      expect(find.text('Activer les notifications'), findsNothing);
    });

    testWidgets('une plateforme sans Web Push le dit simplement', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester, statut: PushStatus.nonSupporte);
      await _ouvrirParametres(tester);

      expect(find.text('Notifications indisponibles ici'), findsOneWidget);
      expect(find.text('Activer les notifications'), findsNothing);
    });
  });

  group('Les six types', () {
    testWidgets('chacun est désactivable', (WidgetTester tester) async {
      final ({FakePushRepository depot, FakePushService service}) faux =
          await _pumpApp(tester);
      await _ouvrirParametres(tester);

      for (final String libelle in const <String>[
        'Nouveaux messages',
        'Invitations',
        'Tâches assignées',
        'Rappels',
        'Réponses aux événements',
        'Changements de date',
      ]) {
        expect(find.text(libelle), findsOneWidget);
      }

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(SwitchListTile, 'Nouveaux messages'),
          matching: find.byType(Switch),
        ),
      );
      await tester.pumpAndSettle();

      expect(faux.depot.lastToggledType, 'chat_message');
      expect(faux.depot.lastToggledValue, isFalse);
    });

    testWidgets('un échec d’écriture remet l’interrupteur', (
      WidgetTester tester,
    ) async {
      // L'interrupteur bouge avant l'aller-retour, sans quoi il paraît inerte.
      // La contrepartie est qu'il doit revenir si l'écriture échoue, sinon
      // l'écran affirme un réglage que la base n'a pas.
      await _pumpApp(tester, depot: FailingPushRepository());
      await _ouvrirParametres(tester);

      final Finder interrupteur = find.descendant(
        of: find.widgetWithText(SwitchListTile, 'Rappels'),
        matching: find.byType(Switch),
      );
      expect(tester.widget<Switch>(interrupteur).value, isTrue);

      await tester.tap(interrupteur);
      await tester.pumpAndSettle();

      expect(
        tester.widget<Switch>(interrupteur).value,
        isTrue,
        reason: 'l’interrupteur doit revenir si la base n’a pas suivi',
      );
      // L'échec est dit, et en français : aucun message technique brut ne doit
      // atteindre l'écran.
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('Réenregistrement au démarrage', () {
    testWidgets('un abonnement existant est reposé sans geste', (
      WidgetTester tester,
    ) async {
      // Un abonnement peut être révoqué sans que personne n'en informe la
      // base : on le repose à chaque ouverture de session.
      final ({FakePushRepository depot, FakePushService service}) faux =
          await _pumpApp(tester, statut: PushStatus.actif);

      expect(faux.depot.registrations, greaterThanOrEqualTo(1));
      expect(
        faux.depot.lastRegisteredEndpoint,
        FakePushService.abonnementDemo.endpoint,
      );
    });

    testWidgets('sans abonnement, rien n’est écrit', (
      WidgetTester tester,
    ) async {
      final ({FakePushRepository depot, FakePushService service}) faux =
          await _pumpApp(tester);

      expect(faux.depot.registrations, 0);
      expect(faux.depot.lastRegisteredEndpoint, isNull);
    });
  });
}
