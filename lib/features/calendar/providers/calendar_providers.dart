import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_formatting.dart';
import '../../../data/data_providers.dart';
import '../../../data/supabase_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../../notifications/providers/notification_providers.dart';
import '../models/calendar_event.dart';
import '../repository/event_repository.dart';

/// Dépôt de l'agenda. Surchargé dans les tests par un faux dépôt.
final Provider<EventRepository> eventRepositoryProvider =
    Provider<EventRepository>(
      (Ref ref) => SupabaseEventRepository(ref.watch(supabaseClientProvider)),
    );

/// Tous les événements visibles, triés par date de début.
final AsyncNotifierProvider<EventsNotifier, List<CalendarEvent>>
eventsProvider = AsyncNotifierProvider<EventsNotifier, List<CalendarEvent>>(
  EventsNotifier.new,
);

class EventsNotifier extends AsyncNotifier<List<CalendarEvent>> {
  @override
  Future<List<CalendarEvent>> build() {
    ref.watch(authStatusProvider);
    return ref.watch(eventRepositoryProvider).fetchEvents();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(eventRepositoryProvider).fetchEvents(),
    );
  }
}

List<CalendarEvent> _all(Ref ref) =>
    ref.watch(eventsProvider).value ?? const <CalendarEvent>[];

/// Jour sélectionné dans l'écran Calendrier.
final NotifierProvider<SelectedDay, DateTime> selectedDayProvider =
    NotifierProvider<SelectedDay, DateTime>(SelectedDay.new);

class SelectedDay extends Notifier<DateTime> {
  @override
  DateTime build() {
    final DateTime now = ref.watch(nowProvider);
    return DateTime(now.year, now.month, now.day);
  }

  void select(DateTime day) => state = DateTime(day.year, day.month, day.day);

  void shiftDays(int days) => state = state.add(Duration(days: days));
}

/// Événements d'un jour donné, ordonnés par heure de début.
// Riverpod 3 n'exporte pas les types `*Family` : on laisse l'inférence faire.
final eventsForDayProvider = Provider.family<List<CalendarEvent>, DateTime>(
  (Ref ref, DateTime day) =>
      _all(ref).where((CalendarEvent e) => e.occursOn(day)).toList(),
);

/// Événements du jour sélectionné.
final Provider<List<CalendarEvent>> eventsForSelectedDayProvider =
    Provider<List<CalendarEvent>>(
      (Ref ref) =>
          ref.watch(eventsForDayProvider(ref.watch(selectedDayProvider))),
    );

/// Agenda du jour courant, pour la page d'accueil.
final Provider<List<CalendarEvent>> todayEventsProvider =
    Provider<List<CalendarEvent>>(
      (Ref ref) => ref.watch(eventsForDayProvider(ref.watch(nowProvider))),
    );

/// Prochains événements après aujourd'hui, limités à sept jours.
final Provider<List<CalendarEvent>> upcomingEventsProvider =
    Provider<List<CalendarEvent>>((Ref ref) {
      final DateTime now = ref.watch(nowProvider);
      return _all(ref).where((CalendarEvent e) {
        final int days = AppDates.dayDifference(e.start, now);
        return days > 0 && days <= 7;
      }).toList();
    });

/// Événements d'un groupe donné, à venir en premier.
final eventsForGroupProvider = Provider.family<List<CalendarEvent>, String>(
  (Ref ref, String groupId) =>
      _all(ref).where((CalendarEvent e) => e.groupId == groupId).toList(),
);

/// Événements attendant une réponse de l'utilisateur.
final Provider<List<CalendarEvent>> eventsAwaitingAnswerProvider =
    Provider<List<CalendarEvent>>((Ref ref) {
      final DateTime now = ref.watch(nowProvider);
      return _all(ref)
          .where(
            (CalendarEvent e) =>
                !e.isPersonal &&
                e.myResponse == EventResponse.pending &&
                e.start.isAfter(now),
          )
          .toList();
    });

/// Nombre d'événements par jour sur la période affichée, pour piquer les
/// pastilles sous les dates de la bande hebdomadaire.
final Provider<Map<DateTime, int>> eventCountByDayProvider =
    Provider<Map<DateTime, int>>((Ref ref) {
      final Map<DateTime, int> counts = <DateTime, int>{};
      for (final CalendarEvent event in _all(ref)) {
        final DateTime key = DateTime(
          event.start.year,
          event.start.month,
          event.start.day,
        );
        counts[key] = (counts[key] ?? 0) + 1;
      }
      return counts;
    });

/// Un événement par son identifiant, `null` s'il n'est plus visible.
///
/// L'écran de détail s'y branche plutôt que de recevoir l'événement en
/// argument : après une réponse ou une modification, il se met à jour seul.
final eventByIdProvider = Provider.family<CalendarEvent?, String>((
  Ref ref,
  String id,
) {
  for (final CalendarEvent event in _all(ref)) {
    if (event.id == id) return event;
  }
  return null;
});

/// Écritures sur l'agenda.
final Provider<EventActions> eventActionsProvider = Provider<EventActions>(
  EventActions.new,
);

class EventActions {
  const EventActions(this._ref);

  final Ref _ref;

  EventRepository get _repository => _ref.read(eventRepositoryProvider);

  Future<CalendarEvent> create({
    required String title,
    required DateTime startsAt,
    DateTime? endsAt,
    String? groupId,
    String? description,
    String? location,
    String? rrule,
    String? imageUrl,
    int? reminderMinutes,
    List<String>? participants,
  }) async {
    final CalendarEvent event = await _repository.createEvent(
      title: title,
      startsAt: startsAt,
      endsAt: endsAt,
      groupId: groupId,
      description: description,
      location: location,
      rrule: rrule,
      imageUrl: imageUrl,
      reminderMinutes: reminderMinutes,
      participants: participants,
    );
    await _refresh();
    return event;
  }

  Future<CalendarEvent> update({
    required String eventId,
    required String title,
    required DateTime startsAt,
    DateTime? endsAt,
    String? description,
    String? location,
    String? rrule,
    String? imageUrl,
    int? reminderMinutes,
  }) async {
    final CalendarEvent event = await _repository.updateEvent(
      eventId: eventId,
      title: title,
      startsAt: startsAt,
      endsAt: endsAt,
      description: description,
      location: location,
      rrule: rrule,
      imageUrl: imageUrl,
      reminderMinutes: reminderMinutes,
    );
    await _refresh();
    return event;
  }

  Future<void> respond(String eventId, EventResponse response) async {
    await _repository.respond(eventId: eventId, response: response);
    await _refresh();

    // Répondre referme la notification d'invitation, côté base, par
    // `clore_notification_evenement`. Sans cette relecture, la ligne resterait
    // à l'écran et la pastille allumée : la boîte est relue à la demande, pas
    // poussée. Un compteur doit refléter ce qui reste à faire.
    await _ref.read(notificationsProvider.notifier).refresh();
  }

  Future<void> remove(String eventId) async {
    await _repository.deleteEvent(eventId);
    await _refresh();
  }

  Future<void> _refresh() => _ref.read(eventsProvider.notifier).refresh();
}
