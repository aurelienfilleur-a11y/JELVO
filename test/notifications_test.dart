import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jelvo/core/core.dart';
import 'package:jelvo/data/clock.dart';
import 'package:jelvo/data/data_providers.dart';
import 'package:jelvo/features/auth/providers/auth_providers.dart';
import 'package:jelvo/features/availability/providers/availability_providers.dart';
import 'package:jelvo/features/contacts/providers/contact_providers.dart';
import 'package:jelvo/features/calendar/providers/calendar_providers.dart';
import 'package:jelvo/features/chat/providers/chat_providers.dart';
import 'package:jelvo/features/groups/providers/group_providers.dart';
import 'package:jelvo/features/tasks/providers/task_providers.dart';
import 'package:jelvo/features/notifications/models/app_notification.dart';
import 'package:jelvo/features/notifications/providers/notification_providers.dart';
import 'package:jelvo/features/profile/providers/profile_providers.dart';
import 'package:jelvo/main.dart';

import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_availability_repository.dart';
import 'fakes/fake_chat_repository.dart';
import 'fakes/fake_contact_repository.dart';
import 'fakes/fake_event_repository.dart';
import 'fakes/fake_group_repository.dart';
import 'fakes/fake_task_repository.dart';
import 'fakes/fake_notification_repository.dart';

final DateTime _testNow = DateTime(2026, 8, 3, 9);

Future<FakeNotificationRepository> _pumpApp(
  WidgetTester tester, {
  List<AppNotification>? notifications,
}) async {
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final FakeAuthRepository auth = FakeAuthRepository(signedIn: true);
  addTearDown(auth.dispose);
  final FakeNotificationRepository repository = FakeNotificationRepository(
    notifications: notifications,
  );

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
        // Aucun message non lu : ces tests mesurent les pastilles de la
        // boîte de notifications, pas celles de la messagerie.
        chatRepositoryProvider.overrideWithValue(
          FakeChatRepository(unread: const <String, int>{}),
        ),
        availabilityRepositoryProvider.overrideWithValue(
          FakeAvailabilityRepository(),
        ),
        notificationRepositoryProvider.overrideWithValue(repository),
      ],
      child: const JelvoApp(),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  setUpAll(() => initializeDateFormatting(AppDates.locale));

  testWidgets('la cloche porte le nombre total de non-lus', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    // Deux non lues sur trois : la troisième porte déjà une date de lecture.
    expect(find.byTooltip('Notifications'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
  });

  testWidgets('les pastilles se répartissent par onglet', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    // Une invitation de groupe et une demande de contact restent à traiter :
    // chaque onglet porte donc « 1 », et le total de la cloche vaut « 2 ».
    final Iterable<NavBadge> badges = tester
        .widgetList<NavBadge>(find.byType(NavBadge))
        .where((NavBadge b) => b.count > 0);
    expect(badges.map((NavBadge b) => b.count).toList(), <int>[2, 1, 1]);
  });

  testWidgets('aucune pastille quand tout est lu', (WidgetTester tester) async {
    await _pumpApp(tester, notifications: <AppNotification>[]);

    final Iterable<NavBadge> visibles = tester
        .widgetList<NavBadge>(find.byType(NavBadge))
        .where((NavBadge b) => b.count > 0);
    expect(visibles, isEmpty);
  });

  testWidgets('l’écran liste les notifications', (WidgetTester tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();

    expect(
      find.text('Invitation à rejoindre Vacances en Corse'),
      findsOneWidget,
    );
    expect(find.text('Demande de contact'), findsNWidgets(2));
    expect(
      find.textContaining('Noah Delacroix souhaite vous ajouter'),
      findsOneWidget,
    );
  });

  testWidgets('un carnet vide affiche un état soigné', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, notifications: <AppNotification>[]);

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();

    expect(find.text('Aucune notification'), findsOneWidget);
    expect(find.textContaining('Les invitations à un groupe'), findsOneWidget);
    // Rien à marquer comme lu : l'action n'a pas lieu d'être.
    expect(find.text('Tout marquer comme lu'), findsNothing);
  });

  testWidgets('ouvrir une notification la marque comme lue', (
    WidgetTester tester,
  ) async {
    final FakeNotificationRepository repository = await _pumpApp(tester);

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Invitation à rejoindre Vacances en Corse'));
    await tester.pumpAndSettle();

    expect(repository.lastReadId, 'n1');
  });

  testWidgets('« tout marquer comme lu » éteint les pastilles', (
    WidgetTester tester,
  ) async {
    final FakeNotificationRepository repository = await _pumpApp(tester);

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tout marquer comme lu'));
    await tester.pumpAndSettle();

    expect(repository.markAllReadCount, 1);
    expect(find.text('Tout marquer comme lu'), findsNothing);

    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();

    final Iterable<NavBadge> visibles = tester
        .widgetList<NavBadge>(find.byType(NavBadge))
        .where((NavBadge b) => b.count > 0);
    expect(visibles, isEmpty);
  });

  testWidgets('répondre à un événement depuis la notification relit la boîte', (
    WidgetTester tester,
  ) async {
    final FakeNotificationRepository repository = await _pumpApp(
      tester,
      notifications: <AppNotification>[
        AppNotification(
          id: 'n9',
          type: NotificationType.eventInvitation,
          payload: const <String, dynamic>{
            'event_id': 'e1',
            'titre': 'Brunch chez les parents',
            'group_name': 'Famille Rousseau',
            'auteur': 'Léa Marchand',
          },
          createdAt: DateTime(2026, 8, 3, 8),
        ),
      ],
    );

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();

    // Les trois réponses sont dans la ligne : c'est là qu'on apprend
    // l'invitation, et le détour par le détail était un détour de trop.
    expect(find.text('Brunch chez les parents'), findsOneWidget);
    expect(find.text('Peut-être'), findsOneWidget);

    final int avant = repository.fetchCount;
    await tester.tap(find.text('Peut-être'));
    await tester.pumpAndSettle();

    // Répondre referme la notification côté base ; sans relecture, la ligne
    // resterait à l'écran et la pastille allumée.
    expect(repository.fetchCount, greaterThan(avant));
  });

  testWidgets('la boîte est relue à chaque ouverture', (
    WidgetTester tester,
  ) async {
    final FakeNotificationRepository repository = await _pumpApp(tester);
    final int avant = repository.fetchCount;

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();

    expect(repository.fetchCount, greaterThan(avant));
  });
}
