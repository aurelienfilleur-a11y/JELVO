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
import 'package:jelvo/features/calendar/widgets/group_selector.dart';
import 'package:jelvo/features/chat/providers/chat_providers.dart';
import 'package:jelvo/features/contacts/providers/contact_providers.dart';
import 'package:jelvo/features/groups/providers/group_providers.dart';
import 'package:jelvo/features/groups/widgets/invite_link_sheet.dart';
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

typedef _Fakes = ({
  FakeTaskRepository taches,
  FakeEventRepository agenda,
  FakeGroupRepository groupes,
});

Future<_Fakes> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(420, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final FakeAuthRepository auth = FakeAuthRepository(signedIn: true);
  addTearDown(auth.dispose);
  final FakeTaskRepository taches = FakeTaskRepository();
  final FakeEventRepository agenda = FakeEventRepository();
  final FakeGroupRepository groupes = FakeGroupRepository();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(FixedClock(_testNow)),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        groupRepositoryProvider.overrideWithValue(groupes),
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
  return (taches: taches, agenda: agenda, groupes: groupes);
}

/// Ouvre le formulaire d'un groupe : Groupes → Famille Rousseau → « + ».
Future<void> _ouvrirDepuisLeGroupe(WidgetTester tester, String quoi) async {
  await tester.tap(find.text('Groupes'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Famille Rousseau'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Ajouter au groupe'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(quoi));
  await tester.pumpAndSettle();
}

Future<void> _ouvrirCreationDeGroupe(WidgetTester tester) async {
  await tester.tap(find.text('Groupes'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Nouveau groupe').first);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting(AppDates.locale));

  group('Nouvelle tâche', () {
    testWidgets('personne n’est présélectionné, et la mention le dit', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await _ouvrirDepuisLeGroupe(tester, 'Nouvelle tâche');

      expect(find.text('Assigner à'), findsOneWidget);
      // Le sens d'une rangée sans coche n'est pas « formulaire incomplet »,
      // c'est « proposée au groupe » — et rien d'autre ne le dirait.
      expect(find.textContaining('Proposée à tout le groupe'), findsOneWidget);
      expect(find.textContaining('Confiée à'), findsNothing);
    });

    testWidgets('choisir quelqu’un change la mention', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await _ouvrirDepuisLeGroupe(tester, 'Nouvelle tâche');

      await tester.tap(find.text('Léa').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('Proposée à tout le groupe'), findsNothing);
      expect(
        find.text('Confiée à Léa, qui recevra une notification.'),
        findsOneWidget,
      );
    });

    testWidgets('sans assigné, la liste part vide et non nulle', (
      WidgetTester tester,
    ) async {
      // `creer_tache` lit `null` comme « assigne l'auteur » et `[]` comme
      // « proposée au groupe ». Les confondre donnerait une tâche déjà prise
      // par celui qui la crée, sans boutons dans la conversation.
      final _Fakes fakes = await _pumpApp(tester);
      await _ouvrirDepuisLeGroupe(tester, 'Nouvelle tâche');

      await tester.enterText(find.byType(TextField).first, 'Sortir les vélos');
      await tester.tap(find.text('Créer la tâche'));
      await tester.pumpAndSettle();

      expect(fakes.taches.lastCreatedTitle, 'Sortir les vélos');
      expect(fakes.taches.lastCreatedAssignees, isEmpty);
      expect(fakes.taches.lastCreatedAssignees, isNotNull);
    });

    testWidgets('« Autre » ne s’affiche pas quand la rangée montre tout', (
      WidgetTester tester,
    ) async {
      // Un bouton qui n'ouvrirait que les visages déjà visibles n'irait nulle
      // part : le groupe de démonstration compte deux membres.
      await _pumpApp(tester);
      await _ouvrirDepuisLeGroupe(tester, 'Nouvelle tâche');

      expect(find.text('Autre'), findsNothing);
    });

    testWidgets('« Plus d’options » replie échéance, priorité et description', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await _ouvrirDepuisLeGroupe(tester, 'Nouvelle tâche');

      expect(find.text('Échéance'), findsNothing);
      expect(find.text('Plus d’options'), findsOneWidget);

      await tester.tap(find.text('Plus d’options'));
      await tester.pumpAndSettle();

      expect(find.text('Échéance'), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);
      expect(find.text('0/200'), findsOneWidget);
    });
  });

  group('Nouvel événement', () {
    testWidgets('le groupe se choisit dans le formulaire', (
      WidgetTester tester,
    ) async {
      // Le groupe était imposé par l'écran d'où l'on venait : ouvert depuis le
      // « + », le formulaire ne savait créer qu'un rendez-vous personnel.
      final _Fakes fakes = await _pumpApp(tester);

      await tester.tap(find.text('Calendrier'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Créer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Événement'));
      await tester.pumpAndSettle();

      expect(find.byType(GroupSelector), findsOneWidget);
      expect(find.text('Personnel'), findsOneWidget);

      await tester.tap(find.byType(GroupSelector));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Famille Rousseau').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Barbecue');
      // Le libellé « Date * » est un `Text` au-dessus du champ : c'est
      // l'invite qui se touche.
      await tester.tap(find.text('Choisir').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Créer l’événement'));
      await tester.pumpAndSettle();

      expect(fakes.agenda.lastCreatedTitle, 'Barbecue');
      expect(fakes.agenda.lastCreatedGroupId, 'g1');
    });

    testWidgets('sans sélection, tous les membres sont conviés', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await _ouvrirDepuisLeGroupe(tester, 'Nouvel événement');

      // « Tous les membres » et non « aucun » : c'est ce que fait
      // `creer_evenement` quand la liste est nulle.
      expect(find.text('Participants'), findsOneWidget);
      expect(find.text('Tous les membres'), findsOneWidget);
    });

    testWidgets('choisir un participant se dit sur la ligne', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await _ouvrirDepuisLeGroupe(tester, 'Nouvel événement');

      await tester.tap(find.text('Participants'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Léa Marchand').last);
      await tester.pumpAndSettle();
      // Une feuille modale se referme par sa barrière : elle écrit au fil des
      // touches, il n'y a rien à valider.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('1 sur 2'), findsOneWidget);
    });

    testWidgets('la date, l’heure et la fin tiennent ensemble', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await _ouvrirDepuisLeGroupe(tester, 'Nouvel événement');

      // La maquette ne montre qu'une heure ; garder la fin évite de refiger la
      // durée à une heure, ce qu'elle a déjà été.
      expect(find.text('Date *'), findsOneWidget);
      expect(find.text('Heure *'), findsOneWidget);
      expect(find.text('Fin'), findsOneWidget);
    });

    testWidgets('la description est visible d’emblée, avec son compteur', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await _ouvrirDepuisLeGroupe(tester, 'Nouvel événement');

      expect(find.text('Description'), findsOneWidget);
      expect(find.text('0/200'), findsOneWidget);
      // Rien ne resterait à replier : l'image d'événement n'a pas de dépôt.
      expect(find.text('Plus d’options'), findsNothing);
    });
  });

  group('Nouveau groupe', () {
    testWidgets('la description porte un compteur de caractères', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await _ouvrirCreationDeGroupe(tester);

      expect(find.text('0/120'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(1), 'Les Rousseau');
      await tester.pump();

      expect(find.text('12/120'), findsOneWidget);
    });

    testWidgets('« Groupe privé » est un constat, pas un interrupteur', (
      WidgetTester tester,
    ) async {
      // La colonne `is_private` existe, mais **aucune politique ne la lit** :
      // tout groupe Jelvo est privé. Un interrupteur qui se décoche
      // promettrait un groupe public qui n'existe pas.
      await _pumpApp(tester);
      await _ouvrirCreationDeGroupe(tester);

      expect(find.text('Groupe privé'), findsOneWidget);
      expect(
        find.textContaining('Tous les groupes Jelvo le sont'),
        findsOneWidget,
      );
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(SwitchListTile), findsNothing);
    });

    testWidgets('les suggestions viennent des favoris et des groupes communs', (
      WidgetTester tester,
    ) async {
      // Léa est favorite et partage trois groupes, Yanis un seul : l'ordre
      // n'est pas alphabétique, il dit qui l'on fréquente.
      await _pumpApp(tester);
      await _ouvrirCreationDeGroupe(tester);

      expect(find.text('Suggestions'), findsOneWidget);
      final Offset lea = tester.getTopLeft(find.text('Léa'));
      final Offset yanis = tester.getTopLeft(find.text('Yanis'));
      expect(lea.dx, lessThan(yanis.dx));
      // Une demande en attente n'est pas un contact.
      expect(find.text('Noah'), findsNothing);
    });

    testWidgets('« Inviter par lien » ouvre la feuille après la création', (
      WidgetTester tester,
    ) async {
      // Un jeton se tire sur un groupe qui existe : l'intention se déclare
      // avant, et voyage par l'URL jusqu'à l'écran qui sait la satisfaire.
      final _Fakes fakes = await _pumpApp(tester);
      await _ouvrirCreationDeGroupe(tester);

      await tester.enterText(find.byType(TextField).first, 'Voyage à Rome');
      await tester.tap(find.text('Inviter par lien'));
      await tester.pumpAndSettle();
      expect(find.text('Proposé après la création'), findsOneWidget);

      await tester.tap(find.text('Créer le groupe'));
      await tester.pumpAndSettle();

      expect(fakes.groupes.lastCreatedName, 'Voyage à Rome');
      expect(find.byType(InviteLinkSheet), findsOneWidget);
    });

    testWidgets('sans ce choix, aucune feuille de lien ne s’ouvre', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await _ouvrirCreationDeGroupe(tester);

      await tester.enterText(find.byType(TextField).first, 'Coloc');
      await tester.tap(find.text('Créer le groupe'));
      await tester.pumpAndSettle();

      expect(find.byType(InviteLinkSheet), findsNothing);
    });

    testWidgets('« Choisir dans mes contacts » ouvre le carnet entier', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await _ouvrirCreationDeGroupe(tester);

      await tester.tap(find.text('Choisir dans mes contacts'));
      await tester.pumpAndSettle();

      // La feuille rend les noms entiers, là où la rangée n'a la place que du
      // prénom : c'est ce qui la rend utile.
      expect(find.text('Léa Marchand'), findsOneWidget);
      expect(find.text('Yanis Bertrand'), findsOneWidget);

      await tester.tap(find.text('Yanis Bertrand'));
      await tester.pumpAndSettle();
      // Une feuille modale se referme par sa barrière : elle écrit au fil des
      // touches, il n'y a rien à valider.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('1 personne sera invitée.'), findsOneWidget);
    });
  });
}
