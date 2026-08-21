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
import 'package:jelvo/features/calendar/providers/calendar_providers.dart';
import 'package:jelvo/features/chat/models/media_selection.dart';
import 'package:jelvo/features/chat/models/message.dart';
import 'package:jelvo/features/chat/providers/chat_providers.dart';
import 'package:jelvo/features/chat/repository/chat_repository.dart';
import 'package:jelvo/features/chat/widgets/chat_media.dart';
import 'package:jelvo/features/contacts/providers/contact_providers.dart';
import 'package:jelvo/features/groups/providers/group_providers.dart';
import 'package:jelvo/features/notifications/models/app_notification.dart';
import 'package:jelvo/features/notifications/providers/notification_providers.dart';
import 'package:jelvo/features/notifications/providers/push_providers.dart';
import 'package:jelvo/features/profile/providers/profile_providers.dart';
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

final DateTime _testNow = DateTime(2026, 8, 3, 9);

Future<FakeChatRepository> _pumpApp(
  WidgetTester tester, {
  Map<String, int>? unread,
  bool avecNotifications = true,
  List<Message>? messages,
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
        taskRepositoryProvider.overrideWithValue(FakeTaskRepository()),
        eventRepositoryProvider.overrideWithValue(FakeEventRepository()),
        contactRepositoryProvider.overrideWithValue(FakeContactRepository()),
        chatRepositoryProvider.overrideWithValue(chat),
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

  group('Médias', () {
    testWidgets('le bouton de pièce jointe est proposé', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await _ouvrirDiscussion(tester);

      expect(find.byTooltip('Joindre une photo ou une vidéo'), findsOneWidget);
    });

    testWidgets('la feuille propose photo et vidéo, jamais un document', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await _ouvrirDiscussion(tester);

      await tester.tap(find.byTooltip('Joindre une photo ou une vidéo'));
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
}
