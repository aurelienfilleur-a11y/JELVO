import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/data_providers.dart';
import '../../calendar/providers/calendar_providers.dart';
import '../../groups/providers/group_providers.dart';
import '../../tasks/providers/task_providers.dart';

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
