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
import 'package:jelvo/features/chat/models/message.dart';
import 'package:jelvo/features/chat/providers/chat_providers.dart';
import 'package:jelvo/features/chat/repository/chat_repository.dart';
import 'package:jelvo/features/contacts/providers/contact_providers.dart';
import 'package:jelvo/features/groups/providers/group_providers.dart';
import 'package:jelvo/features/notifications/providers/notification_providers.dart';
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
import 'fakes/fake_task_repository.dart';

final DateTime _testNow = DateTime(2026, 8, 3, 9);

Future<FakeChatRepository> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final FakeAuthRepository auth = FakeAuthRepository(signedIn: true);
  addTearDown(auth.dispose);
  final FakeChatRepository chat = FakeChatRepository();
  addTearDown(chat.dispose);

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
        chatRepositoryProvider.overrideWithValue(chat),
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
  return chat;
}

/// Accueil → onglet Groupes → « Famille Rousseau » → « Discussion ».
Future<void> _ouvrirDiscussion(WidgetTester tester) async {
  await tester.tap(find.text('Groupes'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Famille Rousseau'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Discussion'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting(AppDates.locale));

  group('Entrée depuis le groupe', () {
    testWidgets('la ligne annonce les messages non lus', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);

      await tester.tap(find.text('Groupes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Famille Rousseau'));
      await tester.pumpAndSettle();

      expect(find.text('Discussion'), findsOneWidget);
      expect(find.text('2 messages non lus'), findsOneWidget);
    });

    testWidgets('ouvrir la conversation la marque comme lue', (
      WidgetTester tester,
    ) async {
      final FakeChatRepository chat = await _pumpApp(tester);
      await _ouvrirDiscussion(tester);

      expect(chat.lastReadGroupId, 'g1');
    });
  });

  group('Conversation', () {
    testWidgets('les messages s’affichent, le plus récent en bas', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await _ouvrirDiscussion(tester);

      expect(find.text('Bonjour tout le monde'), findsOneWidget);
      expect(find.text('On se retrouve à midi'), findsOneWidget);
      expect(find.text('J’apporte le dessert'), findsOneWidget);

      // Liste inversée : le plus récent est le plus bas à l'écran.
      final double recent = tester
          .getCenter(find.text('J’apporte le dessert'))
          .dy;
      final double ancien = tester
          .getCenter(find.text('Bonjour tout le monde'))
          .dy;
      expect(recent, greaterThan(ancien));
    });

    testWidgets('envoyer un message appelle le dépôt', (
      WidgetTester tester,
    ) async {
      final FakeChatRepository chat = await _pumpApp(tester);
      await _ouvrirDiscussion(tester);

      await tester.enterText(find.byType(TextField), 'À tout à l’heure');
      await tester.pump();
      await tester.tap(find.byTooltip('Envoyer'));
      await tester.pumpAndSettle();

      expect(chat.lastSentContent, 'À tout à l’heure');
      expect(find.text('À tout à l’heure'), findsOneWidget);
    });

    testWidgets('un message vide ne part pas', (WidgetTester tester) async {
      final FakeChatRepository chat = await _pumpApp(tester);
      await _ouvrirDiscussion(tester);

      // Des espaces seuls ne sont pas un message : `envoyer_message` les
      // refuserait, autant ne pas les envoyer.
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      await tester.tap(find.byTooltip('Envoyer'));
      await tester.pumpAndSettle();

      expect(chat.lastSentContent, isNull);
    });

    testWidgets('un message arrivé en temps réel apparaît sans geste', (
      WidgetTester tester,
    ) async {
      final FakeChatRepository chat = await _pumpApp(tester);
      await _ouvrirDiscussion(tester);

      expect(find.text('Et moi le pain'), findsNothing);

      chat.receive(
        Message(
          id: 'm99',
          groupId: 'g1',
          senderId: 'u2',
          createdAt: DateTime(2026, 8, 3, 8, 45),
          content: 'Et moi le pain',
          senderName: 'Léa Marchand',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Et moi le pain'), findsOneWidget);
    });

    testWidgets('l’indicateur de frappe apparaît puis se tait', (
      WidgetTester tester,
    ) async {
      final FakeChatRepository chat = await _pumpApp(tester);
      await _ouvrirDiscussion(tester);

      chat.emitTyping(
        const TypingSignal(userId: 'u2', name: 'Léa', typing: true),
      );
      await tester.pumpAndSettle();
      expect(find.text('Léa est en train d’écrire…'), findsOneWidget);

      chat.emitTyping(
        const TypingSignal(userId: 'u2', name: 'Léa', typing: false),
      );
      await tester.pumpAndSettle();
      expect(find.text('Léa est en train d’écrire…'), findsNothing);
    });

    testWidgets('écrire annonce la frappe aux autres', (
      WidgetTester tester,
    ) async {
      final FakeChatRepository chat = await _pumpApp(tester);
      await _ouvrirDiscussion(tester);

      await tester.enterText(find.byType(TextField), 'Je');
      await tester.pump();

      expect(chat.lastTyping, isTrue);
    });
  });

  group('Réactions', () {
    testWidgets('poser une réaction, puis la retirer', (
      WidgetTester tester,
    ) async {
      final FakeChatRepository chat = await _pumpApp(tester);
      await _ouvrirDiscussion(tester);

      await tester.longPress(find.text('J’apporte le dessert'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Réagir 🎉'));
      await tester.pumpAndSettle();

      expect(chat.lastReactedId, 'm3');
      expect(chat.lastEmoji, '🎉');
      expect(find.text('🎉'), findsOneWidget);

      // La clé primaire `(message_id, user_id)` n'autorise qu'une réaction par
      // personne : reposer le même emoji le retire.
      await tester.tap(find.text('🎉'));
      await tester.pumpAndSettle();

      expect(find.text('🎉'), findsNothing);
    });
  });

  group('Suppression', () {
    testWidgets('supprimer son message laisse « Message supprimé »', (
      WidgetTester tester,
    ) async {
      final FakeChatRepository chat = await _pumpApp(tester);
      await _ouvrirDiscussion(tester);

      await tester.longPress(find.text('On se retrouve à midi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer le message'));
      await tester.pumpAndSettle();

      expect(chat.lastDeletedId, 'm2');
      expect(find.text('On se retrouve à midi'), findsNothing);
      expect(find.text('Message supprimé'), findsOneWidget);
    });

    testWidgets('le message d’un autre ne propose pas la suppression', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await _ouvrirDiscussion(tester);

      await tester.longPress(find.text('J’apporte le dessert'));
      await tester.pumpAndSettle();

      expect(find.text('Supprimer le message'), findsNothing);
      expect(
        find.text('Vous ne pouvez supprimer que vos messages'),
        findsOneWidget,
      );
    });

    testWidgets('une suppression sans effet est annoncée comme telle', (
      WidgetTester tester,
    ) async {
      // `messages` n'a pas de politique DELETE : une écriture qui ne touche
      // aucune ligne se solde par un 200 côté PostgREST. C'est le booléen de
      // la fonction SQL qui tranche, et l'écran doit le dire.
      final FakeChatRepository chat = await _pumpApp(tester);
      chat.deletionSucceeds = false;
      await _ouvrirDiscussion(tester);

      await tester.longPress(find.text('On se retrouve à midi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer le message'));
      await tester.pumpAndSettle();

      expect(
        find.text('Ce message ne peut plus être supprimé.'),
        findsOneWidget,
      );
      expect(find.text('On se retrouve à midi'), findsOneWidget);
    });
  });
}
