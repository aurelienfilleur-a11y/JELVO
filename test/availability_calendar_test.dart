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
import 'package:jelvo/features/availability/models/availability.dart';
import 'package:jelvo/features/calendar/models/calendar_event.dart';
import 'package:jelvo/features/tasks/models/task.dart';
import 'package:jelvo/features/calendar/widgets/calendar_header.dart';
import 'package:jelvo/features/calendar/widgets/week_strip.dart';
import 'package:jelvo/features/calendar/widgets/calendar_sheets.dart';
import 'package:jelvo/features/chat/providers/chat_providers.dart';
import 'package:jelvo/features/contacts/providers/contact_providers.dart';
import 'package:jelvo/features/groups/providers/group_providers.dart';
import 'package:jelvo/features/home/widgets/week_overview.dart';
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

/// Lundi 3 août 2026 : le jour du créneau récurrent du faux dépôt, et celui
/// des données de démonstration de l'agenda et des tâches.
final DateTime _testNow = DateTime(2026, 8, 3, 9);

Future<FakeAvailabilityRepository> _pumpApp(
  WidgetTester tester, {
  FakeAvailabilityRepository? availability,
  FakeEventRepository? events,
  FakeTaskRepository? tasks,
}) async {
  tester.view.physicalSize = const Size(420, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final FakeAuthRepository auth = FakeAuthRepository(signedIn: true);
  addTearDown(auth.dispose);
  final FakeAvailabilityRepository dispos =
      availability ?? FakeAvailabilityRepository();

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
        chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
        pushServiceProvider.overrideWithValue(FakePushService()),
        pushRepositoryProvider.overrideWithValue(FakePushRepository()),
        availabilityRepositoryProvider.overrideWithValue(dispos),
        notificationRepositoryProvider.overrideWithValue(
          FakeNotificationRepository(),
        ),
      ],
      child: const JelvoApp(),
    ),
  );
  await tester.pumpAndSettle();
  return dispos;
}

Future<void> _ouvrirCalendrier(WidgetTester tester) async {
  await tester.tap(find.text('Calendrier').last);
  await tester.pumpAndSettle();
}

