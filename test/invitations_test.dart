import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jelvo/core/core.dart';
import 'package:jelvo/data/clock.dart';
import 'package:jelvo/data/data_providers.dart';
import 'package:jelvo/features/auth/providers/auth_providers.dart';
import 'package:jelvo/features/availability/providers/availability_providers.dart';
import 'package:jelvo/features/calendar/models/calendar_event.dart';
import 'package:jelvo/features/calendar/providers/calendar_providers.dart';
import 'package:jelvo/features/calendar/screens/event_invitation_screen.dart';
import 'package:jelvo/features/chat/providers/chat_providers.dart';
import 'package:jelvo/features/contacts/providers/contact_providers.dart';
import 'package:jelvo/features/groups/models/group_invite.dart';
import 'package:jelvo/features/groups/providers/group_providers.dart';
import 'package:jelvo/features/groups/screens/invitation_screen.dart';
import 'package:jelvo/features/notifications/models/app_notification.dart';
import 'package:jelvo/features/notifications/providers/notification_providers.dart';
import 'package:jelvo/features/notifications/providers/push_providers.dart';
import 'package:jelvo/features/notifications/screens/notifications_screen.dart';
import 'package:jelvo/features/profile/providers/profile_providers.dart';
import 'package:jelvo/features/tasks/models/task.dart';
import 'package:jelvo/features/tasks/providers/task_providers.dart';
import 'package:jelvo/features/tasks/screens/task_assignment_screen.dart';

import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_availability_repository.dart';
import 'fakes/fake_chat_repository.dart';
import 'fakes/fake_contact_repository.dart';
import 'fakes/fake_event_repository.dart';
import 'fakes/fake_group_repository.dart';
import 'fakes/fake_notification_repository.dart';
import 'fakes/fake_push.dart';
import 'fakes/fake_task_repository.dart';

final DateTime _maintenant = DateTime(2026, 8, 3, 9);

/// Monte un écran seul, avec un routeur minimal.
///
/// Les trois écrans d'invitation s'ouvrent depuis une notification et non
/// depuis un onglet : reconstruire tout le graphe de navigation pour les
/// atteindre coûterait plus qu'il n'éprouve.
Future<GoRouter> _pump(
  WidgetTester tester,
  Widget ecran, {
  FakeGroupRepository? groups,
  FakeTaskRepository? tasks,
  FakeEventRepository? events,
  FakeNotificationRepository? notifications,
}) async {
  tester.view.physicalSize = const Size(420, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final FakeAuthRepository auth = FakeAuthRepository(signedIn: true);
  addTearDown(auth.dispose);

  final GoRouter routeur = GoRouter(
    initialLocation: '/ecran',
    routes: <RouteBase>[
      GoRoute(
        path: '/ecran',
        builder: (BuildContext context, GoRouterState state) => ecran,
      ),
      GoRoute(
        path: '/',
        name: 'home',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('accueil')),
      ),
      GoRoute(
        path: '/groupes',
        name: 'groups',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('liste des groupes')),
      ),
      GoRoute(
        path: '/groupes/:id',
        name: 'groupDetail',
        builder: (BuildContext context, GoRouterState state) =>
            Scaffold(body: Text('groupe ${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/calendrier',
        name: 'calendar',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('calendrier')),
      ),
      GoRoute(
        path: '/evenements/:id',
        name: 'eventDetail',
        builder: (BuildContext context, GoRouterState state) =>
            Scaffold(body: Text('détail événement')),
      ),
      GoRoute(
        path: '/evenements/:id/invitation',
        name: 'eventInvitation',
        builder: (BuildContext context, GoRouterState state) =>
            EventInvitationScreen(eventId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/taches/:id',
        name: 'taskDetail',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('détail tâche')),
      ),
      GoRoute(
        path: '/taches/:id/attribution',
        name: 'taskAssignment',
        builder: (BuildContext context, GoRouterState state) =>
            TaskAssignmentScreen(taskId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/contacts',
        name: 'contacts',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('contacts')),
      ),
      GoRoute(
        path: '/invitations',
        name: 'invitations',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('invitations')),
      ),
      GoRoute(
        path: '/invitations/:id',
        name: 'invitation',
        builder: (BuildContext context, GoRouterState state) =>
            InvitationScreen(invitationId: state.pathParameters['id'] ?? ''),
      ),
    ],
  );
  addTearDown(routeur.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(FixedClock(_maintenant)),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        groupRepositoryProvider.overrideWithValue(
          groups ?? FakeGroupRepository(),
        ),
        taskRepositoryProvider.overrideWithValue(tasks ?? FakeTaskRepository()),
        eventRepositoryProvider.overrideWithValue(
          events ?? FakeEventRepository(),
        ),
        contactRepositoryProvider.overrideWithValue(FakeContactRepository()),
        chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
        notificationRepositoryProvider.overrideWithValue(
          notifications ?? FakeNotificationRepository(),
        ),
        pushServiceProvider.overrideWithValue(FakePushService()),
        pushRepositoryProvider.overrideWithValue(FakePushRepository()),
        availabilityRepositoryProvider.overrideWithValue(
          FakeAvailabilityRepository(),
        ),
      ],
      child: MaterialApp.router(routerConfig: routeur, theme: AppTheme.light),
    ),
  );
  await tester.pumpAndSettle();
  return routeur;
}

