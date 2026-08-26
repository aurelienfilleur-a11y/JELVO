import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jelvo/core/core.dart';
import 'package:jelvo/data/app_config.dart';
import 'package:jelvo/data/clock.dart';
import 'package:jelvo/data/data_providers.dart';
import 'package:jelvo/features/contacts/providers/contact_providers.dart';
import 'package:jelvo/features/contacts/widgets/qr_support.dart';
import 'package:jelvo/features/contacts/models/contact.dart';
import 'package:jelvo/features/contacts/widgets/favorites_strip.dart';
import 'package:jelvo/features/groups/models/group_invite.dart';
import 'package:jelvo/features/groups/models/group_member.dart';
import 'package:jelvo/features/calendar/providers/calendar_providers.dart';
import 'package:jelvo/features/chat/providers/chat_providers.dart';
import 'package:jelvo/features/groups/providers/group_providers.dart';
import 'package:jelvo/features/tasks/providers/task_providers.dart';
import 'package:jelvo/features/groups/screens/join_group_screen.dart';
import 'package:jelvo/features/auth/providers/auth_providers.dart';
import 'package:jelvo/features/availability/providers/availability_providers.dart';
import 'package:jelvo/features/notifications/providers/push_providers.dart';
import 'package:jelvo/features/profile/providers/profile_providers.dart';
import 'package:jelvo/main.dart';
import 'package:jelvo/router/app_routes.dart';

import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_availability_repository.dart';
import 'fakes/fake_chat_repository.dart';
import 'fakes/fake_contact_repository.dart';
import 'fakes/fake_event_repository.dart';
import 'fakes/fake_group_repository.dart';
import 'fakes/fake_push.dart';
import 'fakes/fake_task_repository.dart';

final DateTime _testNow = DateTime(2026, 8, 3, 9);

/// Lance l'application complète avec les quatre dépôts simulés.
Future<({FakeGroupRepository groups, FakeContactRepository contacts})> _pumpApp(
  WidgetTester tester, {
  FakeGroupRepository? groupRepository,
  FakeContactRepository? contactRepository,
}) async {
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final FakeAuthRepository auth = FakeAuthRepository(signedIn: true);
  addTearDown(auth.dispose);
  final FakeGroupRepository groups = groupRepository ?? FakeGroupRepository();
  final FakeContactRepository contacts =
      contactRepository ?? FakeContactRepository();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(FixedClock(_testNow)),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        groupRepositoryProvider.overrideWithValue(groups),
        taskRepositoryProvider.overrideWithValue(FakeTaskRepository()),
        eventRepositoryProvider.overrideWithValue(FakeEventRepository()),
        contactRepositoryProvider.overrideWithValue(contacts),
        chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
        pushServiceProvider.overrideWithValue(FakePushService()),
        pushRepositoryProvider.overrideWithValue(FakePushRepository()),
        availabilityRepositoryProvider.overrideWithValue(
          FakeAvailabilityRepository(),
        ),
      ],
      child: const JelvoApp(),
    ),
  );
  await tester.pumpAndSettle();
  return (groups: groups, contacts: contacts);
}

