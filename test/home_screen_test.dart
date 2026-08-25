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
import 'package:jelvo/features/groups/models/group.dart';
import 'package:jelvo/features/groups/models/group_member.dart';
import 'package:jelvo/features/groups/providers/group_providers.dart';
import 'package:jelvo/features/home/widgets/agenda_card.dart';
import 'package:jelvo/features/home/widgets/group_strip.dart';
import 'package:jelvo/features/home/widgets/tasks_card.dart';
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

/// Lundi 3 août 2026, 9 h — même horloge figée que les autres tests.
final DateTime _testNow = DateTime(2026, 8, 3, 9);

Future<void> _pumpApp(
  WidgetTester tester, {
  FakeGroupRepository? groupRepository,
  FakeTaskRepository? taskRepository,
  FakeEventRepository? eventRepository,
}) async {
  tester.view.physicalSize = const Size(420, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final FakeAuthRepository auth = FakeAuthRepository(signedIn: true);
  addTearDown(auth.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(FixedClock(_testNow)),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        groupRepositoryProvider.overrideWithValue(
          groupRepository ?? FakeGroupRepository(),
        ),
        taskRepositoryProvider.overrideWithValue(
          taskRepository ?? FakeTaskRepository(),
        ),
        eventRepositoryProvider.overrideWithValue(
          eventRepository ?? FakeEventRepository(),
        ),
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
}

void main() {
  setUpAll(() => initializeDateFormatting(AppDates.locale));

  group('En-tête', () {
    testWidgets('la salutation porte le prénom, et la date suit dessous', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);

      expect(find.text('Bonjour Camille'), findsOneWidget);
      // Sans l'année : sous une salutation, elle n'apprend rien.
      expect(find.text('Lundi 3 août'), findsOneWidget);
      expect(find.textContaining('2026'), findsNothing);
    });

    testWidgets('la photo de profil ouvre le profil', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);

      await tester.tap(find.byTooltip('Profil'));
      await tester.pumpAndSettle();

      expect(find.text('Camille Rousseau'), findsOneWidget);
    });

    testWidgets('le bouton calendrier de l’en-tête ouvre le calendrier', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);

      await tester.tap(find.byTooltip('Calendrier').first);
      await tester.pumpAndSettle();

      expect(find.text('Événements'), findsWidgets);
    });
  });

  group('Bande des groupes', () {
    testWidgets('chaque carte porte le nom et le nombre de membres', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);

      // Bornée à la bande : le nom d'un groupe se lit aussi en sous-titre
      // d'une ligne d'agenda, juste dessous.
      Finder dansLaBande(String texte) => find.descendant(
        of: find.byType(GroupStrip),
        matching: find.text(texte),
      );
      expect(dansLaBande('Famille Rousseau'), findsOneWidget);
      expect(dansLaBande('3 membres'), findsOneWidget);
      expect(dansLaBande('Vacances en Corse'), findsOneWidget);
      expect(dansLaBande('4 membres'), findsOneWidget);
    });

    testWidgets('sans photo de couverture, l’initiale prend la place', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);

      // « Famille Rousseau » et « Vacances en Corse » n'ont pas de photo :
      // le repli affiche leur initiale sur l'accent dérivé de l'identifiant.
      // Aucune icône de catégorie n'est inventée — `groups` n'en porte pas.
      //
      // La recherche est bornée à la bande : « V » est aussi l'initiale de
      // vendredi dans la semaine d'accueil, juste au-dessus.
      Finder dansLaBande(String texte) => find.descendant(
        of: find.byType(GroupStrip),
        matching: find.text(texte),
      );
      expect(dansLaBande('F'), findsOneWidget);
      expect(dansLaBande('V'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('avec une photo, la carte demande bien l’image', (
      WidgetTester tester,
    ) async {
      await _pumpApp(
        tester,
        groupRepository: FakeGroupRepository(
          groups: const <Group>[
            Group(
              id: 'g1',
              name: 'Famille Rousseau',
              memberCount: 3,
              myRole: GroupRole.admin,
              photoUrl: 'https://exemple.test/couverture.jpg',
            ),
          ],
        ),
      );

      // Le chargement échoue dans le harnais de test — il n'y a pas de
      // réseau —, mais le widget `Image` est bien demandé, et l'initiale
      // reste affichée en attendant.
      expect(find.byType(Image), findsOneWidget);
      expect(
        find.descendant(of: find.byType(GroupStrip), matching: find.text('F')),
        findsOneWidget,
      );
    });

    testWidgets('sans aucun groupe, l’état vide propose d’en créer un', (
      WidgetTester tester,
    ) async {
      await _pumpApp(
        tester,
        groupRepository: FakeGroupRepository(groups: const <Group>[]),
      );

      expect(find.text('Aucun groupe pour le moment'), findsOneWidget);
      expect(find.text('Créer un groupe'), findsWidgets);
      // Rien à voir : l'action « Voir tout » disparaît plutôt que de mener à
      // une liste vide.
      expect(find.text('Voir tout'), findsNothing);
    });
  });

  group('Carte « Mon agenda »', () {
    testWidgets('l’événement du jour s’affiche avec sa plage horaire', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);

      expect(find.text('Mon agenda'), findsOneWidget);
      expect(find.text('Brunch chez les parents'), findsOneWidget);
      expect(find.text('09:30 – 11:30'), findsOneWidget);
    });

    testWidgets('une tâche de la chronologie n’est pas répétée en bas', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);

      // La répétition entre les deux cartes est assumée dans son principe —
      // les compteurs continuent de la compter —, mais la **ligne** en double
      // à quelques centimètres de la première ne l'est pas.
      expect(find.text('Réserver le restaurant pour samedi'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TasksCard),
          matching: find.text('Réserver le restaurant pour samedi'),
        ),
        findsNothing,
      );
    });

    testWidgets('une journée sans rien annonce une journée libre', (
      WidgetTester tester,
    ) async {
      // Sans événement **ni** tâche datée : la chronologie montre les deux,
      // et il suffit d'une tâche du jour pour qu'elle ne soit pas vide.
      await _pumpApp(
        tester,
        eventRepository: FakeEventRepository(events: []),
        taskRepository: FakeTaskRepository(tasks: []),
      );

      expect(find.text('Journée libre'), findsOneWidget);
      // Le pied « voir tout » ne s'affiche pas : il n'y a rien de plus.
      expect(find.textContaining('Voir tout mon agenda'), findsNothing);
    });

    testWidgets('la chronologie mêle événements et tâches du jour', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);

      // C'est le but de la carte : voir sa journée d'un coup d'œil, sans
      // distinguer ce qui arrive de ce qu'on a à faire.
      final Finder carte = find.byType(AgendaCard);
      expect(
        find.descendant(
          of: carte,
          matching: find.text('Brunch chez les parents'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: carte,
          matching: find.text('Réserver le restaurant pour samedi'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('les créneaux de disponibilité restent dehors', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);

      // Ils décrivent ce qui se peut, pas ce qui arrive, et rempliraient une
      // carte qui doit tenir en trois lignes. Ils restent au calendrier.
      expect(
        find.descendant(
          of: find.byType(AgendaCard),
          matching: find.textContaining('Disponible'),
        ),
        findsNothing,
      );
    });
  });

  group('Carte « Mes tâches »', () {
    testWidgets('les trois compteurs sont en tête', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);

      expect(find.text('Mes tâches'), findsOneWidget);
      expect(find.text('À faire'), findsOneWidget);
      expect(find.textContaining('Terminées'), findsOneWidget);
      expect(find.textContaining('En retard'), findsWidgets);
    });

    testWidgets('sans tâche à traiter, la carte le dit sans mentir', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester, taskRepository: FakeTaskRepository(tasks: []));

      expect(find.text('Tout est à jour'), findsOneWidget);
      // Les compteurs restent, à zéro : les masquer donnerait à croire que la
      // carte est en cours de chargement.
      expect(find.text('À faire'), findsOneWidget);
      expect(find.text('0 tâches'), findsOneWidget);
    });
  });

  group('Membres', () {
    testWidgets('la bande n’invente aucun membre', (WidgetTester tester) async {
      // Garde-fou : `memberCount` vient de la base, et un groupe à zéro
      // membre actif doit l'afficher plutôt qu'un nombre de repli.
      await _pumpApp(
        tester,
        groupRepository: FakeGroupRepository(
          groups: const <Group>[Group(id: 'g9', name: 'Zéro', memberCount: 0)],
          members: const <GroupMember>[],
        ),
      );

      expect(find.text('0 membre'), findsOneWidget);
    });
  });
}
