import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/data_providers.dart';
import '../../calendar/models/calendar_event.dart';
import '../../calendar/providers/calendar_providers.dart';
import '../../groups/providers/group_providers.dart';
import '../../tasks/models/task.dart';
import '../../tasks/providers/task_providers.dart';
import '../widgets/week_overview.dart';

/// Chiffres affichés dans le bandeau de résumé de l'accueil.
class HomeSummary {
  const HomeSummary({
    required this.todayEventCount,
    required this.openTaskCount,
    required this.groupCount,
  });

  final int todayEventCount;
  final int openTaskCount;
  final int groupCount;

  bool get isEmpty =>
      todayEventCount == 0 && openTaskCount == 0 && groupCount == 0;
}

/// Agrège les features calendrier, tâches et groupes pour la page d'accueil.
///
/// L'accueil ne connaît ainsi aucun dépôt : il ne dépend que de ce provider et
/// des listes déjà filtrées par chaque feature.
final Provider<HomeSummary> homeSummaryProvider = Provider<HomeSummary>((
  Ref ref,
) {
  return HomeSummary(
    todayEventCount: ref.watch(todayEventsProvider).length,
    openTaskCount: ref.watch(openTasksProvider).length,
    groupCount: ref.watch(activeGroupsProvider).length,
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
