import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jelvo/core/core.dart';
import 'package:jelvo/data/clock.dart';
import 'package:jelvo/data/app_config.dart';
import 'package:jelvo/data/data_providers.dart';
import 'package:jelvo/features/auth/providers/auth_providers.dart';
import 'package:jelvo/features/availability/providers/availability_providers.dart';
import 'package:jelvo/features/calendar/models/calendar_event.dart';
import 'package:jelvo/features/calendar/providers/calendar_providers.dart';
import 'package:jelvo/features/chat/models/media_selection.dart';
import 'package:jelvo/features/chat/models/message.dart';
import 'package:jelvo/features/chat/models/message_card.dart';
import 'package:jelvo/features/chat/providers/chat_providers.dart';
import 'package:jelvo/features/chat/repository/chat_repository.dart';
import 'package:jelvo/features/chat/widgets/chat_day_divider.dart';
import 'package:jelvo/features/chat/widgets/chat_header.dart';
import 'package:jelvo/features/chat/widgets/chat_media.dart';
import 'package:jelvo/features/chat/widgets/emoji_picker.dart';
import 'package:jelvo/features/chat/widgets/message_bubble.dart';
import 'package:jelvo/features/chat/widgets/message_card_tile.dart';
import 'package:jelvo/features/chat/widgets/voice_message.dart';
import 'package:jelvo/features/contacts/providers/contact_providers.dart';
import 'package:jelvo/features/groups/providers/group_providers.dart';
import 'package:jelvo/features/groups/widgets/group_quick_actions.dart';
import 'package:jelvo/features/notifications/models/app_notification.dart';
import 'package:jelvo/features/notifications/providers/notification_providers.dart';
import 'package:jelvo/features/notifications/providers/push_providers.dart';
import 'package:jelvo/features/profile/providers/profile_providers.dart';
import 'package:jelvo/features/tasks/models/task.dart';
import 'package:jelvo/features/tasks/providers/task_providers.dart';
import 'package:jelvo/main.dart';
import 'package:jelvo/router/app_bottom_nav.dart';

import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_availability_repository.dart';
import 'fakes/fake_chat_repository.dart';
import 'fakes/fake_contact_repository.dart';
import 'fakes/fake_event_repository.dart';
import 'fakes/fake_group_repository.dart';
import 'fakes/fake_notification_repository.dart';
import 'fakes/fake_push.dart';
import 'fakes/fake_task_repository.dart';
import 'fakes/fake_voice.dart';

final DateTime _testNow = DateTime(2026, 8, 3, 9);

