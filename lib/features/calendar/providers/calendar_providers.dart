import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/status_dot.dart';
import '../../../core/utils/date_formatting.dart';
import '../../../data/data_providers.dart';
import '../../../data/supabase_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../../availability/models/availability.dart';
import '../../availability/providers/availability_providers.dart';
import '../../groups/models/group.dart';
import '../../groups/providers/group_providers.dart';
import '../../notifications/providers/notification_providers.dart';
import '../../tasks/models/task.dart';
import '../../tasks/providers/task_providers.dart';
import '../models/agenda_entry.dart';
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

/// Filtre par groupe du calendrier.
///
/// **Une sélection vide signifie « tout »**, et non « rien » : c'est l'état
/// d'ouverture, et le calendrier personnel n'aurait aucun sens vide par
/// défaut. Ne rien cocher et tout cocher se ressemblent donc à l'écran, ce qui
/// est exactement l'effet voulu.
final NotifierProvider<CalendarGroupFilter, Set<String>>
calendarFilterProvider = NotifierProvider<CalendarGroupFilter, Set<String>>(
  CalendarGroupFilter.new,
);

class CalendarGroupFilter extends Notifier<Set<String>> {
  /// Clé du filtre « Personnel ». Les rendez-vous sans groupe n'ont pas
  /// d'identifiant de groupe à donner ; il leur en faut donc un, distinct de
  /// tout UUID.
  static const String personal = 'personnel';

  @override
  Set<String> build() => const <String>{};

  void toggle(String key) {
    final Set<String> suivant = Set<String>.of(state);
    if (!suivant.remove(key)) suivant.add(key);
    state = suivant;
  }

  void clear() => state = const <String>{};

  /// Vrai si [groupId] passe le filtre courant. `null` désigne le personnel.
  bool accepts(String? groupId) =>
      state.isEmpty || state.contains(groupId ?? personal);
}

/// Journée complète du jour donné : événements de groupe, rendez-vous
/// personnels, tâches datées et créneaux de disponibilité, dans l'ordre des
/// heures.
///
/// L'agrégation vit ici et non dans l'écran : c'est elle qui alimente aussi
/// les compteurs, et deux agrégations parallèles finiraient par diverger.
final dayAgendaProvider = Provider.family<List<AgendaEntry>, DateTime>((
  Ref ref,
  DateTime jour,
) {
  final CalendarGroupFilter filtre = ref.watch(calendarFilterProvider.notifier);
  ref.watch(calendarFilterProvider);

  final List<AgendaEntry> lignes = <AgendaEntry>[];

  for (final CalendarEvent event in ref.watch(eventsForDayProvider(jour))) {
    if (!filtre.accepts(event.groupId)) continue;
    final Group? groupe = event.groupId == null
        ? null
        : ref.watch(groupByIdProvider(event.groupId!));
    lignes.add(
      AgendaEntry(
        id: event.id,
        kind: event.isPersonal
            ? AgendaEntryKind.personalEvent
            : AgendaEntryKind.groupEvent,
        title: event.title,
        start: event.start,
        end: event.end,
        accent: groupe?.accent.color ?? AppColors.primary,
        subtitle: <String?>[
          groupe?.name ?? (event.isPersonal ? 'Personnel' : null),
          event.location,
        ].whereType<String>().join(' · '),
        timeLabel: AppDates.time(event.start),
        // Une réponse « oui » n'a pas besoin d'être signalée : c'est le cas
        // attendu.
        statusTone: event.myResponse == EventResponse.yes
            ? null
            : event.myResponse.tone,
        statusLabel: event.myResponse.label,
        groupId: event.groupId,
      ),
    );
  }

  for (final Task task in ref.watch(tasksProvider).value ?? const <Task>[]) {
    final DateTime? echeance = task.dueDate;
    if (echeance == null || !AppDates.isSameDay(echeance, jour)) continue;
    if (!filtre.accepts(task.groupId)) continue;
    final Group? groupe = task.groupId == null
        ? null
        : ref.watch(groupByIdProvider(task.groupId!));
    lignes.add(
      AgendaEntry(
        id: task.id,
        kind: AgendaEntryKind.task,
        title: task.title,
        start: echeance,
        end: echeance,
        accent: AppColors.success,
        subtitle: groupe?.name ?? 'Personnel',
        timeLabel: AppDates.time(echeance),
        statusTone: task.isDone ? null : _tonDePriorite(task.priority),
        statusLabel: task.isDone ? 'Terminée' : task.priority.label,
        groupId: task.groupId,
      ),
    );
  }

  // Les disponibilités ne dépendent d'aucun groupe : les masquer sous un
  // filtre de groupe reviendrait à faire disparaître le fond de la journée
  // dès qu'on regarde un groupe en particulier.
  for (final AvailabilitySlot creneau in ref.watch(slotsForDayProvider(jour))) {
    final DateTime debut = DateTime(
      jour.year,
      jour.month,
      jour.day,
    ).add(Duration(minutes: creneau.start));
    lignes.add(
      AgendaEntry(
        id: creneau.id,
        kind: AgendaEntryKind.availability,
        title: creneau.status.label,
        start: debut,
        end: debut.add(Duration(minutes: creneau.end - creneau.start)),
        accent: creneau.status == AvailabilityStatus.available
            ? AppColors.success
            : AppColors.danger,
        subtitle: creneau.plage,
        timeLabel: AvailabilitySlot.formaterHeure(creneau.start),
        statusTone: creneau.status.tone,
        statusLabel: creneau.status.label,
      ),
    );
  }

  lignes.sort((AgendaEntry a, AgendaEntry b) {
    final int heure = a.start.compareTo(b.start);
    if (heure != 0) return heure;
    // À heure égale, le fond de journée passe devant ce qui s'y pose.
    return a.kind.index.compareTo(b.kind.index);
  });
  return lignes;
});

