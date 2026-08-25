import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/data_providers.dart';
import '../../calendar/models/agenda_entry.dart';
import '../../calendar/models/calendar_event.dart';
import '../../calendar/providers/calendar_providers.dart';
import '../../tasks/models/task.dart';
import '../../tasks/providers/task_providers.dart';
import '../widgets/tasks_card.dart';
import '../widgets/week_overview.dart';

/// La journée en cours pour la carte « Mon agenda » : **les événements
/// seuls**.
///
/// `dayAgendaProvider` mêle aussi les tâches datées et les créneaux de
/// disponibilité, ce qui a du sens au calendrier — une journée s'y lit d'un
/// bloc. Sur l'accueil, non : les tâches ont leur propre carte juste dessous,
/// et une tâche affichée aux deux endroits se lit deux fois. Les créneaux, eux,
/// décrivent le fond de la journée et n'ont pas leur place dans un résumé.
final Provider<List<AgendaEntry>> todayAgendaProvider =
    Provider<List<AgendaEntry>>((Ref ref) {
      return ref
          .watch(dayAgendaProvider(ref.watch(nowProvider)))
          .where(
            (AgendaEntry e) =>
                e.kind == AgendaEntryKind.groupEvent ||
                e.kind == AgendaEntryKind.personalEvent,
          )
          .toList();
    });

/// Les trois chiffres de la carte « Mes tâches ».
///
/// L'agrégation vit ici, pas dans le widget : la liste affichée dessous vient
/// de la même source, et deux comptages parallèles finiraient par afficher un
/// nombre que la liste contredit.
final Provider<TaskCounts> taskCountsProvider = Provider<TaskCounts>((Ref ref) {
  final DateTime now = ref.watch(nowProvider);
  final DateTime lundi = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: now.weekday - 1));

  final List<Task> ouvertes = ref.watch(openTasksProvider);
  final List<Task> toutes = ref.watch(tasksProvider).value ?? const <Task>[];

  return TaskCounts(
    open: ouvertes.length,
    doneThisWeek: toutes
        .where(
          (Task t) => t.completedAt != null && !t.completedAt!.isBefore(lundi),
        )
        .length,
    // « En retard » se lit sur l'échéance, jamais sur un état stocké :
    // `completed_at` reste la seule source du statut d'une tâche.
    overdue: ouvertes
        .where((Task t) => t.dueDate != null && t.dueDate!.isBefore(now))
        .length,
  );
});

/// Salutation dépendant de l'heure : « Bonjour » / « Bon après-midi » / « Bonsoir ».
final Provider<String> greetingProvider = Provider<String>((Ref ref) {
  final int hour = ref.watch(nowProvider).hour;
  if (hour < 12) return 'Bonjour';
  if (hour < 18) return 'Bon après-midi';
  return 'Bonsoir';
});

/// Les sept jours de la semaine en cours, avec ce que chacun porte.
///
/// La semaine commence le **lundi** : `DateTime.weekday` vaut 1 le lundi, d'où
/// le retrait de `weekday - 1` jours pour trouver le début.
final Provider<List<DaySummary>> currentWeekProvider =
    Provider<List<DaySummary>>((Ref ref) {
      final DateTime now = ref.watch(nowProvider);
      final DateTime lundi = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1));

      final List<CalendarEvent> evenements =
          ref.watch(eventsProvider).value ?? const <CalendarEvent>[];
      final List<Task> taches = ref.watch(openTasksProvider);

      return <DaySummary>[
        for (int i = 0; i < 7; i++)
          () {
            final DateTime jour = lundi.add(Duration(days: i));
            return DaySummary(
              day: jour,
              eventCount: evenements
                  .where((CalendarEvent e) => e.occursOn(jour))
                  .length,
              taskCount: taches
                  .where(
                    (Task t) =>
                        t.dueDate != null &&
                        t.dueDate!.year == jour.year &&
                        t.dueDate!.month == jour.month &&
                        t.dueDate!.day == jour.day,
                  )
                  .length,
            );
          }(),
      ];
    });