GroupInvitationDetail _detail({
  required InvitationScreenStatus statut,
  DateTime? membershipExpiresAt,
}) => GroupInvitationDetail(
  status: statut,
  id: 'inv-1',
  groupId: 'g1',
  groupName: 'Famille Rousseau',
  description: 'Le groupe de la maison',
  senderName: 'Julie Martin',
  memberCount: 4,
  members: const <InvitationMember>[
    InvitationMember(name: 'Julie'),
    InvitationMember(name: 'Paul'),
  ],
  groupCreatedAt: DateTime(2025, 3, 14),
  createdAt: _maintenant.subtract(const Duration(hours: 2)),
  membershipExpiresAt: membershipExpiresAt,
);

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  group('Invitation à un groupe', () {
    testWidgets('l’en-tête nomme qui invite, ce qu’il fait et depuis quand', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const InvitationScreen(invitationId: 'inv-1'),
        groups: FakeGroupRepository(
          invitationDetails: <GroupInvitationDetail>[
            _detail(statut: InvitationScreenStatus.valide),
          ],
        ),
      );

      expect(find.byType(InvitationHeader), findsOneWidget);
      expect(find.text('Julie Martin'), findsWidgets);
      expect(find.text('vous invite à rejoindre un groupe'), findsOneWidget);
      expect(find.text('il y a 2 h'), findsOneWidget);
    });

    testWidgets('la carte porte description, membres et date de création', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const InvitationScreen(invitationId: 'inv-1'),
        groups: FakeGroupRepository(
          invitationDetails: <GroupInvitationDetail>[
            _detail(statut: InvitationScreenStatus.valide),
          ],
        ),
      );

      expect(find.text('Le groupe de la maison'), findsOneWidget);
      expect(find.text('4 membres'), findsWidgets);
      expect(find.text('Créé le'), findsOneWidget);
      expect(find.text('Déjà dans le groupe'), findsOneWidget);
    });

    testWidgets('la photo de couverture du groupe coiffe l’écran', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const InvitationScreen(invitationId: 'inv-1'),
        groups: FakeGroupRepository(
          invitationDetails: <GroupInvitationDetail>[
            _detail(statut: InvitationScreenStatus.valide),
          ],
        ),
      );

      expect(find.byType(CoverBanner), findsOneWidget);
    });

    testWidgets('les deux boutons sont Refuser puis Rejoindre', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const InvitationScreen(invitationId: 'inv-1'),
        groups: FakeGroupRepository(
          invitationDetails: <GroupInvitationDetail>[
            _detail(statut: InvitationScreenStatus.valide),
          ],
        ),
      );

      expect(find.text('Refuser'), findsOneWidget);
      expect(find.text('Rejoindre'), findsOneWidget);

      // Le refus est à gauche du plein : la maquette pose cet ordre, et les
      // trois écrans le tiennent.
      final double refus = tester.getCenter(find.text('Refuser')).dx;
      final double accord = tester.getCenter(find.text('Rejoindre')).dx;
      expect(refus, lessThan(accord));
    });

    testWidgets('le terme de l’adhésion est annoncé avant les boutons', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const InvitationScreen(invitationId: 'inv-1'),
        groups: FakeGroupRepository(
          invitationDetails: <GroupInvitationDetail>[
            _detail(
              statut: InvitationScreenStatus.valide,
              membershipExpiresAt: DateTime(2026, 8, 31, 23, 59),
            ),
          ],
        ),
      );

      expect(find.textContaining('Adhésion temporaire'), findsOneWidget);
      expect(
        tester.getCenter(find.textContaining('Adhésion temporaire')).dy,
        lessThan(tester.getCenter(find.text('Rejoindre')).dy),
      );
    });

    testWidgets('une invitation déjà acceptée le dit et ouvre le groupe', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const InvitationScreen(invitationId: 'inv-1'),
        groups: FakeGroupRepository(
          invitationDetails: <GroupInvitationDetail>[
            _detail(statut: InvitationScreenStatus.acceptee),
          ],
        ),
      );

      expect(find.text('Invitation déjà acceptée'), findsOneWidget);
      // **Aucun bouton sans effet** : « Rejoindre » a disparu.
      expect(find.text('Rejoindre'), findsNothing);
      expect(find.text('Refuser'), findsNothing);

      await tester.tap(find.text('Ouvrir le groupe'));
      await tester.pumpAndSettle();
      expect(find.text('groupe g1'), findsOneWidget);
    });

    testWidgets('une invitation déjà refusée le dit sans bouton d’action', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const InvitationScreen(invitationId: 'inv-1'),
        groups: FakeGroupRepository(
          invitationDetails: <GroupInvitationDetail>[
            _detail(statut: InvitationScreenStatus.refusee),
          ],
        ),
      );

      expect(find.text('Invitation déjà refusée'), findsOneWidget);
      expect(find.text('Rejoindre'), findsNothing);
      expect(find.text('Ouvrir le groupe'), findsNothing);
    });

    testWidgets('une invitation expirée le dit', (WidgetTester tester) async {
      await _pump(
        tester,
        const InvitationScreen(invitationId: 'inv-1'),
        groups: FakeGroupRepository(
          invitationDetails: <GroupInvitationDetail>[
            _detail(statut: InvitationScreenStatus.expiree),
          ],
        ),
      );

      expect(find.text('Invitation expirée'), findsOneWidget);
      expect(find.text('Rejoindre'), findsNothing);
    });

    testWidgets('un groupe supprimé le dit, sans carte de groupe', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const InvitationScreen(invitationId: 'inv-1'),
        groups: FakeGroupRepository(
          invitationDetails: <GroupInvitationDetail>[
            _detail(statut: InvitationScreenStatus.groupeSupprime),
          ],
        ),
      );

      expect(find.text('Groupe supprimé'), findsOneWidget);
      // Le contexte n'a plus de sens : ni description, ni membres.
      expect(find.text('Le groupe de la maison'), findsNothing);
      expect(find.text('Rejoindre'), findsNothing);
    });

    testWidgets('un identifiant inconnu ne prétend pas à un groupe', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const InvitationScreen(invitationId: 'inconnue'),
        groups: FakeGroupRepository(),
      );

      expect(find.text('Invitation introuvable'), findsOneWidget);
      expect(find.text('Rejoindre'), findsNothing);
    });

    testWidgets('refuser appelle le dépôt', (WidgetTester tester) async {
      final FakeGroupRepository groups = FakeGroupRepository(
        invitations: <GroupInvitation>[
          const GroupInvitation(
            id: 'inv-1',
            groupId: 'g1',
            groupName: 'Famille Rousseau',
            senderName: 'Julie Martin',
          ),
        ],
      );
      await _pump(
        tester,
        const InvitationScreen(invitationId: 'inv-1'),
        groups: groups,
      );

      await tester.tap(find.text('Refuser'));
      await tester.pumpAndSettle();
      expect(await groups.fetchInvitations(), isEmpty);
    });
  });

  group('Invitation à un événement', () {
    List<CalendarEvent> lesEvenements({
      String? imageUrl,
      EventResponse reponse = EventResponse.pending,
    }) => <CalendarEvent>[
      CalendarEvent(
        id: 'e1',
        title: 'Randonnée du lac Blanc',
        start: DateTime(2026, 8, 10, 9),
        end: DateTime(2026, 8, 10, 17),
        location: 'Chamonix',
        groupId: 'g1',
        notes: 'Prévoir de l’eau',
        imageUrl: imageUrl,
        myResponse: reponse,
        authorName: 'Julie Martin',
        participants: const <EventParticipant>[
          EventParticipant(
            userId: 'u2',
            response: EventResponse.yes,
            name: 'Paul Girard',
          ),
        ],
        yesCount: 1,
      ),
    ];

    testWidgets('l’en-tête, le titre et les lignes de la carte', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const EventInvitationScreen(eventId: 'e1'),
        events: FakeEventRepository(events: lesEvenements()),
      );

      expect(find.text('Julie Martin'), findsOneWidget);
      expect(find.text('vous convie à un événement'), findsOneWidget);
      expect(find.text('Randonnée du lac Blanc'), findsOneWidget);
      expect(find.text('Date'), findsOneWidget);
      expect(find.text('Horaires'), findsOneWidget);
      expect(find.text('Chamonix'), findsOneWidget);
      expect(find.text('Paul Girard'), findsOneWidget);
    });

    testWidgets('l’image de l’événement l’emporte sur la couverture', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const EventInvitationScreen(eventId: 'e1'),
        events: FakeEventRepository(
          events: <CalendarEvent>[
            CalendarEvent(
              id: 'e1',
              title: 'Randonnée du lac Blanc',
              start: DateTime(2026, 8, 10, 9),
              end: DateTime(2026, 8, 10, 17),
              groupId: 'g1',
              imageUrl: 'https://exemple.test/rando.jpg',
              groupPhotoUrl: 'https://exemple.test/couverture.jpg',
              authorName: 'Julie Martin',
            ),
          ],
        ),
      );

      final CoverBanner bandeau = tester.widget<CoverBanner>(
        find.byType(CoverBanner),
      );
      expect(bandeau.photoUrl, 'https://exemple.test/rando.jpg');
    });

    testWidgets('sans image propre, la couverture du groupe prend le relais', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const EventInvitationScreen(eventId: 'e1'),
        events: FakeEventRepository(
          events: <CalendarEvent>[
            CalendarEvent(
              id: 'e1',
              title: 'Randonnée du lac Blanc',
              start: DateTime(2026, 8, 10, 9),
              end: DateTime(2026, 8, 10, 17),
              groupId: 'g1',
              groupName: 'Famille Rousseau',
              groupPhotoUrl: 'https://exemple.test/couverture.jpg',
              authorName: 'Julie Martin',
            ),
          ],
        ),
      );

      final CoverBanner bandeau = tester.widget<CoverBanner>(
        find.byType(CoverBanner),
      );
      expect(bandeau.photoUrl, 'https://exemple.test/couverture.jpg');
      expect(bandeau.name, 'Famille Rousseau');
    });

    testWidgets('sans rien, le bandeau retombe sur l’accent, sans image', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const EventInvitationScreen(eventId: 'e1'),
        events: FakeEventRepository(events: lesEvenements()),
      );

      final CoverBanner bandeau = tester.widget<CoverBanner>(
        find.byType(CoverBanner),
      );
      expect(bandeau.photoUrl, isNull);
      // Aucune illustration inventée : le repli est un dégradé, pas une image.
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('sans lieu, la ligne est absente plutôt que vide', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const EventInvitationScreen(eventId: 'e1'),
        events: FakeEventRepository(
          events: <CalendarEvent>[
            CalendarEvent(
              id: 'e1',
              title: 'Apéro',
              start: DateTime(2026, 8, 10, 19),
              end: DateTime(2026, 8, 10, 22),
              groupId: 'g1',
              authorName: 'Julie Martin',
            ),
          ],
        ),
      );

      expect(find.text('Lieu'), findsNothing);
      expect(find.text('Non précisé'), findsNothing);
    });

    testWidgets('la réponse a trois choix, du refus à l’accord', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const EventInvitationScreen(eventId: 'e1'),
        events: FakeEventRepository(events: lesEvenements()),
      );

      expect(find.text('Non'), findsOneWidget);
      expect(find.text('Peut-être'), findsOneWidget);
      expect(find.text('Oui'), findsOneWidget);

      final double non = tester.getCenter(find.text('Non')).dx;
      final double peut = tester.getCenter(find.text('Peut-être')).dx;
      final double oui = tester.getCenter(find.text('Oui')).dx;
      expect(non, lessThan(peut));
      expect(peut, lessThan(oui));
    });

    testWidgets('répondre « Peut-être » appelle le dépôt', (
      WidgetTester tester,
    ) async {
      final FakeEventRepository events = FakeEventRepository(
        events: lesEvenements(),
      );
      await _pump(
        tester,
        const EventInvitationScreen(eventId: 'e1'),
        events: events,
      );

      await tester.tap(find.text('Peut-être'));
      await tester.pumpAndSettle();
      expect(events.lastRespondedId, 'e1');
      expect(events.lastResponse, EventResponse.maybe);
    });

    testWidgets('une réponse déjà donnée est rappelée, sans verrouiller', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const EventInvitationScreen(eventId: 'e1'),
        events: FakeEventRepository(
          events: lesEvenements(reponse: EventResponse.yes),
        ),
      );

      expect(find.textContaining('Vous avez répondu : Oui'), findsOneWidget);
      // Changer d'avis reste possible : la base l'accepte.
      expect(find.text('Non'), findsOneWidget);
    });

    testWidgets('un événement supprimé le dit au lieu de proposer', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const EventInvitationScreen(eventId: 'disparu'),
        events: FakeEventRepository(events: <CalendarEvent>[]),
      );

      expect(find.text('Événement introuvable'), findsOneWidget);
      expect(find.text('Oui'), findsNothing);
    });
  });

  group('Tâche confiée', () {
    List<Task> lesTaches({
      AssigneeStatus? monStatut = AssigneeStatus.pending,
    }) => <Task>[
      Task(
        id: 't1',
        title: 'Réserver le restaurant',
        notes: 'Pour samedi soir',
        groupId: 'g1',
        dueDate: DateTime(2026, 8, 8, 18),
        priority: TaskPriority.high,
        myStatus: monStatut,
        authorName: 'Julie Martin',
        assignees: const <TaskAssignee>[
          TaskAssignee(
            userId: 'u1',
            status: AssigneeStatus.pending,
            name: 'Camille Rousseau',
          ),
        ],
      ),
    ];

    testWidgets('l’en-tête, le titre et les quatre lignes', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const TaskAssignmentScreen(taskId: 't1'),
        tasks: FakeTaskRepository(tasks: lesTaches()),
      );

      expect(find.text('Julie Martin'), findsOneWidget);
      expect(find.text('vous a confié une tâche'), findsOneWidget);
      expect(find.text('Réserver le restaurant'), findsOneWidget);
      expect(find.text('Groupe'), findsOneWidget);
      expect(find.text('Pour samedi soir'), findsOneWidget);
      expect(find.text('Échéance'), findsOneWidget);
      // `task_priority` existe en base : la ligne n'est pas inventée.
      expect(find.text('Priorité'), findsOneWidget);
      expect(find.text('Haute'), findsOneWidget);
      expect(find.textContaining('Camille Rousseau'), findsOneWidget);
    });

    testWidgets('la couverture du groupe coiffe aussi la tâche confiée', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const TaskAssignmentScreen(taskId: 't1'),
        tasks: FakeTaskRepository(
          tasks: <Task>[
            Task(
              id: 't1',
              title: 'Réserver le restaurant',
              groupId: 'g1',
              groupName: 'Famille Rousseau',
              groupPhotoUrl: 'https://exemple.test/couverture.jpg',
              myStatus: AssigneeStatus.pending,
              authorName: 'Julie Martin',
            ),
          ],
        ),
      );

      final CoverBanner bandeau = tester.widget<CoverBanner>(
        find.byType(CoverBanner),
      );
      expect(bandeau.photoUrl, 'https://exemple.test/couverture.jpg');
      // Le nom vient de `mes_taches`, pas de la liste locale des groupes :
      // un assigné n'est pas forcément membre.
      expect(bandeau.name, 'Famille Rousseau');
      expect(find.text('Famille Rousseau'), findsWidgets);
    });

    testWidgets('une tâche personnelle garde le bandeau, sans photo', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const TaskAssignmentScreen(taskId: 't1'),
        tasks: FakeTaskRepository(
          tasks: <Task>[
            const Task(
              id: 't1',
              title: 'Renouveler le passeport',
              myStatus: AssigneeStatus.pending,
              authorName: 'Julie Martin',
            ),
          ],
        ),
      );

      final CoverBanner bandeau = tester.widget<CoverBanner>(
        find.byType(CoverBanner),
      );
      expect(bandeau.photoUrl, isNull);
      expect(bandeau.name, 'Personnel');
    });

    testWidgets('les deux boutons sont Refuser puis Accepter', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const TaskAssignmentScreen(taskId: 't1'),
        tasks: FakeTaskRepository(tasks: lesTaches()),
      );

      final double refus = tester.getCenter(find.text('Refuser')).dx;
      final double accord = tester.getCenter(find.text('Accepter')).dx;
      expect(refus, lessThan(accord));
    });

    testWidgets('accepter appelle le dépôt', (WidgetTester tester) async {
      final FakeTaskRepository tasks = FakeTaskRepository(tasks: lesTaches());
      await _pump(
        tester,
        const TaskAssignmentScreen(taskId: 't1'),
        tasks: tasks,
      );

      await tester.tap(find.text('Accepter'));
      await tester.pumpAndSettle();
      expect(tasks.lastResponse, AssigneeStatus.accepted);
    });

    testWidgets('une tâche déjà acceptée le dit et ouvre la tâche', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const TaskAssignmentScreen(taskId: 't1'),
        tasks: FakeTaskRepository(
          tasks: lesTaches(monStatut: AssigneeStatus.accepted),
        ),
      );

      expect(find.text('Vous avez accepté cette tâche.'), findsOneWidget);
      expect(find.text('Accepter'), findsNothing);
      expect(find.text('Ouvrir la tâche'), findsOneWidget);
    });

    testWidgets('une tâche à laquelle on n’est pas assigné ne propose rien', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const TaskAssignmentScreen(taskId: 't1'),
        tasks: FakeTaskRepository(tasks: lesTaches(monStatut: null)),
      );

      expect(
        find.text('Cette tâche ne vous est pas assignée.'),
        findsOneWidget,
      );
      expect(find.text('Accepter'), findsNothing);
    });

    testWidgets('une tâche supprimée le dit au lieu de proposer', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const TaskAssignmentScreen(taskId: 'disparue'),
        tasks: FakeTaskRepository(tasks: <Task>[]),
      );

      expect(find.text('Tâche introuvable'), findsOneWidget);
      expect(find.text('Accepter'), findsNothing);
    });
  });

  group('Depuis la boîte de notifications', () {
    testWidgets('une tâche confiée y figure et ouvre son écran', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const NotificationsScreen(),
        tasks: FakeTaskRepository(
          tasks: <Task>[
            const Task(
              id: 't9',
              title: 'Réserver le restaurant',
              myStatus: AssigneeStatus.pending,
              authorName: 'Julie Martin',
            ),
          ],
        ),
        notifications: FakeNotificationRepository(
          notifications: <AppNotification>[
            AppNotification(
              id: 'n1',
              type: NotificationType.taskAssigned,
              payload: const <String, dynamic>{
                'task_id': 't9',
                'titre': 'Réserver le restaurant',
                'auteur': 'Julie Martin',
              },
              createdAt: _maintenant.subtract(const Duration(minutes: 30)),
            ),
          ],
        ),
      );

      expect(
        find.text('Julie Martin vous a confié cette tâche.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Réserver le restaurant'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskAssignmentScreen), findsOneWidget);
    });

    testWidgets('la réponse à une tâche confiée revient à son auteur', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const NotificationsScreen(),
        tasks: FakeTaskRepository(
          tasks: <Task>[const Task(id: 't9', title: 'Réserver le restaurant')],
        ),
        notifications: FakeNotificationRepository(
          notifications: <AppNotification>[
            AppNotification(
              id: 'n3',
              type: NotificationType.taskResponse,
              payload: const <String, dynamic>{
                'task_id': 't9',
                'titre': 'Réserver le restaurant',
                'reponse': 'accepted',
                'auteur': 'Léa Marchand',
              },
              createdAt: _maintenant,
            ),
          ],
        ),
      );

      expect(find.text('Léa Marchand accepte cette tâche.'), findsOneWidget);

      // Le **détail**, pas l'écran d'attribution : qui a confié la tâche n'y
      // est pas assigné et n'aurait rien à y répondre.
      await tester.tap(find.text('Réserver le restaurant'));
      await tester.pumpAndSettle();
      expect(find.text('détail tâche'), findsOneWidget);
    });

    testWidgets('un refus se lit comme un refus', (WidgetTester tester) async {
      await _pump(
        tester,
        const NotificationsScreen(),
        notifications: FakeNotificationRepository(
          notifications: <AppNotification>[
            AppNotification(
              id: 'n4',
              type: NotificationType.taskResponse,
              payload: const <String, dynamic>{
                'task_id': 't9',
                'titre': 'Réserver le restaurant',
                'reponse': 'declined',
                'auteur': 'Léa Marchand',
              },
              createdAt: _maintenant,
            ),
          ],
        ),
      );

      expect(find.text('Léa Marchand décline cette tâche.'), findsOneWidget);
    });

    testWidgets('une invitation à un événement ouvre l’écran d’invitation', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const NotificationsScreen(),
        events: FakeEventRepository(
          events: <CalendarEvent>[
            CalendarEvent(
              id: 'e7',
              title: 'Randonnée du lac Blanc',
              start: DateTime(2026, 8, 10, 9),
              end: DateTime(2026, 8, 10, 17),
              groupId: 'g1',
              authorName: 'Julie Martin',
            ),
          ],
        ),
        notifications: FakeNotificationRepository(
          notifications: <AppNotification>[
            AppNotification(
              id: 'n2',
              type: NotificationType.eventInvitation,
              payload: const <String, dynamic>{
                'event_id': 'e7',
                'titre': 'Randonnée du lac Blanc',
                'auteur': 'Julie Martin',
              },
              createdAt: _maintenant,
            ),
          ],
        ),
      );

      await tester.tap(find.text('Randonnée du lac Blanc').first);
      await tester.pumpAndSettle();
      expect(find.byType(EventInvitationScreen), findsOneWidget);
    });
  });
}