/// `TaskPriority` ne porte pas de ton : il n'en a besoin qu'ici, et le lui
/// ajouter ferait dépendre le modèle du design system pour un seul écran.
StatusTone _tonDePriorite(TaskPriority priorite) => switch (priorite) {
  TaskPriority.high => StatusTone.danger,
  TaskPriority.medium => StatusTone.warning,
  TaskPriority.low => StatusTone.neutral,
};

/// Agenda du jour sélectionné.
final Provider<List<AgendaEntry>> agendaForSelectedDayProvider =
    Provider<List<AgendaEntry>>(
      (Ref ref) => ref.watch(dayAgendaProvider(ref.watch(selectedDayProvider))),
    );

/// Les quatre compteurs de l'en-tête du calendrier.
@immutable
class CalendarCounters {
  const CalendarCounters({
    required this.events,
    required this.tasks,
    required this.freeMinutes,
    required this.pendingInvitations,
  });

  final int events;
  final int tasks;

  /// Temps déclaré disponible sur la journée, en minutes.
  final int freeMinutes;

  /// Invitations en attente de réponse, toutes sources confondues : groupes,
  /// événements et tâches. C'est ce qui reste à traiter, pas ce qui concerne
  /// le seul jour affiché — une invitation ne se range pas dans une case
  /// horaire.
  final int pendingInvitations;

  /// « 4 h 30 », « 45 min », « — » : la durée se lit à l'unité qui compte.
  String get freeLabel {
    if (freeMinutes <= 0) return '—';
    final int heures = freeMinutes ~/ 60;
    final int minutes = freeMinutes % 60;
    if (heures == 0) return '$minutes min';
    if (minutes == 0) return '$heures h';
    return '$heures h ${minutes.toString().padLeft(2, '0')}';
  }
}

final calendarCountersProvider = Provider.family<CalendarCounters, DateTime>((
  Ref ref,
  DateTime jour,
) {
  final List<AgendaEntry> agenda = ref.watch(dayAgendaProvider(jour));
  return CalendarCounters(
    events: agenda
        .where(
          (AgendaEntry e) =>
              e.kind == AgendaEntryKind.groupEvent ||
              e.kind == AgendaEntryKind.personalEvent,
        )
        .length,
    tasks: agenda
        .where((AgendaEntry e) => e.kind == AgendaEntryKind.task)
        .length,
    freeMinutes: ref.watch(availableMinutesForDayProvider(jour)),
    pendingInvitations:
        (ref.watch(invitationsProvider).value ?? const <Object>[]).length +
        ref.watch(eventsAwaitingAnswerProvider).length +
        ref.watch(tasksAwaitingAnswerProvider).length,
  );
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
