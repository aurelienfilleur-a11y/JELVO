import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/group.dart';
import '../repository/group_repository.dart';

final Provider<GroupRepository> groupRepositoryProvider =
    Provider<GroupRepository>((Ref ref) => InMemoryGroupRepository());

/// Tous les groupes de l'utilisateur.
final StreamProvider<List<Group>> groupsProvider = StreamProvider<List<Group>>(
  (Ref ref) => ref.watch(groupRepositoryProvider).watchGroups(),
);

/// Un groupe précis, ou `null` s'il n'existe pas (ou plus).
// Riverpod 3 n'exporte pas les types `*Family` : on laisse l'inférence faire.
final groupByIdProvider = Provider.family<Group?, String>((Ref ref, String id) {
  // Dépendre du flux garantit que la vue de détail suit les mises à jour.
  ref.watch(groupsProvider);
  return ref.watch(groupRepositoryProvider).findById(id);
});

/// Groupes triés par activité décroissante, pour la page d'accueil.
final Provider<List<Group>> activeGroupsProvider = Provider<List<Group>>((
  Ref ref,
) {
  final List<Group> groups = ref.watch(groupsProvider).value ?? const <Group>[];
  final List<Group> sorted = List<Group>.of(groups);
  sorted.sort(
    (Group a, Group b) => (b.upcomingEventCount + b.openTaskCount).compareTo(
      a.upcomingEventCount + a.openTaskCount,
    ),
  );
  return sorted;
});
