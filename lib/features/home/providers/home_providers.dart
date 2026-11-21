import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/data_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../calendar/models/agenda_entry.dart';
import '../../calendar/models/calendar_event.dart';
import '../../calendar/providers/calendar_providers.dart';
import '../../tasks/models/task.dart';
import '../../tasks/providers/task_providers.dart';
import '../widgets/tasks_card.dart';
import '../widgets/week_overview.dart';

/// La journée en cours pour la carte « Mon agenda » : événements **et** tâches
/// datées, mêlés dans l'ordre des heures.
///
/// C'est le but premier de la carte — voir sa journée d'un coup d'œil —, et
/// une chronologie qui tairait les tâches ne la montrerait qu'à moitié. La
/// même liste alimente le calendrier, où la journée se lit déjà d'un bloc.
///
/// **Les créneaux de disponibilité en restent écartés** : ils ne décrivent pas
/// ce qui arrive mais ce qui se peut, et ils occuperaient la moitié d'une
/// carte qui doit tenir en trois lignes.
/// La langue entre dans la clé, comme pour `dayAgendaProvider` : ces lignes
/// portent des phrases, et un provider n'a pas de contexte d'où les tirer.
final todayAgendaProvider = Provider.family<List<AgendaEntry>, AppTexts>((
  Ref ref,
  AppTexts t,
) {
  return ref
      .watch(dayAgendaProvider((ref.watch(nowProvider), t)))
      .where((AgendaEntry e) => e.kind != AgendaEntryKind.availability)
      .toList();
});

/// Les tâches à lister **sous** les compteurs, une fois retirées celles que la
/// chronologie montre déjà.
///
/// La répétition entre les deux cartes est assumée dans son principe : les
/// compteurs ne bougent pas, et « en retard » continue de compter une tâche
/// affichée plus haut. Ce qui est retiré, c'est seulement la **ligne** en
/// double, à quelques centimètres de la première.
///
/// Le filtre passe par l'identifiant, et non par le titre : deux tâches
/// peuvent porter le même nom dans deux groupes différents.
final homeTaskRowsProvider = Provider.family<List<Task>, AppTexts>((
  Ref ref,
  AppTexts t,
) {
  final Set<String> dejaDansLAgenda = ref
      .watch(todayAgendaProvider(t))
      .where((AgendaEntry e) => e.kind == AgendaEntryKind.task)
      .map((AgendaEntry e) => e.id)
      .toSet();

  return ref
      .watch(focusTasksProvider)
      .where((Task tache) => !dejaDansLAgenda.contains(tache.id))
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

/// Moment de la journée, dont dépend la salutation.
///
/// **Le provider dit l'heure qu'il est, pas le mot qui va avec.** C'est la
/// même règle que pour les couleurs : « Bonsoir » n'est juste qu'en français,
/// et un provider n'a pas de contexte d'où tirer la langue.
enum MomentDuJour {
  matin,
  apresMidi,
  soir,

  /// Le samedi et le dimanche, à toute heure sauf le soir.
  ///
  /// **Le week-end est le seul repère de calendrier que Jelvo souhaite**, et
  /// c'est délibéré. Une fête nationale dépend du *pays* et non de la langue
  /// — l'espagnol couvre vingt pays, l'allemand trois, l'anglais aucun en
  /// particulier —, et Jelvo ne sait pas où vous êtes : ni localisation, ni
  /// numéro, et `profiles.timezone` que personne ne lit. Déduire le pays de
  /// la langue serait la devinette qu'on écarte partout ailleurs. Samedi et
  /// dimanche, eux, sont les mêmes dans les quatre langues.
  weekEnd;

  String salutation(AppTexts t) => switch (this) {
    MomentDuJour.matin => t.homeBonjour,
    MomentDuJour.apresMidi => t.homeBonApresMidi,
    MomentDuJour.soir => t.homeBonsoir,
    MomentDuJour.weekEnd => t.homeBonWeekEnd,
  };
}

/// Le moment de la journée, dont dépend la salutation.
///
/// **Les bornes horaires sont une donnée de langue, pas une constante.** En
/// espagnol, *buenas tardes* commence après le déjeuner — vers 14 h —, et
/// servir « buenas tardes » à midi est quelque chose qu'aucun hispanophone
/// n'écrit. Les deux bornes vivent donc dans l'ARB, au même titre qu'un
/// format de date, et c'est la seule raison pour laquelle ce provider prend
/// la langue.
///
/// **Le soir l'emporte sur le week-end** : « Bon week-end » à 23 h un samedi
/// serait étrange, alors que « Bonsoir » est juste tous les jours.
final greetingProvider = Provider.family<MomentDuJour, AppTexts>((
  Ref ref,
  AppTexts t,
) {
  final DateTime maintenant = ref.watch(nowProvider);
  final int heure = maintenant.hour;
  final int debutSoiree = int.parse(t.coreDebutSoiree);
  if (heure >= debutSoiree) return MomentDuJour.soir;
  if (maintenant.weekday == DateTime.saturday ||
      maintenant.weekday == DateTime.sunday) {
    return MomentDuJour.weekEnd;
  }
  return heure < int.parse(t.coreDebutApresMidi)
      ? MomentDuJour.matin
      : MomentDuJour.apresMidi;
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