/// Monte la seule page publique d'un lien, sans passer par la garde du routeur.
///
/// L'écran n'est atteignable que par une URL ; un routeur minimal évite de
/// dupliquer tout le graphe de navigation pour l'éprouver.
Future<void> _pumpJoinScreen(
  WidgetTester tester, {
  required FakeGroupRepository groups,
  bool signedIn = true,
}) async {
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final FakeAuthRepository auth = FakeAuthRepository(signedIn: signedIn);
  addTearDown(auth.dispose);

  final GoRouter router = GoRouter(
    initialLocation: '/rejoindre/jeton-test',
    routes: <RouteBase>[
      GoRoute(
        path: '/rejoindre/:jeton',
        builder: (BuildContext context, GoRouterState state) =>
            JoinGroupScreen(token: state.pathParameters['jeton'] ?? ''),
      ),
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('accueil')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(FixedClock(_testNow)),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        groupRepositoryProvider.overrideWithValue(groups),
        taskRepositoryProvider.overrideWithValue(FakeTaskRepository()),
        eventRepositoryProvider.overrideWithValue(FakeEventRepository()),
        contactRepositoryProvider.overrideWithValue(FakeContactRepository()),
        chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
        pushServiceProvider.overrideWithValue(FakePushService()),
        pushRepositoryProvider.overrideWithValue(FakePushRepository()),
        availabilityRepositoryProvider.overrideWithValue(
          FakeAvailabilityRepository(),
        ),
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting(AppDates.locale));

  group('Groupes', () {
    testWidgets('la liste affiche les groupes de l’utilisateur', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);

      await tester.tap(find.text('Groupes'));
      await tester.pumpAndSettle();

      expect(find.text('Famille Rousseau'), findsOneWidget);
      expect(find.text('Vacances en Corse'), findsOneWidget);
      expect(find.text('3 membres'), findsOneWidget);
    });

    testWidgets('un carnet vide propose de créer un groupe', (
      WidgetTester tester,
    ) async {
      await _pumpApp(
        tester,
        groupRepository: FakeGroupRepository(groups: const []),
      );

      await tester.tap(find.text('Groupes'));
      await tester.pumpAndSettle();

      expect(find.text('Aucun groupe pour le moment'), findsOneWidget);
      expect(find.text('Créer un groupe'), findsWidgets);
    });

    testWidgets('ouvrir un groupe affiche ses membres', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);

      await tester.tap(find.text('Groupes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Famille Rousseau'));
      await tester.pumpAndSettle();

      expect(find.text('Membres'), findsOneWidget);
      expect(find.text('Léa Marchand'), findsOneWidget);
      expect(find.text('Camille Rousseau (vous)'), findsOneWidget);
      // L'utilisateur est admin de ce groupe : la modification lui est ouverte.
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    });

    testWidgets('un nom vide bloque la création', (WidgetTester tester) async {
      final ({FakeContactRepository contacts, FakeGroupRepository groups})
      fakes = await _pumpApp(tester);

      await tester.tap(find.text('Groupes'));
      await tester.pumpAndSettle();
      // Le « + » central de la barre porte la même icône : on vise le bouton
      // d'en-tête par son infobulle.
      await tester.tap(find.byTooltip('Nouveau groupe').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Créer le groupe'));
      await tester.pump();

      expect(find.text('Donnez un nom à votre groupe.'), findsOneWidget);
      expect(fakes.groups.lastDeletedGroupId, isNull);
    });

    testWidgets('le formulaire propose d’inviter dès la création', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);

      await tester.tap(find.text('Groupes'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Nouveau groupe').first);
      await tester.pumpAndSettle();

      // Avant, il fallait créer le groupe puis inviter dans un second temps.
      expect(find.text('Choisir dans mes contacts'), findsOneWidget);
      // Les contacts acceptés seulement : Noah est une demande en attente.
      expect(find.text('Léa'), findsOneWidget);
      expect(find.text('Yanis'), findsOneWidget);
      expect(find.text('Noah'), findsNothing);
      expect(
        find.text('Personne n’est invité pour l’instant.'),
        findsOneWidget,
      );
    });

    testWidgets('les invitations partent à la création du groupe', (
      WidgetTester tester,
    ) async {
      final ({FakeContactRepository contacts, FakeGroupRepository groups})
      fakes = await _pumpApp(tester);

      await tester.tap(find.text('Groupes'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Nouveau groupe').first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Coloc Bastille');
      await tester.tap(find.text('Léa'));
      await tester.pumpAndSettle();
      expect(find.text('1 personne sera invitée.'), findsOneWidget);

      await tester.tap(find.text('Créer le groupe'));
      await tester.pumpAndSettle();

      expect(fakes.groups.lastCreatedName, 'Coloc Bastille');
      expect(fakes.groups.invitedUserIds, <String>['u2']);
      expect(find.text('Membres'), findsOneWidget);
    });

    testWidgets('une invitation qui ne part pas est annoncée', (
      WidgetTester tester,
    ) async {
      // Le groupe est créé : un échec d'invitation ne doit ni le perdre, ni
      // passer sous silence. Sans message, on croit avoir invité quelqu'un.
      final FakeGroupRepository groups = FakeGroupRepository();
      groups.refuseInvitationsPour.add('u3');
      await _pumpApp(tester, groupRepository: groups);

      await tester.tap(find.text('Groupes'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Nouveau groupe').first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Voyage');
      await tester.tap(find.text('Yanis'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Créer le groupe'));
      await tester.pumpAndSettle();

      expect(groups.lastCreatedName, 'Voyage');
      expect(find.text('Membres'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('créer un groupe mène à son écran', (
      WidgetTester tester,
    ) async {
      final ({FakeContactRepository contacts, FakeGroupRepository groups})
      fakes = await _pumpApp(tester);

      await tester.tap(find.text('Groupes'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Nouveau groupe').first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Coloc Bastille');
      await tester.tap(find.text('Créer le groupe'));
      await tester.pumpAndSettle();

      expect(fakes.groups.lastCreatedName, 'Coloc Bastille');
      // L'écran du groupe remplace le formulaire, qui ne doit pas se rouvrir
      // par un retour arrière.
      expect(find.text('Créer le groupe'), findsNothing);
      expect(find.text('Membres'), findsOneWidget);
    });

    testWidgets('quitter un groupe passe par une confirmation', (
      WidgetTester tester,
    ) async {
      final ({FakeContactRepository contacts, FakeGroupRepository groups})
      fakes = await _pumpApp(tester);

      await tester.tap(find.text('Groupes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Famille Rousseau'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitter le groupe').last);
      await tester.pumpAndSettle();

      // Tant que la confirmation n'est pas donnée, rien n'est envoyé.
      expect(fakes.groups.lastLeftGroupId, isNull);

      await tester.tap(find.text('Quitter').last);
      await tester.pumpAndSettle();

      expect(fakes.groups.lastLeftGroupId, 'g1');
    });
  });

  group('Invitation par lien', () {
    testWidgets('un lien valide présente le groupe et permet de rejoindre', (
      WidgetTester tester,
    ) async {
      final FakeGroupRepository groups = FakeGroupRepository();
      await _pumpJoinScreen(tester, groups: groups);

      expect(find.text('Vacances en Corse'), findsOneWidget);
      expect(find.text('4 membres'), findsOneWidget);

      await tester.tap(find.text('Rejoindre le groupe'));
      await tester.pumpAndSettle();

      expect(groups.lastJoinedToken, 'jeton-test');
    });

    testWidgets('un lien expiré est refusé avec un message en français', (
      WidgetTester tester,
    ) async {
      await _pumpJoinScreen(
        tester,
        groups: FakeGroupRepository(previewStatus: InviteLinkStatus.expire),
      );

      expect(find.text('Lien inutilisable'), findsOneWidget);
      expect(
        find.textContaining('Ce lien d’invitation a expiré'),
        findsOneWidget,
      );
      expect(find.text('Rejoindre le groupe'), findsNothing);
    });

    testWidgets('un lien révoqué est refusé', (WidgetTester tester) async {
      await _pumpJoinScreen(
        tester,
        groups: FakeGroupRepository(previewStatus: InviteLinkStatus.revoque),
      );

      expect(
        find.textContaining('a été révoqué par le groupe'),
        findsOneWidget,
      );
    });

    testWidgets('sans session, le lien mène à l’inscription', (
      WidgetTester tester,
    ) async {
      await _pumpJoinScreen(
        tester,
        groups: FakeGroupRepository(),
        signedIn: false,
      );

      expect(find.text('Créer un compte pour rejoindre'), findsOneWidget);
      expect(find.text('J\'ai déjà un compte'), findsOneWidget);
      expect(find.text('Rejoindre le groupe'), findsNothing);
    });

    testWidgets('déjà membre, le message le dit sans erreur', (
      WidgetTester tester,
    ) async {
      final FakeGroupRepository groups = FakeGroupRepository(
        joinOutcome: JoinOutcome.dejaMembre,
      );
      await _pumpJoinScreen(tester, groups: groups);

      await tester.tap(find.text('Rejoindre le groupe'));
      await tester.pumpAndSettle();

      expect(groups.lastJoinedToken, 'jeton-test');
    });
  });

  group('Adhésion temporaire', () {
    /// Léa, membre jusqu'au 20 août — deux semaines après l'horloge figée.
    FakeGroupRepository avecMembreTemporaire() => FakeGroupRepository(
      members: <GroupMember>[
        FakeGroupRepository.demoMembers.first,
        GroupMember(
          userId: 'u2',
          role: GroupRole.member,
          pseudo: 'lea.marchand',
          firstName: 'Léa',
          lastName: 'Marchand',
          expiresAt: DateTime(2026, 8, 20, 23, 59),
        ),
      ],
    );

    Future<void> ouvrirGroupe(WidgetTester tester) async {
      await tester.tap(find.text('Groupes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Famille Rousseau'));
      await tester.pumpAndSettle();
    }

    testWidgets('un membre temporaire porte sa date de fin', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester, groupRepository: avecMembreTemporaire());
      await ouvrirGroupe(tester);

      // La date, et pas seulement une pastille : sans elle, un administrateur
      // ne sait pas s'il doit prolonger.
      expect(find.textContaining('Jusqu’au'), findsOneWidget);
      expect(find.textContaining('20 août'), findsOneWidget);
    });

    testWidgets('un membre permanent n’affiche aucune date', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await ouvrirGroupe(tester);

      expect(find.textContaining('Jusqu’au'), findsNothing);
    });

    testWidgets('un administrateur prolonge depuis le menu du membre', (
      WidgetTester tester,
    ) async {
      final FakeGroupRepository groups = avecMembreTemporaire();
      await _pumpApp(tester, groupRepository: groups);
      await ouvrirGroupe(tester);

      await tester.tap(find.byTooltip('Gérer ce membre').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Modifier la durée de l’adhésion'));
      await tester.pumpAndSettle();

      expect(find.text('Durée de l’adhésion'), findsOneWidget);
      // Ouvrir la feuille n'écrit rien : c'est « Enregistrer » qui décide.
      expect(groups.termSet, isFalse);

      await tester.tap(find.text('3 mois'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(groups.lastTermUserId, 'u2');
      // 3 novembre : 90 jours après le 3 août, à la fin de la journée.
      expect(groups.lastTerm, DateTime(2026, 11, 1, 23, 59, 59));
    });

    testWidgets('« Sans terme » rend l’adhésion permanente', (
      WidgetTester tester,
    ) async {
      final FakeGroupRepository groups = avecMembreTemporaire();
      await _pumpApp(tester, groupRepository: groups);
      await ouvrirGroupe(tester);

      await tester.tap(find.byTooltip('Gérer ce membre').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Modifier la durée de l’adhésion'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sans terme'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      // `null` seul ne prouverait rien — c'est aussi la valeur de « jamais
      // appelé ». Le drapeau lève l'ambiguïté.
      expect(groups.termSet, isTrue);
      expect(groups.lastTerm, isNull);
      expect(find.textContaining('n’a plus de terme'), findsOneWidget);
    });

    testWidgets('un refus de la base reste dans la feuille', (
      WidgetTester tester,
    ) async {
      // Le dernier administrateur ne peut pas devenir temporaire : la feuille
      // doit le dire sans se refermer, sinon on croit la date posée.
      final FakeGroupRepository groups = avecMembreTemporaire();
      groups.termOutcome = 'dernier_admin';
      await _pumpApp(tester, groupRepository: groups);
      await ouvrirGroupe(tester);

      await tester.tap(find.byTooltip('Gérer ce membre').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Modifier la durée de l’adhésion'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 mois'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(find.text('Enregistrer'), findsOneWidget);
      expect(find.textContaining('au moins un administrateur'), findsOneWidget);
    });

    testWidgets('l’invitation nominative emporte la durée choisie', (
      WidgetTester tester,
    ) async {
      final ({FakeContactRepository contacts, FakeGroupRepository groups})
      fakes = await _pumpApp(tester);
      await ouvrirGroupe(tester);

      await tester.tap(find.text('Inviter'));
      await tester.pumpAndSettle();

      expect(find.text('Durée de l’adhésion'), findsOneWidget);
      await tester.tap(find.text('1 semaine'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'sarah');
      // Laisse passer le débounce de la recherche par pseudo.
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await tester.tap(find.text('Inviter').last);
      await tester.pumpAndSettle();

      expect(fakes.groups.lastInvitedTerm, DateTime(2026, 8, 10, 23, 59, 59));
    });

    testWidgets('sans choix, l’invitation reste permanente', (
      WidgetTester tester,
    ) async {
      // « Sans terme » est l'état d'ouverture : une durée doit se choisir,
      // jamais s'appliquer par défaut.
      final ({FakeContactRepository contacts, FakeGroupRepository groups})
      fakes = await _pumpApp(tester);
      await ouvrirGroupe(tester);

      await tester.tap(find.text('Inviter'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'sarah');
      // Laisse passer le débounce de la recherche par pseudo.
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await tester.tap(find.text('Inviter').last);
      await tester.pumpAndSettle();

      expect(fakes.groups.lastInvitedUserId, isNotNull);
      expect(fakes.groups.lastInvitedTerm, isNull);
    });

    testWidgets('le lien généré emporte la durée et l’affiche', (
      WidgetTester tester,
    ) async {
      final ({FakeContactRepository contacts, FakeGroupRepository groups})
      fakes = await _pumpApp(tester);
      await ouvrirGroupe(tester);

      await tester.tap(find.text('Partager un lien'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('1 semaine'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Générer un lien'));
      await tester.pumpAndSettle();

      expect(fakes.groups.lastLinkTerm, DateTime(2026, 8, 10, 23, 59, 59));
      // Deux dates coexistent sur la carte : celle du lien et celle de
      // l'adhésion. C'est la seconde qu'on éprouve.
      expect(find.textContaining('Adhésion jusqu’au'), findsWidgets);
    });

    testWidgets('la page publique annonce la durée avant d’accepter', (
      WidgetTester tester,
    ) async {
      await _pumpJoinScreen(
        tester,
        groups: FakeGroupRepository(
          previewMembershipExpiresAt: DateTime(2026, 8, 20, 23, 59),
        ),
      );

      expect(find.textContaining('Adhésion temporaire'), findsOneWidget);
      expect(find.textContaining('20 août 2026'), findsOneWidget);
      // Le bouton reste : l'adhésion est temporaire, pas refusée.
      expect(find.text('Rejoindre le groupe'), findsOneWidget);
    });
  });

  group('Contacts', () {
    testWidgets('les favoris sont épinglés en tête du carnet', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);

      await tester.tap(find.text('Contacts'));
      await tester.pumpAndSettle();

      final Offset lea = tester.getTopLeft(find.text('Léa Marchand'));
      final Offset yanis = tester.getTopLeft(find.text('Yanis Bertrand'));
      expect(lea.dy, lessThan(yanis.dy));
    });

    testWidgets('une demande reçue peut être acceptée', (
      WidgetTester tester,
    ) async {
      final ({FakeContactRepository contacts, FakeGroupRepository groups})
      fakes = await _pumpApp(tester);

      await tester.tap(find.text('Contacts'));
      await tester.pumpAndSettle();

      expect(find.text('Demandes reçues'), findsOneWidget);
      expect(find.text('Noah Delacroix'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.check_circle_rounded));
      await tester.pumpAndSettle();

      expect(fakes.contacts.lastAcceptedUserId, 'u4');
    });

    testWidgets('une demande reçue peut être refusée', (
      WidgetTester tester,
    ) async {
      final ({FakeContactRepository contacts, FakeGroupRepository groups})
      fakes = await _pumpApp(tester);

      await tester.tap(find.text('Contacts'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close_rounded).last);
      await tester.pumpAndSettle();

      expect(fakes.contacts.lastDeclinedUserId, 'u4');
    });

    testWidgets('la recherche par pseudo propose d’ajouter la personne', (
      WidgetTester tester,
    ) async {
      final ({FakeContactRepository contacts, FakeGroupRepository groups})
      fakes = await _pumpApp(tester);

      await tester.tap(find.text('Contacts'));
      await tester.pumpAndSettle();
      // Le « + » de l'en-tête ouvre désormais la feuille des trois moyens
      // d'ajouter quelqu'un ; la recherche par pseudo en est un.
      await tester.tap(
        find.descendant(
          of: find.byType(AppScreen),
          matching: find.byTooltip('Ajouter un contact'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rechercher un pseudo'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'sarah');
      // Laisse passer le débounce de la recherche.
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('Sarah Nguyen'), findsOneWidget);

      await tester.tap(find.text('Ajouter'));
      await tester.pumpAndSettle();

      expect(fakes.contacts.lastRequestedUserId, 'u5');
      expect(find.text('Demande envoyée.'), findsOneWidget);
    });
  });

  group('Bouton « + » contextuel', () {
    test('l’identifiant de groupe se lit dans le chemin', () {
      expect(AppRoutes.groupIdIn('/groupes/g1'), 'g1');
      expect(AppRoutes.groupIdIn('/groupes/g1/modifier'), 'g1');
      // « nouveau » est l'écran de création, pas un groupe : sinon le « + »
      // proposerait d'ajouter au groupe qu'on est en train de créer.
      expect(AppRoutes.groupIdIn(AppRoutes.groupCreatePath), isNull);
      expect(AppRoutes.groupIdIn('/groupes'), isNull);
      expect(AppRoutes.groupIdIn('/calendrier'), isNull);
    });

    testWidgets('depuis un groupe, il ne propose plus d’en créer un', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);

      await tester.tap(find.text('Groupes'));
      await tester.pumpAndSettle();
      // Sur la liste, le « + » crée bien un groupe.
      expect(find.byTooltip('Nouveau groupe'), findsWidgets);

      await tester.tap(find.text('Famille Rousseau'));
      await tester.pumpAndSettle();

      // Dans un groupe déjà créé, il n'y a plus de groupe à créer.
      expect(find.byTooltip('Nouveau groupe'), findsNothing);
      expect(find.byTooltip('Ajouter au groupe'), findsOneWidget);

      await tester.tap(find.byTooltip('Ajouter au groupe'));
      await tester.pumpAndSettle();

      expect(find.text('Nouvel événement'), findsOneWidget);
      expect(find.text('Nouvelle tâche'), findsOneWidget);
    });

    testWidgets('la feuille ouvre la création déjà réglée sur le groupe', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);

      await tester.tap(find.text('Groupes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Famille Rousseau'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ajouter au groupe'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nouvelle tâche'));
      await tester.pumpAndSettle();

      // Le formulaire s'ouvre en feuille, réglé sur la tâche.
      expect(find.text('Créer la tâche'), findsOneWidget);
      // La carte d'assignation n'apparaît que pour une tâche de groupe :
      // sa présence prouve que le groupe a bien été transmis.
      expect(find.text('Assigner à'), findsOneWidget);
      expect(find.text('Léa Marchand'), findsWidgets);
    });

    testWidgets('l’écran de groupe offre un chemin visible sans le « + »', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);

      await tester.tap(find.text('Groupes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Famille Rousseau'));
      await tester.pumpAndSettle();

      // Une action par section : le « + » de la barre n'est pas le seul accès.
      expect(find.text('Ajouter'), findsNWidgets(2));

      await tester.tap(find.text('Ajouter').first);
      await tester.pumpAndSettle();

      expect(find.text('Créer l’événement'), findsOneWidget);
      // Participants du groupe, donc contexte transmis — et l'heure de fin,
      // qui manquait à la création d'événement.
      expect(find.text('Participants'), findsOneWidget);
      expect(find.text('Fin'), findsOneWidget);
    });
  });

  group('Lien partagé', () {
    test('le lien porte le fragment attendu par le routage web', () {
      final String url = AppConfig.inviteUrl('jeton-abc');

      // Sans `usePathUrlStrategy()`, la route vit après le `#`. Un lien sans
      // fragment tombe sur le 404 de GitHub Pages, qui sert `index.html` :
      // l'application démarre alors sur l'accueil et le jeton est perdu.
      expect(url, endsWith('/#/rejoindre/jeton-abc'));
      expect(url, startsWith(AppConfig.webBaseUrl));
    });
  });

  group('QR code', () {
    test('le contenu encodé se relit', () {
      expect(
        QrContact.encode('Camille.Rousseau'),
        'jelvo:contact/camille.rousseau',
      );
      expect(
        QrContact.decode('jelvo:contact/camille.rousseau'),
        'camille.rousseau',
      );
    });

    test('un pseudo nu reste accepté', () {
      expect(QrContact.decode('camille.rousseau'), 'camille.rousseau');
    });

    test('un QR étranger est rejeté', () {
      expect(QrContact.decode('https://example.test/produit/42'), isNull);
      expect(QrContact.decode('ab'), isNull);
      expect(QrContact.decode(null), isNull);
    });
  });

  group('Le carnet refondu', () {
    Future<void> ouvrirContacts(WidgetTester tester) async {
      await tester.tap(find.text('Contacts'));
      await tester.pumpAndSettle();
    }

    testWidgets('le titre et le « + » de l’en-tête', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await ouvrirContacts(tester);

      expect(find.text('Mes contacts'), findsOneWidget);
      expect(find.text('Rechercher un contact'), findsOneWidget);
    });

    testWidgets('la bande des favoris met en avant les contacts étoilés', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await ouvrirContacts(tester);

      expect(find.byType(FavoritesStrip), findsOneWidget);
      expect(find.text('Favoris'), findsOneWidget);
      // Léa est le seul favori du jeu d'essai ; Yanis n'y est pas.
      expect(
        find.descendant(
          of: find.byType(FavoritesStrip),
          matching: find.text('Léa'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(FavoritesStrip),
          matching: find.text('Yanis'),
        ),
        findsNothing,
      );
    });

    testWidgets('la bande suit l’étoile immédiatement', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await ouvrirContacts(tester);

      // L'étoile est restée là où elle était : sur la ligne du contact.
      await tester.tap(find.byTooltip('Ajouter aux favoris').first);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(FavoritesStrip),
          matching: find.text('Yanis'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Retirer des favoris').first);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(FavoritesStrip),
          matching: find.text('Léa'),
        ),
        findsNothing,
      );
    });

    testWidgets('le carnet est rangé par lettre, avec ses en-têtes', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await ouvrirContacts(tester);

      // Bertrand puis Marchand : la clé de tri est le nom complet, qui
      // commence par le prénom — donc L pour Léa, Y pour Yanis.
      expect(find.byKey(const ValueKey<String>('lettre-L')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('lettre-Y')), findsOneWidget);
      expect(
        tester.getCenter(find.byKey(const ValueKey<String>('lettre-L'))).dy,
        lessThan(
          tester.getCenter(find.byKey(const ValueKey<String>('lettre-Y'))).dy,
        ),
      );
    });

    testWidgets('le bouton de tri inverse l’ordre', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await ouvrirContacts(tester);

      expect(find.text('A–Z'), findsOneWidget);
      await tester.tap(find.text('A–Z'));
      await tester.pumpAndSettle();

      expect(find.text('Z–A'), findsOneWidget);
      expect(
        tester.getCenter(find.byKey(const ValueKey<String>('lettre-Y'))).dy,
        lessThan(
          tester.getCenter(find.byKey(const ValueKey<String>('lettre-L'))).dy,
        ),
      );
    });

    testWidgets('le nombre de groupes en commun est affiché', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await ouvrirContacts(tester);

      expect(find.text('3'), findsWidgets);
      expect(find.text('groupes'), findsOneWidget);
      // Une seule adhésion partagée se dit au singulier.
      expect(find.text('groupe'), findsOneWidget);
    });

    testWidgets('toucher une ligne ouvre ce qu’on peut en faire', (
      WidgetTester tester,
    ) async {
      final ({FakeContactRepository contacts, FakeGroupRepository groups})
      fakes = await _pumpApp(tester);
      await ouvrirContacts(tester);

      await tester.tap(find.text('Léa Marchand'));
      await tester.pumpAndSettle();

      // Retirer un contact existait en base sans être atteignable.
      expect(find.text('Retirer de mes contacts'), findsOneWidget);
      await tester.tap(find.text('Retirer de mes contacts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retirer'));
      await tester.pumpAndSettle();

      expect(fakes.contacts.lastRemovedUserId, 'u2');
    });

    testWidgets('le « + » propose les trois moyens d’ajouter quelqu’un', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await ouvrirContacts(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(AppScreen),
          matching: find.byTooltip('Ajouter un contact'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Scanner un QR Code'), findsOneWidget);
      expect(find.text('Rechercher un pseudo'), findsOneWidget);
      expect(find.text('Inviter un ami'), findsOneWidget);
    });

    testWidgets('« Gérer » ouvre de quoi épingler à la chaîne', (
      WidgetTester tester,
    ) async {
      final ({FakeContactRepository contacts, FakeGroupRepository groups})
      fakes = await _pumpApp(tester);
      await ouvrirContacts(tester);

      await tester.tap(find.text('Gérer'));
      await tester.pumpAndSettle();

      expect(find.text('Gérer les favoris'), findsOneWidget);
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(fakes.contacts.lastFavoriteValue, isNotNull);
    });

    testWidgets('sans favori, la bande invite à en poser un', (
      WidgetTester tester,
    ) async {
      await _pumpApp(
        tester,
        contactRepository: FakeContactRepository(
          contacts: <Contact>[
            const Contact(
              id: 'u2',
              pseudo: 'lea.marchand',
              firstName: 'Léa',
              lastName: 'Marchand',
            ),
          ],
        ),
      );
      await ouvrirContacts(tester);

      expect(find.byType(FavoritesStrip), findsOneWidget);
      expect(find.textContaining('Épinglez vos proches'), findsOneWidget);
    });

    testWidgets('sur un carnet vide, la bande ne s’affiche pas', (
      WidgetTester tester,
    ) async {
      await _pumpApp(
        tester,
        contactRepository: FakeContactRepository(contacts: <Contact>[]),
      );
      await ouvrirContacts(tester);

      expect(find.byType(FavoritesStrip), findsNothing);
      expect(find.text('Carnet vide'), findsOneWidget);
    });

    testWidgets('une recherche sans résultat le dit, sans bande', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await ouvrirContacts(tester);

      await tester.enterText(find.byType(TextField).first, 'zzz');
      await tester.pumpAndSettle();

      expect(find.text('Aucun résultat'), findsOneWidget);
      expect(find.byType(FavoritesStrip), findsNothing);
    });

    testWidgets('la ligne tient à 360 dp de large', (
      WidgetTester tester,
    ) async {
      // Avatar, nom, pseudo, pastille, étoile et chevron sur la même ligne :
      // c'est la largeur minimale que le projet s'impose.
      tester.view.physicalSize = const Size(360, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpApp(tester);
      await ouvrirContacts(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Léa Marchand'), findsOneWidget);
    });
  });
}
