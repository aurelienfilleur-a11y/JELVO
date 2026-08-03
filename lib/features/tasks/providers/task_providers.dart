import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_formatting.dart';
import '../../../data/data_providers.dart';
import '../models/task.dart';
import '../repository/task_repository.dart';

final Provider<TaskRepository> taskRepositoryProvider =
    Provider<TaskRepository>(
      (Ref ref) => InMemoryTaskRepository(anchor: ref.watch(nowProvider)),
    );

/// Toutes les tâches, ouvertes d'abord puis par échéance.
final StreamProvider<List<Task>> tasksProvider = StreamProvider<List<Task>>(
  (Ref ref) => ref.watch(taskRepositoryProvider).watchTasks(),
);

/// Tâches encore ouvertes.
final Provider<List<Task>> openTasksProvider = Provider<List<Task>>((Ref ref) {
  final List<Task> tasks = ref.watch(tasksProvider).value ?? const <Task>[];
  return tasks.where((Task t) => !t.isDone).toList();
});

/// Tâches à traiter en priorité sur l'accueil : en retard, ou dues sous 48 h.
final Provider<List<Task>> focusTasksProvider = Provider<List<Task>>((Ref ref) {
  final DateTime now = ref.watch(nowProvider);
  return ref.watch(openTasksProvider).where((Task t) {
    if (t.dueDate == null) return false;
    return AppDates.dayDifference(t.dueDate!, now) <= 1;
  }).toList();
});

/// Tâches d'un groupe donné.
// Riverpod 3 n'exporte pas les types `*Family` : on laisse l'inférence faire.
final tasksForGroupProvider = Provider.family<List<Task>, String>((
  Ref ref,
  String groupId,
) {
  final List<Task> tasks = ref.watch(tasksProvider).value ?? const <Task>[];
  return tasks.where((Task t) => t.groupId == groupId).toList();
});

/// Actions d'écriture sur les tâches, exposées aux écrans.
///
/// Les widgets appellent `ref.read(taskActionsProvider).toggleDone(id)` plutôt
/// que de manipuler le dépôt directement.
final Provider<TaskActions> taskActionsProvider = Provider<TaskActions>(
  (Ref ref) => TaskActions(ref.watch(taskRepositoryProvider)),
);

class TaskActions {
  const TaskActions(this._repository);

  final TaskRepository _repository;

  void toggleDone(String id) => _repository.toggleDone(id);

  void add(Task task) => _repository.upsert(task);

  void remove(String id) => _repository.remove(id);
}