Future<FakeChatRepository> _pumpApp(
  WidgetTester tester, {
  Map<String, int>? unread,
  bool avecNotifications = true,
  List<Message>? messages,
  FakeTaskRepository? tasks,
  FakeEventRepository? events,
  FakeVoiceRecorder? recorder,
  FakeVoicePlayer? player,
}) async {
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final FakeAuthRepository auth = FakeAuthRepository(signedIn: true);
  addTearDown(auth.dispose);
  final FakeChatRepository chat = FakeChatRepository(
    unread: unread,
    messages: messages,
  );
  addTearDown(chat.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(FixedClock(_testNow)),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        groupRepositoryProvider.overrideWithValue(FakeGroupRepository()),
        taskRepositoryProvider.overrideWithValue(tasks ?? FakeTaskRepository()),
        eventRepositoryProvider.overrideWithValue(
          events ?? FakeEventRepository(),
        ),
        contactRepositoryProvider.overrideWithValue(FakeContactRepository()),
        chatRepositoryProvider.overrideWithValue(chat),
        // Ni micro ni haut-parleur dans un test de widget : sans ces deux
        // surcharges, `record` et `just_audio` cherchent un canal de
        // plateforme qui n'existe pas.
        voiceRecorderProvider.overrideWithValue(
          recorder ?? FakeVoiceRecorder(),
        ),
        voicePlayerFactoryProvider.overrideWithValue(
          () => player ?? FakeVoicePlayer(),
        ),
        pushServiceProvider.overrideWithValue(FakePushService()),
        pushRepositoryProvider.overrideWithValue(FakePushRepository()),
        availabilityRepositoryProvider.overrideWithValue(
          FakeAvailabilityRepository(),
        ),
        notificationRepositoryProvider.overrideWithValue(
          FakeNotificationRepository(
            notifications: avecNotifications ? null : <AppNotification>[],
          ),
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

/// Pastille de l'onglet Groupes — index 1 de la barre du bas.
///
/// Viser `NavBadge` sans restreindre à la barre attraperait aussi la cloche de
/// l'accueil, qui en est un.
int _pastilleGroupes(WidgetTester tester) {
  final List<NavBadge> badges = tester
      .widgetList<NavBadge>(
        find.descendant(
          of: find.byType(AppBottomNav),
          matching: find.byType(NavBadge),
        ),
      )
      .toList();
  return badges[1].count;
}

void main() {
  setUpAll(() => initializeDateFormatting(AppDates.locale));

  group('Savoir qu’on a reçu un message', () {
    testWidgets('l’onglet Groupes porte une pastille sans y entrer', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester, avecNotifications: false);

      // Depuis l'accueil, sans avoir ouvert quoi que ce soit.
      expect(_pastilleGroupes(tester), 1);
    });

    testWidgets('la pastille compte les conversations, pas les messages', (
      WidgetTester tester,
    ) async {
      // Douze messages non lus, mais dans **une seule** conversation : ce que
      // la pastille annonce, c'est le nombre d'endroits où aller.
      await _pumpApp(
        tester,
        unread: const <String, int>{'g1': 12},
        avecNotifications: false,
      );

      expect(_pastilleGroupes(tester), 1);
    });

    testWidgets('deux conversations actives donnent deux', (
      WidgetTester tester,
    ) async {
      await _pumpApp(
        tester,
        unread: const <String, int>{'g1': 3, 'g2': 1},
        avecNotifications: false,
      );

      expect(_pastilleGroupes(tester), 2);
    });

    testWidgets('un groupe sans rien à lire n’allume rien', (
      WidgetTester tester,
    ) async {
      await _pumpApp(
        tester,
        unread: const <String, int>{'g1': 0},
        avecNotifications: false,
      );

      expect(_pastilleGroupes(tester), 0);
    });

    testWidgets('la carte du groupe dit lequel est actif', (
      WidgetTester tester,
    ) async {
      await _pumpApp(
        tester,
        unread: const <String, int>{'g1': 3},
        avecNotifications: false,
      );

      await tester.tap(find.text('Groupes'));
      await tester.pumpAndSettle();

      // « Famille Rousseau » est g1 ; « Vacances en Corse » n'a rien.
      final GroupCard famille = tester.widget<GroupCard>(
        find.widgetWithText(GroupCard, 'Famille Rousseau'),
      );
      final GroupCard corse = tester.widget<GroupCard>(
        find.widgetWithText(GroupCard, 'Vacances en Corse'),
      );

      expect(famille.unreadCount, 3);
      expect(corse.unreadCount, 0);
      // La carte, elle, a la place d'afficher le compte réel.
      expect(find.text('3'), findsWidgets);
    });

    testWidgets('lire la conversation éteint la pastille', (
      WidgetTester tester,
    ) async {
      await _pumpApp(
        tester,
        unread: const <String, int>{'g1': 4},
        avecNotifications: false,
      );
      expect(_pastilleGroupes(tester), 1);

      await _ouvrirDiscussion(tester);
      await tester.tap(find.byTooltip('Retour').first);
      await tester.pumpAndSettle();

      expect(_pastilleGroupes(tester), 0);
    });
  });

  group('Entrée depuis le groupe', () {
    testWidgets('la ligne annonce les messages non lus', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);

      await tester.tap(find.text('Groupes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Famille Rousseau'));
      await tester.pumpAndSettle();

      // La rangée d'accès rapides remplace la ligne « Discussion » : le
      // compte passe de la phrase à la pastille posée sur le pictogramme.
      expect(find.text('Discussion'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(GroupQuickActions),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
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
      // refuserait, autant ne pas les envoyer. Le bouton de droite reste
      // donc le micro — il n'y a rien à envoyer.
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();

      expect(find.byTooltip('Envoyer'), findsNothing);
      expect(find.byTooltip('Enregistrer un message vocal'), findsOneWidget);
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

  group('Médias', () {
    testWidgets('le « + » ouvre les trois choses qu’on peut ajouter', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await _ouvrirDiscussion(tester);

      await tester.tap(find.byTooltip('Ajouter à la conversation'));
      await tester.pumpAndSettle();

      expect(find.text('Nouvelle tâche'), findsOneWidget);
      expect(find.text('Nouvel événement'), findsOneWidget);
      expect(find.text('Photo ou vidéo'), findsOneWidget);

      // Les listes, les dépenses et les notes n'existent nulle part dans
      // Jelvo : les proposer promettrait ce qui n'arrive pas.
      expect(find.text('Nouvelle liste'), findsNothing);
      expect(find.text('Nouvelle dépense'), findsNothing);
      expect(find.text('Nouvelle note'), findsNothing);
    });

    testWidgets('la feuille propose photo et vidéo, jamais un document', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await _ouvrirDiscussion(tester);

      await tester.tap(find.byTooltip('Ajouter à la conversation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Photo ou vidéo'));
      await tester.pumpAndSettle();

      expect(find.text('Photo de la galerie'), findsOneWidget);
      expect(find.text('Prendre une photo'), findsOneWidget);
      expect(find.text('Vidéo de la galerie'), findsOneWidget);
      expect(find.text('Filmer'), findsOneWidget);
      // `media_type` ne connaît que `image` et `video` : c'est le type qui
      // interdit les documents, et l'écran ne doit pas en promettre.
      expect(find.textContaining('document'), findsNothing);
      expect(find.textContaining('Fichier'), findsNothing);
    });

    testWidgets('un message photo affiche la vignette, pas le chemin brut', (
      WidgetTester tester,
    ) async {
      final FakeChatRepository chat = await _pumpApp(tester);
      chat.receive(
        Message(
          id: 'm50',
          groupId: 'g1',
          senderId: 'u2',
          createdAt: DateTime(2026, 8, 3, 8, 50),
          mediaUrl: 'g1/photo.jpg',
          mediaKind: MediaKind.image,
          senderName: 'Léa Marchand',
        ),
      );
      await _ouvrirDiscussion(tester);

      expect(find.byType(ChatMedia), findsOneWidget);
      // Le chemin de stockage n'a rien à faire à l'écran.
      expect(find.textContaining('g1/photo.jpg'), findsNothing);
    });

    testWidgets('une vidéo s’annonce comme telle', (WidgetTester tester) async {
      final FakeChatRepository chat = await _pumpApp(tester);
      chat.receive(
        Message(
          id: 'm51',
          groupId: 'g1',
          senderId: 'u2',
          createdAt: DateTime(2026, 8, 3, 8, 51),
          mediaUrl: 'g1/film.mp4',
          mediaKind: MediaKind.video,
          senderName: 'Léa Marchand',
        ),
      );
      await _ouvrirDiscussion(tester);
      await tester.pumpAndSettle();

      expect(find.text('Vidéo'), findsOneWidget);
    });

    testWidgets('un média supprimé ne montre plus rien', (
      WidgetTester tester,
    ) async {
      final FakeChatRepository chat = await _pumpApp(tester);
      chat.receive(
        Message(
          id: 'm52',
          groupId: 'g1',
          senderId: FakeChatRepository.moi,
          createdAt: DateTime(2026, 8, 3, 8, 52),
          mediaUrl: 'g1/secret.jpg',
          mediaKind: MediaKind.image,
        ),
      );
      await _ouvrirDiscussion(tester);
      expect(find.byType(ChatMedia), findsOneWidget);

      await tester.longPress(find.byType(ChatMedia));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer le message'));
      await tester.pumpAndSettle();

      expect(find.byType(ChatMedia), findsNothing);
      expect(find.text('Message supprimé'), findsOneWidget);
    });
  });

  group('Bornes d’un média', () {
    test('une vidéo trop lourde est refusée, une photo jamais', () {
      final MediaSelection lourde = MediaSelection(
        bytes: Uint8List(AppConfig.chatMediaMaxVideoBytes + 1),
        extension: 'mp4',
        kind: MediaKind.video,
      );
      expect(lourde.isTooHeavy, isTrue);

      final MediaSelection courte = MediaSelection(
        bytes: Uint8List(1024),
        extension: 'mp4',
        kind: MediaKind.video,
      );
      expect(courte.isTooHeavy, isFalse);

      // Les photos sont compressées à la sélection : la borne de poids ne les
      // concerne pas.
      final MediaSelection photo = MediaSelection(
        bytes: Uint8List(AppConfig.chatMediaMaxVideoBytes + 1),
        extension: 'jpg',
        kind: MediaKind.image,
      );
      expect(photo.isTooHeavy, isFalse);
    });

    test('l’extension se déduit du nom, avec un repli selon le type', () {
      expect(MediaSelection.extensionOf('photo.HEIC', MediaKind.image), 'heic');
      expect(MediaSelection.extensionOf('film.MP4', MediaKind.video), 'mp4');
      // Un nom venu du web porte parfois une chaîne de requête.
      expect(
        MediaSelection.extensionOf('image.png?v=2', MediaKind.image),
        'png',
      );
      // Sans extension lisible, le repli suit le type déclaré.
      expect(
        MediaSelection.extensionOf('sans-extension', MediaKind.image),
        'jpg',
      );
      expect(MediaSelection.extensionOf(null, MediaKind.video), 'mp4');
    });

    test('le poids se lit en ko ou en Mo', () {
      expect(
        MediaSelection(
          bytes: Uint8List(500 * 1024),
          extension: 'jpg',
          kind: MediaKind.image,
        ).sizeLabel,
        '500 ko',
      );
      expect(
        MediaSelection(
          bytes: Uint8List(3 * 1024 * 1024 + 200 * 1024),
          extension: 'mp4',
          kind: MediaKind.video,
        ).sizeLabel,
        '3,2 Mo',
      );
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

  group('Avatars dans la conversation', () {
    /// Trois messages d'affilée de Léa, puis un de moi — l'ordre du dépôt est
    /// du plus récent au plus ancien, la liste étant inversée à l'affichage.
    List<Message> serie() => <Message>[
      Message(
        id: 'b1',
        groupId: 'g1',
        senderId: 'u2',
        createdAt: DateTime(2026, 8, 3, 8, 45),
        content: 'Et le troisième',
        senderName: 'Léa Marchand',
        senderAvatarUrl: 'preset:p2_07',
      ),
      Message(
        id: 'b2',
        groupId: 'g1',
        senderId: 'u2',
        createdAt: DateTime(2026, 8, 3, 8, 44),
        content: 'Puis le deuxième',
        senderName: 'Léa Marchand',
        senderAvatarUrl: 'preset:p2_07',
      ),
      Message(
        id: 'b3',
        groupId: 'g1',
        senderId: 'u2',
        createdAt: DateTime(2026, 8, 3, 8, 43),
        content: 'D’abord le premier',
        senderName: 'Léa Marchand',
        senderAvatarUrl: 'preset:p2_07',
      ),
      Message(
        id: 'b4',
        groupId: 'g1',
        senderId: FakeChatRepository.moi,
        createdAt: DateTime(2026, 8, 3, 8, 42),
        content: 'Un mot de moi',
      ),
    ];

    testWidgets('une série ne porte qu’un seul avatar, sur le dernier', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester, messages: serie());
      await _ouvrirDiscussion(tester);

      // Trois bulles de Léa, un seul visage : le poser sur chacune donnerait
      // une colonne de visages répétés.
      expect(find.byType(AvatarImage), findsOneWidget);

      // Et c'est bien le dernier de la série. On compare les distances
      // plutôt qu'un seuil en pixels : ce qui compte est que l'avatar soit
      // près de la dernière bulle, pas de la première.
      final double avatar = tester.getRect(find.byType(AvatarImage)).bottom;
      final double dernier = tester
          .getRect(find.text('Et le troisième'))
          .bottom;
      final double premier = tester
          .getRect(find.text('D’abord le premier'))
          .bottom;
      expect(
        (avatar - dernier).abs(),
        lessThan((avatar - premier).abs()),
        reason: 'l’avatar doit coller au bas de la série, pas à son haut',
      );
    });

    testWidgets('la gouttière reste réservée : les bulles restent alignées', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester, messages: serie());
      await _ouvrirDiscussion(tester);

      // Sans réservation, les deux premières bulles glisseraient vers la
      // gauche et la série serait en escalier.
      final double sansAvatar = tester
          .getRect(find.text('D’abord le premier'))
          .left;
      final double avecAvatar = tester
          .getRect(find.text('Et le troisième'))
          .left;
      expect(sansAvatar, avecAvatar);
    });

    testWidgets('mes propres messages n’ont pas d’avatar', (
      WidgetTester tester,
    ) async {
      await _pumpApp(
        tester,
        messages: <Message>[
          Message(
            id: 'seul',
            groupId: 'g1',
            senderId: FakeChatRepository.moi,
            createdAt: DateTime(2026, 8, 3, 8, 42),
            content: 'Un mot de moi',
          ),
        ],
      );
      await _ouvrirDiscussion(tester);

      expect(find.text('Un mot de moi'), findsOneWidget);
      expect(find.byType(AvatarImage), findsNothing);
    });

    testWidgets('l’avatar prédéfini de l’expéditeur est bien rendu', (
      WidgetTester tester,
    ) async {
      // Le même point de rendu que partout ailleurs : c'est ce qui fait que
      // `preset:` est compris ici sans code propre au chat.
      await _pumpApp(tester, messages: serie());
      await _ouvrirDiscussion(tester);

      final AvatarImage avatar = tester.widget<AvatarImage>(
        find.byType(AvatarImage),
      );
      expect(
        AvatarData.assetPourAvatar(avatar.data.imageUrl),
        'assets/avatars/p2_07.png',
      );
    });
  });

  group('Les cartes de tâche et d’événement', () {
    Message carteTache({
      required Map<String, dynamic> carte,
      String id = 'c1',
      DateTime? quand,
    }) => Message(
      id: id,
      groupId: 'g1',
      senderId: 'autre',
      createdAt: quand ?? DateTime(2026, 8, 3, 8, 30),
      content: carte['titre'] as String?,
      senderName: 'Julie Martin',
      taskId: 't-carte',
      card: MessageCard.fromJson(<String, dynamic>{'sorte': 'tache', ...carte}),
    );

    Message carteEvenement(Map<String, dynamic> carte) => Message(
      id: 'c2',
      groupId: 'g1',
      senderId: 'autre',
      createdAt: DateTime(2026, 8, 3, 8, 31),
      content: carte['titre'] as String?,
      senderName: 'Julie Martin',
      eventId: 'e-carte',
      card: MessageCard.fromJson(<String, dynamic>{
        'sorte': 'evenement',
        ...carte,
      }),
    );

    testWidgets('une tâche proposée au groupe porte Oui et Non', (
      WidgetTester tester,
    ) async {
      await _pumpApp(
        tester,
        avecNotifications: false,
        messages: <Message>[
          carteTache(
            carte: <String, dynamic>{
              'titre': 'Acheter du pain',
              'supprimee': false,
              'prise': false,
              'terminee': false,
              'due_at': DateTime(2026, 8, 4, 18).toIso8601String(),
              'assignes': <dynamic>[],
            },
          ),
        ],
      );
      await _ouvrirDiscussion(tester);

      expect(find.byType(MessageCardTile), findsOneWidget);
      expect(find.text('Acheter du pain'), findsOneWidget);
      expect(find.text('Oui'), findsOneWidget);
      expect(find.text('Non'), findsOneWidget);
      expect(
        find.textContaining('personne ne l’a encore prise'),
        findsOneWidget,
      );
    });

    testWidgets('« Oui » prend la tâche et la carte le dit', (
      WidgetTester tester,
    ) async {
      final FakeTaskRepository taches = FakeTaskRepository();
      await _pumpApp(
        tester,
        avecNotifications: false,
        tasks: taches,
        messages: <Message>[
          carteTache(
            carte: <String, dynamic>{
              'titre': 'Acheter du pain',
              'supprimee': false,
              'prise': false,
              'terminee': false,
              'assignes': <dynamic>[],
            },
          ),
        ],
      );
      await _ouvrirDiscussion(tester);

      await tester.tap(find.text('Oui'));
      await tester.pumpAndSettle();

      expect(taches.lastTakenId, 't-carte');
      expect(find.text('Vous avez pris cette tâche.'), findsOneWidget);
    });

    testWidgets('deux personnes ne prennent pas la même tâche', (
      WidgetTester tester,
    ) async {
      // La base a tranché : quelqu’un est passé avant. L’écran doit le dire
      // proprement, et non se taire parce qu’aucune exception n’a été levée.
      final FakeTaskRepository taches = FakeTaskRepository()
        ..takeOutcome = 'deja_prise';
      await _pumpApp(
        tester,
        avecNotifications: false,
        tasks: taches,
        messages: <Message>[
          carteTache(
            carte: <String, dynamic>{
              'titre': 'Acheter du pain',
              'supprimee': false,
              'prise': false,
              'terminee': false,
              'assignes': <dynamic>[],
            },
          ),
        ],
      );
      await _ouvrirDiscussion(tester);

      await tester.tap(find.text('Oui'));
      await tester.pumpAndSettle();

      expect(
        find.text('Quelqu’un vient de la prendre avant vous.'),
        findsOneWidget,
      );
    });

    testWidgets('une tâche prise annonce son preneur, sans boutons', (
      WidgetTester tester,
    ) async {
      await _pumpApp(
        tester,
        avecNotifications: false,
        messages: <Message>[
          carteTache(
            carte: <String, dynamic>{
              'titre': 'Acheter du pain',
              'supprimee': false,
              'prise': true,
              'terminee': false,
              'assignes': <dynamic>[
                <String, dynamic>{
                  'user_id': 'u-thomas',
                  'status': 'accepted',
                  'nom': 'Thomas',
                },
              ],
            },
          ),
        ],
      );
      await _ouvrirDiscussion(tester);

      expect(find.text('Thomas a pris la tâche'), findsOneWidget);
      // Les boutons ont disparu pour les autres.
      expect(find.text('Oui'), findsNothing);
      expect(find.text('Non'), findsNothing);
      // Et il n’est pas proposé à un tiers de se désister.
      expect(find.text('Me désister'), findsNothing);
    });

    testWidgets('celui qui l’a prise peut se désister', (
      WidgetTester tester,
    ) async {
      final FakeTaskRepository taches = FakeTaskRepository();
      await _pumpApp(
        tester,
        avecNotifications: false,
        tasks: taches,
        messages: <Message>[
          carteTache(
            carte: <String, dynamic>{
              'titre': 'Acheter du pain',
              'supprimee': false,
              'prise': true,
              'terminee': false,
              'mon_statut': 'accepted',
              'assignes': <dynamic>[
                <String, dynamic>{
                  'user_id': 'moi',
                  'status': 'accepted',
                  'nom': 'Camille Rousseau',
                },
              ],
            },
          ),
        ],
      );
      await _ouvrirDiscussion(tester);

      expect(find.text('Me désister'), findsOneWidget);
      await tester.tap(find.text('Me désister'));
      await tester.pumpAndSettle();

      expect(taches.lastWithdrawnId, 't-carte');
      expect(
        find.text('Vous avez rendu cette tâche au groupe.'),
        findsOneWidget,
      );
    });

    testWidgets('une tâche confiée annonce son assigné et sa réponse', (
      WidgetTester tester,
    ) async {
      await _pumpApp(
        tester,
        avecNotifications: false,
        messages: <Message>[
          carteTache(
            carte: <String, dynamic>{
              'titre': 'Acheter du pain',
              'supprimee': false,
              // Confiée, donc **pas** prise : c’est ce drapeau qui sépare les
              // deux phrases, l’état de `task_assignees` étant le même.
              'prise': false,
              'terminee': false,
              'assignes': <dynamic>[
                <String, dynamic>{
                  'user_id': 'u-thomas',
                  'status': 'pending',
                  'nom': 'Thomas',
                },
              ],
            },
          ),
        ],
      );
      await _ouvrirDiscussion(tester);

      expect(find.text('Tâche attribuée à Thomas'), findsOneWidget);
      expect(find.text('Oui'), findsNothing);
      expect(find.text('Me désister'), findsNothing);
    });

    testWidgets('la carte suit le refus de l’assigné', (
      WidgetTester tester,
    ) async {
      await _pumpApp(
        tester,
        avecNotifications: false,
        messages: <Message>[
          carteTache(
            carte: <String, dynamic>{
              'titre': 'Acheter du pain',
              'supprimee': false,
              'prise': false,
              'terminee': false,
              'assignes': <dynamic>[
                <String, dynamic>{
                  'user_id': 'u-thomas',
                  'status': 'declined',
                  'nom': 'Thomas',
                },
              ],
            },
          ),
        ],
      );
      await _ouvrirDiscussion(tester);

      expect(find.text('Thomas a refusé la tâche'), findsOneWidget);
    });

    testWidgets('une tâche supprimée laisse une carte qui le dit', (
      WidgetTester tester,
    ) async {
      await _pumpApp(
        tester,
        avecNotifications: false,
        messages: <Message>[
          carteTache(
            carte: <String, dynamic>{
              'titre': 'Acheter du pain',
              'supprimee': true,
              'prise': false,
              'terminee': false,
              'assignes': <dynamic>[],
            },
          ),
        ],
      );
      await _ouvrirDiscussion(tester);

      expect(find.text('Cette tâche a été supprimée.'), findsOneWidget);
      // Le titre reste : une carte sans titre ne dirait plus de quoi il
      // s’agissait.
      expect(find.text('Acheter du pain'), findsOneWidget);
      expect(find.text('Oui'), findsNothing);
    });

    testWidgets('un événement porte trois réponses et son décompte', (
      WidgetTester tester,
    ) async {
      final FakeEventRepository evenements = FakeEventRepository();
      await _pumpApp(
        tester,
        avecNotifications: false,
        events: evenements,
        messages: <Message>[
          carteEvenement(<String, dynamic>{
            'titre': 'Randonnée du lac Blanc',
            'supprimee': false,
            'starts_at': DateTime(2026, 8, 10, 9).toIso8601String(),
            'ends_at': DateTime(2026, 8, 10, 17).toIso8601String(),
            'lieu': 'Chamonix',
            'oui': 3,
            'peut_etre': 1,
            'non': 2,
          }),
        ],
      );
      await _ouvrirDiscussion(tester);

      expect(find.text('Randonnée du lac Blanc'), findsOneWidget);
      expect(find.text('3 oui · 1 peut-être · 2 non'), findsOneWidget);

      final double non = tester.getCenter(find.text('Non')).dx;
      final double oui = tester.getCenter(find.text('Oui')).dx;
      expect(non, lessThan(oui));

      await tester.tap(find.text('Peut-être'));
      await tester.pumpAndSettle();
      expect(evenements.lastRespondedId, 'e-carte');
    });

    testWidgets('un événement supprimé laisse une carte qui le dit', (
      WidgetTester tester,
    ) async {
      await _pumpApp(
        tester,
        avecNotifications: false,
        messages: <Message>[
          carteEvenement(<String, dynamic>{
            'titre': 'Randonnée du lac Blanc',
            'supprimee': true,
            'starts_at': DateTime(2026, 8, 10, 9).toIso8601String(),
            'ends_at': DateTime(2026, 8, 10, 17).toIso8601String(),
          }),
        ],
      );
      await _ouvrirDiscussion(tester);

      expect(find.text('Cet événement a été supprimé.'), findsOneWidget);
      expect(find.text('Peut-être'), findsNothing);
    });

    testWidgets('la carte reste à sa place chronologique', (
      WidgetTester tester,
    ) async {
      // Une carte **est** un message : elle se range à son heure, sans
      // qu'aucun code n'ait à fusionner deux listes triées.
      await _pumpApp(
        tester,
        avecNotifications: false,
        messages: <Message>[
          Message(
            id: 'apres',
            groupId: 'g1',
            senderId: 'autre',
            createdAt: DateTime(2026, 8, 3, 9),
            content: 'après la carte',
            senderName: 'Julie Martin',
          ),
          carteTache(
            quand: DateTime(2026, 8, 3, 8, 30),
            carte: <String, dynamic>{
              'titre': 'Acheter du pain',
              'supprimee': false,
              'prise': false,
              'terminee': false,
              'assignes': <dynamic>[],
            },
          ),
          Message(
            id: 'avant',
            groupId: 'g1',
            senderId: 'autre',
            createdAt: DateTime(2026, 8, 3, 8),
            content: 'avant la carte',
            senderName: 'Julie Martin',
          ),
        ],
      );
      await _ouvrirDiscussion(tester);

      // La conversation se lit du haut vers le bas : le plus ancien est le
      // plus haut.
      final double avant = tester.getCenter(find.text('avant la carte')).dy;
      final double carte = tester.getCenter(find.byType(MessageCardTile)).dy;
      final double apres = tester.getCenter(find.text('après la carte')).dy;
      expect(avant, lessThan(carte));
      expect(carte, lessThan(apres));
    });
  });

  group('Écran de discussion refondu', () {
    testWidgets('l’en-tête porte le groupe, son effectif, et rien d’autre', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await _ouvrirDiscussion(tester);

      expect(
        find.descendant(
          of: find.byType(ChatHeader),
          matching: find.text('Famille Rousseau'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(ChatHeader),
          matching: find.text('3 membres'),
        ),
        findsOneWidget,
      );

      // Jelvo n'a ni appel audio ni appel vidéo : les pictogrammes de la
      // maquette promettraient une fonctionnalité qui n'arrive pas.
      expect(find.byIcon(Icons.call_rounded), findsNothing);
      expect(find.byIcon(Icons.call_outlined), findsNothing);
      expect(find.byIcon(Icons.videocam_rounded), findsNothing);
      expect(find.byIcon(Icons.videocam_outlined), findsNothing);
    });

    testWidgets('toucher l’en-tête ouvre l’écran du groupe', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await _ouvrirDiscussion(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(ChatHeader),
          matching: find.text('Famille Rousseau'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Anniversaires, vacances et rendez-vous médicaux'),
        findsOneWidget,
      );
    });

    testWidgets('la barre de raccourcis compte ce qui est en cours', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await _ouvrirDiscussion(tester);

      final Finder barre = find.byType(ChatShortcutBar);
      expect(barre, findsOneWidget);
      // Une tâche ouverte et un événement à venir dans g1 : les deux sortent
      // de `mes_taches` et `mon_agenda`, déjà chargées.
      expect(
        find.descendant(of: barre, matching: find.text('tâche')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: barre, matching: find.text('événement')),
        findsOneWidget,
      );

      // Ni listes ni dépenses : elles n'existent nulle part dans Jelvo.
      expect(
        find.descendant(of: barre, matching: find.text('liste')),
        findsNothing,
      );
      expect(
        find.descendant(of: barre, matching: find.text('dépense')),
        findsNothing,
      );
    });

    testWidgets('un groupe sans rien ne dit pas « 0 tâche »', (
      WidgetTester tester,
    ) async {
      // Ni tâche ni événement dans g1 : « 0 tâche · 0 événement » serait vrai,
      // inutile, et se lirait comme un défaut de chargement.
      await _pumpApp(
        tester,
        tasks: FakeTaskRepository(tasks: <Task>[]),
        events: FakeEventRepository(events: <CalendarEvent>[]),
      );
      await _ouvrirDiscussion(tester);

      final Finder barre = find.byType(ChatShortcutBar);
      expect(
        find.descendant(of: barre, matching: find.text('0')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: barre,
          matching: find.text('Rien de prévu pour l’instant'),
        ),
        findsOneWidget,
      );
      // Le chevron reste : la barre est aussi un chemin vers le groupe.
      expect(
        find.descendant(
          of: barre,
          matching: find.byIcon(Icons.chevron_right_rounded),
        ),
        findsOneWidget,
      );
    });

    testWidgets('le chevron de la barre mène au groupe', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await _ouvrirDiscussion(tester);

      await tester.tap(find.byType(ChatShortcutBar));
      await tester.pumpAndSettle();

      expect(
        find.text('Anniversaires, vacances et rendez-vous médicaux'),
        findsOneWidget,
      );
    });

    testWidgets('un séparateur coiffe chaque journée', (
      WidgetTester tester,
    ) async {
      await _pumpApp(
        tester,
        messages: <Message>[
          Message(
            id: 'j2',
            groupId: 'g1',
            senderId: 'u2',
            createdAt: DateTime(2026, 8, 3, 8),
            content: 'ce matin',
            senderName: 'Léa Marchand',
          ),
          Message(
            id: 'j1',
            groupId: 'g1',
            senderId: 'u2',
            createdAt: DateTime(2026, 8, 2, 20),
            content: 'hier soir',
            senderName: 'Léa Marchand',
          ),
        ],
      );
      await _ouvrirDiscussion(tester);

      expect(find.byType(ChatDayDivider), findsNWidgets(2));
      expect(find.text('Aujourd\'hui'), findsOneWidget);
      expect(find.text('Hier'), findsOneWidget);

      // Le séparateur coiffe la journée : « Hier » est au-dessus du message
      // d'hier, et « Aujourd'hui » au-dessus de celui de ce matin.
      expect(
        tester.getCenter(find.text('Hier')).dy,
        lessThan(tester.getCenter(find.text('hier soir')).dy),
      );
      expect(
        tester.getCenter(find.text('hier soir')).dy,
        lessThan(tester.getCenter(find.text('Aujourd\'hui')).dy),
      );
    });

    testWidgets('un changement de jour recoupe la série', (
      WidgetTester tester,
    ) async {
      await _pumpApp(
        tester,
        messages: <Message>[
          Message(
            id: 'j2',
            groupId: 'g1',
            senderId: 'u2',
            createdAt: DateTime(2026, 8, 3, 8),
            content: 'ce matin',
            senderName: 'Léa Marchand',
          ),
          Message(
            id: 'j1',
            groupId: 'g1',
            senderId: 'u2',
            createdAt: DateTime(2026, 8, 2, 20),
            content: 'hier soir',
            senderName: 'Léa Marchand',
          ),
        ],
      );
      await _ouvrirDiscussion(tester);

      // Même expéditeur des deux côtés du séparateur : son nom se relit
      // quand même, sinon la journée du dessous commencerait sans dire qui
      // parle.
      expect(find.text('Léa Marchand'), findsNWidgets(2));
    });

    testWidgets('le nom de l’expéditeur porte sa propre couleur', (
      WidgetTester tester,
    ) async {
      await _pumpApp(
        tester,
        messages: <Message>[
          Message(
            id: 'd2',
            groupId: 'g1',
            senderId: 'u9',
            createdAt: DateTime(2026, 8, 3, 8, 10),
            content: 'et moi le pain',
            senderName: 'Thomas Bernard',
          ),
          Message(
            id: 'd1',
            groupId: 'g1',
            senderId: 'u2',
            createdAt: DateTime(2026, 8, 3, 8),
            content: 'j’apporte le dessert',
            senderName: 'Léa Marchand',
          ),
        ],
      );
      await _ouvrirDiscussion(tester);

      Color couleurDe(String nom) =>
          tester.widget<Text>(find.text(nom)).style!.color!;

      expect(couleurDe('Léa Marchand'), SpeakerAccent.colorFor('u2'));
      expect(couleurDe('Thomas Bernard'), SpeakerAccent.colorFor('u9'));
      // Deux personnes, deux couleurs : c'est tout l'objet du dispositif.
      expect(couleurDe('Léa Marchand'), isNot(couleurDe('Thomas Bernard')));
      // Et jamais le gris de légende, qui ne distinguait personne.
      expect(couleurDe('Léa Marchand'), isNot(AppColors.textSecondary));
    });
  });

  group('Sélecteur d’emoji', () {
    testWidgets('le panneau s’ouvre et se referme', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await _ouvrirDiscussion(tester);

      expect(find.byType(EmojiPicker), findsNothing);

      await tester.tap(find.byTooltip('Emojis'));
      await tester.pumpAndSettle();
      expect(find.byType(EmojiPicker), findsOneWidget);

      await tester.tap(find.byTooltip('Fermer les emojis'));
      await tester.pumpAndSettle();
      expect(find.byType(EmojiPicker), findsNothing);
    });

    testWidgets('un cœur tapé au clavier sort en couleur dans la bulle', (
      WidgetTester tester,
    ) async {
      // Le défaut d'origine : `❤️` (U+2764 U+FE0F) est couvert par Inter, qui
      // le capturait avant que le repli d'emojis soit consulté — d'où un cœur
      // noir, alors que `😀`, absent d'Inter, sortait bien en couleur.
      await _pumpApp(
        tester,
        messages: <Message>[
          Message(
            id: 'c1',
            groupId: 'g1',
            senderId: 'u2',
            createdAt: DateTime(2026, 8, 3, 8),
            content: 'Merci ❤️ à demain',
            senderName: 'Léa Marchand',
          ),
        ],
      );
      await _ouvrirDiscussion(tester);

      final List<TextSpan> feuilles = <TextSpan>[];
      void aplatir(TextSpan span) {
        if (span.text != null) feuilles.add(span);
        for (final InlineSpan e in span.children ?? const <InlineSpan>[]) {
          if (e is TextSpan) aplatir(e);
        }
      }

      // La bulle porte plusieurs `RichText` — le nom, le contenu, l'heure :
      // on les aplatit tous plutôt que de parier sur leur ordre.
      for (final RichText morceau in tester.widgetList<RichText>(
        find.descendant(
          of: find.byType(MessageBubble),
          matching: find.byType(RichText),
        ),
      )) {
        aplatir(morceau.text as TextSpan);
      }

      final TextSpan coeur = feuilles.firstWhere(
        (TextSpan s) => s.text == '❤️',
      );
      expect(coeur.style?.fontFamily, AppTypography.emojiFamily);

      // Et le texte autour n'a pas changé de police pour autant.
      expect(
        feuilles
            .firstWhere((TextSpan s) => s.text == 'Merci ')
            .style
            ?.fontFamily,
        isNot(AppTypography.emojiFamily),
      );
    });

    testWidgets('l’emoji s’insère à l’endroit du curseur', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await _ouvrirDiscussion(tester);

      await tester.enterText(find.byType(TextField), 'bravo !');
      await tester.pump();

      // Le curseur est replacé après « bravo », avant le point
      // d'exclamation : on pose souvent un emoji au milieu d'une phrase
      // déjà écrite.
      final EditableTextState champ = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      champ.updateEditingValue(
        const TextEditingValue(
          text: 'bravo !',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Emojis'));
      await tester.pumpAndSettle();
      // Un emoji de la première famille, celle qui s'ouvre — et qui ne sert
      // pas d'onglet, sans quoi le finder en trouverait deux.
      await tester.tap(
        find.descendant(
          of: find.byType(EmojiPicker),
          matching: find.text('🙂'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'bravo🙂 !',
      );
    });
  });

  group('Messages vocaux', () {
    testWidgets('le micro remplace l’envoi tant qu’on n’a rien écrit', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await _ouvrirDiscussion(tester);

      expect(find.byTooltip('Enregistrer un message vocal'), findsOneWidget);
      expect(find.byTooltip('Envoyer'), findsNothing);

      await tester.enterText(find.byType(TextField), 'coucou');
      await tester.pump();

      expect(find.byTooltip('Envoyer'), findsOneWidget);
      expect(find.byTooltip('Enregistrer un message vocal'), findsNothing);
    });

    testWidgets('enregistrer puis envoyer dépose un message audio', (
      WidgetTester tester,
    ) async {
      final FakeVoiceRecorder micro = FakeVoiceRecorder(
        duree: const Duration(seconds: 8),
      );
      final FakeChatRepository chat = await _pumpApp(tester, recorder: micro);
      await _ouvrirDiscussion(tester);

      await tester.tap(find.byTooltip('Enregistrer un message vocal'));
      await tester.pumpAndSettle();

      // La barre change d'état : on annule ou on envoie, on n'écrit plus.
      expect(find.text('Enregistrement…'), findsOneWidget);
      expect(micro.demarrages, 1);

      await tester.tap(find.byTooltip('Envoyer le message vocal'));
      await tester.pumpAndSettle();

      expect(chat.lastSentKind, MediaKind.audio);
      expect(chat.lastSentDuration, const Duration(seconds: 8));
      // Le chemin suit la convention du bucket : le groupe en premier
      // segment, c'est lui que lisent les politiques.
      expect(chat.lastUploadedPath, startsWith('g1/'));
      expect(chat.lastUploadedPath, endsWith('.m4a'));
    });

    testWidgets('annuler n’envoie rien', (WidgetTester tester) async {
      final FakeVoiceRecorder micro = FakeVoiceRecorder();
      final FakeChatRepository chat = await _pumpApp(tester, recorder: micro);
      await _ouvrirDiscussion(tester);

      await tester.tap(find.byTooltip('Enregistrer un message vocal'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Annuler l’enregistrement'));
      await tester.pumpAndSettle();

      expect(micro.annulations, 1);
      expect(chat.lastSentKind, isNull);
      expect(find.text('Enregistrement…'), findsNothing);
    });

    testWidgets('un micro refusé le dit, et n’enregistre pas', (
      WidgetTester tester,
    ) async {
      final FakeVoiceRecorder micro = FakeVoiceRecorder(autorisation: false);
      await _pumpApp(tester, recorder: micro);
      await _ouvrirDiscussion(tester);

      await tester.tap(find.byTooltip('Enregistrer un message vocal'));
      await tester.pumpAndSettle();

      // Un refus est définitif côté application : l'écran renvoie aux
      // réglages du navigateur plutôt qu'à un bouton qui ne ferait rien.
      expect(
        find.textContaining('réglages de votre navigateur'),
        findsOneWidget,
      );
      expect(find.text('Enregistrement…'), findsNothing);
    });

    testWidgets('la bulle annonce la durée sans rien télécharger', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester, messages: <Message>[_vocal()]);
      await _ouvrirDiscussion(tester);

      // La durée vient de `messages.media_duree_s` : elle s'affiche avant
      // toute lecture, sans URL signée ni octet transféré.
      expect(find.byType(VoiceMessage), findsOneWidget);
      expect(find.text('0:12'), findsOneWidget);
      expect(find.byTooltip('Écouter'), findsOneWidget);

      // Un message vocal n'est pas une vignette : pas de cadre d'image.
      expect(find.byType(ChatMedia), findsNothing);
    });

    testWidgets('écouter demande l’URL signée et lance la lecture', (
      WidgetTester tester,
    ) async {
      final FakeVoicePlayer lecteur = FakeVoicePlayer();
      await _pumpApp(tester, messages: <Message>[_vocal()], player: lecteur);
      await _ouvrirDiscussion(tester);

      await tester.tap(find.byTooltip('Écouter'));
      await tester.pumpAndSettle();

      expect(lecteur.urlChargee, contains('g1/vocal.m4a'));
      expect(find.byTooltip('Mettre en pause'), findsOneWidget);
    });
  });
}

/// Un message vocal de douze secondes, prêt à être posé dans un décor.
Message _vocal() => Message(
  id: 'v1',
  groupId: 'g1',
  senderId: 'u2',
  createdAt: DateTime(2026, 8, 3, 8, 45),
  mediaUrl: 'g1/vocal.m4a',
  mediaKind: MediaKind.audio,
  mediaDuration: const Duration(seconds: 12),
  senderName: 'Léa Marchand',
);