Future<void> _ouvrirDisponibilites(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Profil'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Mes disponibilités'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting(AppDates.locale));

  group('Semaine sur l’accueil', () {
    testWidgets('les sept jours sont visibles avec le jour courant', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);

      expect(find.byType(WeekOverview), findsOneWidget);

      final WeekOverview semaine = tester.widget<WeekOverview>(
        find.byType(WeekOverview),
      );
      expect(semaine.days.length, 7);
      // La semaine commence le lundi : le 3 août 2026 en est un.
      expect(semaine.days.first.day.day, 3);
      expect(semaine.days.last.day.day, 9);

      // Le brunch du 3 et la randonnée du 5 doivent piquer leurs colonnes.
      expect(semaine.days[0].eventCount, 1);
      expect(semaine.days[2].eventCount, 1);
      // La tâche du 3 août aussi, et sur son propre marqueur.
      expect(semaine.days[0].taskCount, 1);
    });

    testWidgets('taper un jour ouvre le calendrier à cette date', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);

      // Le mercredi 5 août porte la randonnée : c'est ce qu'on doit voir
      // après le geste, alors que l'accueil affichait le 3.
      await tester.tap(
        find.descendant(
          of: find.byType(WeekOverview),
          matching: find.text('5'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Randonnée du lac Blanc'), findsOneWidget);
      expect(find.text('Brunch chez les parents'), findsNothing);
    });
  });

  group('Calendrier personnel', () {
    testWidgets('les quatre compteurs sont en tête', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await _ouvrirCalendrier(tester);

      expect(find.text('Événements'), findsOneWidget);
      expect(find.text('Tâches'), findsOneWidget);
      expect(find.text('Invitations'), findsOneWidget);
      // « Disponible » titre aussi les créneaux verts de la chronologie : on
      // vise le compteur, pas le bloc.
      expect(
        find.descendant(
          of: find.byType(CalendarCountersRow),
          matching: find.text('Disponible'),
        ),
        findsOneWidget,
      );

      // Trois heures déclarées disponibles le lundi, dans le faux dépôt.
      expect(find.text('3 h'), findsOneWidget);
    });

    testWidgets('la journée agrège événement, tâche et créneau', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await _ouvrirCalendrier(tester);

      expect(find.text('Brunch chez les parents'), findsOneWidget);
      expect(find.text('Réserver le restaurant pour samedi'), findsOneWidget);
      // Le créneau se lit sur une seule ligne, sans jamais nommer de raison.
      expect(find.textContaining('09:00 – 12:00'), findsOneWidget);
    });

    testWidgets('le filtre par groupe restreint la journée', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await _ouvrirCalendrier(tester);

      // Le filtre vit désormais derrière l'icône de l'en-tête. Le brunch et
      // la tâche appartiennent au groupe g1 : filtrer sur « Personnel » doit
      // les faire disparaître.
      await tester.tap(find.byTooltip('Filtres'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Personnel'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(CalendarFilterSheet))).pop();
      await tester.pumpAndSettle();

      expect(find.text('Brunch chez les parents'), findsNothing);
      expect(find.text('Réserver le restaurant pour samedi'), findsNothing);
      // Le créneau, lui, reste : il ne dépend d'aucun groupe, et le masquer
      // ferait disparaître le fond de la journée.
      expect(find.textContaining('09:00 – 12:00'), findsOneWidget);

      // « Tout voir » remet la journée entière.
      await tester.tap(find.byTooltip('Filtres'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tout voir'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(CalendarFilterSheet))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Brunch chez les parents'), findsOneWidget);
    });

    testWidgets('taper un événement de la timeline ouvre son détail', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await _ouvrirCalendrier(tester);

      await tester.tap(find.text('Brunch chez les parents'));
      await tester.pumpAndSettle();

      expect(find.text('Chez Papi et Mamie'), findsOneWidget);
    });
  });

  group('Disponibilités', () {
    testWidgets('l’écran s’ouvre depuis le profil et dit la règle', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await _ouvrirDisponibilites(tester);

      expect(find.text('Ma semaine type'), findsOneWidget);
      expect(find.text('Exceptions'), findsOneWidget);
      expect(
        find.textContaining('« Disponible », « Indisponible » ou « Inconnu »'),
        findsOneWidget,
      );
      // Le créneau récurrent du lundi et l'exception du 4 août.
      expect(find.text('Lundi'), findsOneWidget);
      expect(find.text('09:00 – 12:00'), findsOneWidget);
    });

    testWidgets('supprimer un créneau appelle le dépôt', (
      WidgetTester tester,
    ) async {
      final FakeAvailabilityRepository dispos = await _pumpApp(tester);
      await _ouvrirDisponibilites(tester);

      await tester.tap(find.byTooltip('Supprimer le créneau').first);
      await tester.pumpAndSettle();

      expect(dispos.lastRemovedId, 'd1');
      expect(find.text('Créneau supprimé.'), findsOneWidget);
      expect(find.text('09:00 – 12:00'), findsNothing);
    });

    testWidgets('le formulaire propose récurrent ou date précise', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await _ouvrirDisponibilites(tester);

      await tester.tap(find.byTooltip('Nouveau créneau'));
      await tester.pumpAndSettle();

      expect(find.text('Nouveau créneau'), findsWidgets);
      expect(find.text('Chaque semaine'), findsOneWidget);
      expect(find.text('Une date précise'), findsOneWidget);
      // Les mêmes mots titrent aussi les créneaux déjà posés derrière la
      // feuille : c'est bien le même vocabulaire, à la saisie comme à la
      // lecture.
      expect(find.text('Disponible'), findsWidgets);
      expect(find.text('Indisponible'), findsWidgets);
    });
  });

  group('Le calendrier refondu', () {
    testWidgets('l’en-tête porte la photo, la recherche, les filtres et le +', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await _ouvrirCalendrier(tester);

      expect(find.byTooltip('Profil'), findsWidgets);
      expect(find.byTooltip('Rechercher'), findsOneWidget);
      expect(find.byTooltip('Filtres'), findsOneWidget);
      expect(find.byTooltip('Créer'), findsOneWidget);
    });

    testWidgets('la ligne du jour nomme la date, et le retour n’apparaît que '
        'si l’on s’en est éloigné', (WidgetTester tester) async {
      await _pumpApp(tester);
      await _ouvrirCalendrier(tester);

      // Sur la journée du jour, un bouton « Aujourd'hui » n'aurait rien à
      // faire : il n'est donc pas là.
      expect(find.text("Aujourd'hui"), findsNothing);

      await tester.tap(find.byTooltip('Semaine suivante'));
      await tester.pumpAndSettle();
      expect(find.text("Aujourd'hui"), findsOneWidget);

      await tester.tap(find.text("Aujourd'hui"));
      await tester.pumpAndSettle();
      expect(find.text("Aujourd'hui"), findsNothing);
    });

    testWidgets('les pastilles sous les dates disent ce qui s’y passe', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await _ouvrirCalendrier(tester);

      final WeekStrip bande = tester.widget<WeekStrip>(find.byType(WeekStrip));
      // Le 3 août porte un événement et une tâche dans les faux dépôts.
      final Set<DayMarker> lundi =
          bande.markersByDay[DateTime(2026, 8, 3)] ?? <DayMarker>{};
      expect(lundi, contains(DayMarker.evenement));
      expect(lundi, contains(DayMarker.tache));
    });

    testWidgets('la recherche trouve un événement et ouvre sa date', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await _ouvrirCalendrier(tester);

      await tester.tap(find.byTooltip('Rechercher'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'brunch');
      await tester.pumpAndSettle();

      expect(find.text('Brunch chez les parents'), findsWidgets);
      await tester.tap(find.text('Brunch chez les parents').last);
      await tester.pumpAndSettle();

      // La feuille s'est refermée sur le calendrier, à la bonne date.
      expect(find.byType(CalendarSearchSheet), findsNothing);
      expect(find.text('Brunch chez les parents'), findsOneWidget);
    });

    testWidgets('les créneaux se masquent depuis les filtres', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);
      await _ouvrirCalendrier(tester);

      expect(find.textContaining('09:00 – 12:00'), findsOneWidget);

      await tester.tap(find.byTooltip('Filtres'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(CalendarFilterSheet))).pop();
      await tester.pumpAndSettle();

      expect(find.textContaining('09:00 – 12:00'), findsNothing);
      // Le reste de la journée est intact : le réglage ne touche que le fond.
      expect(find.text('Brunch chez les parents'), findsOneWidget);
    });

    testWidgets('une journée vide le dit, et propose de la remplir', (
      WidgetTester tester,
    ) async {
      // Sans créneau récurrent, sans événement et sans tâche, la journée n'a
      // rien à montrer — et ce n'est pas un filtre qui la vide.
      await _pumpApp(
        tester,
        availability: FakeAvailabilityRepository(
          slots: const <AvailabilitySlot>[],
        ),
        events: FakeEventRepository(events: <CalendarEvent>[]),
        tasks: FakeTaskRepository(tasks: <Task>[]),
      );
      await _ouvrirCalendrier(tester);

      expect(find.text('Journée libre'), findsOneWidget);
      expect(find.text('Créer un événement'), findsOneWidget);
    });
  });
}
