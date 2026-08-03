import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_formatting.dart';
import '../../../data/data_providers.dart';
import '../models/calendar_event.dart';
import '../repository/event_repository.dart';

final Provider<EventRepository> eventRepositoryProvider =
    Provider<EventRepository>(
      (Ref ref) => InMemoryEventRepository(anchor: ref.watch(nowProvider)),
    );

/// Tous les événements, triés par date de début.
final StreamProvider<List<CalendarEvent>> eventsProvider =
    StreamProvider<List<CalendarEvent>>(
      (Ref ref) => ref.watch(eventRepositoryProvider).watchEvents(),
    );

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
final eventsForDayProvider = Provider.family<List<CalendarEvent>, DateTime>((
  Ref ref,
  DateTime day,
) {
  final List<CalendarEvent> events =
      ref.watch(eventsProvider).value ?? const <CalendarEvent>[];
  return events.where((CalendarEvent e) => e.occursOn(day)).toList();
});

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
      final List<CalendarEvent> events =
          ref.watch(eventsProvider).value ?? const <CalendarEvent>[];

      return events.where((CalendarEvent e) {
        final int days = AppDates.dayDifference(e.start, now);
        return days > 0 && days <= 7;
      }).toList();
    });

/// Nombre d'événements par jour sur la période affichée, pour piquer les
/// pastilles sous les dates de la bande hebdomadaire.
final Provider<Map<DateTime, int>> eventCountByDayProvider =
    Provider<Map<DateTime, int>>((Ref ref) {
      final List<CalendarEvent> events =
          ref.watch(eventsProvider).value ?? const <CalendarEvent>[];
      final Map<DateTime, int> counts = <DateTime, int>{};

      for (final CalendarEvent event in events) {
        final DateTime key = DateTime(
          event.start.year,
          event.start.month,
          event.start.day,
        );
        counts[key] = (counts[key] ?? 0) + 1;
      }
      return counts;
    });
