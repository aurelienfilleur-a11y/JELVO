import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_formatting.dart';
import '../../../data/data_providers.dart';
import '../../../data/supabase_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/task.dart';
import '../repository/task_repository.dart';

/// Dépôt des tâches. Surchargé dans les tests par un faux dépôt.
final Provider<TaskRepository> taskRepositoryProvider =
    Provider<TaskRepository>(
      (Ref ref) => SupabaseTaskRepository(ref.watch(supabaseClientProvider)),
    );

/// Toutes les tâches visibles, ouvertes d'abord puis par échéance.
///
/// Un `AsyncNotifier` plutôt qu'un `StreamProvider` : les écritures passent
/// par `taskActionsProvider`, qui rafraîchit explicitement.
final AsyncNotifierProvider<TasksNotifier, List<Task>> tasksProvider =
    AsyncNotifierProvider<TasksNotifier, List<Task>>(TasksNotifier.new);

class TasksNotifier extends AsyncNotifier<List<Task>> {
  @override
  Future<List<Task>> build() {
    ref.watch(authStatusProvider);
    return ref.watch(taskRepositoryProvider).fetchTasks();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(taskRepositoryProvider).fetchTasks(),
    );
  }
}

List<Task> _all(Ref ref) => ref.watch(tasksProvider).value ?? const <Task>[];

/// Tâches encore ouvertes.
final Provider<List<Task>> openTasksProvider = Provider<List<Task>>(
  (Ref ref) => _all(ref).where((Task t) => !t.isDone).toList(),
);

/// Tâches à traiter en priorité sur l'accueil : en retard, ou dues sous 48 h.
final Provider<List<Task>> focusTasksProvider = Provider<List<Task>>((Ref ref) {
  final DateTime now = ref.watch(nowProvider);
  return ref.watch(openTasksProvider).where((Task t) {
    if (t.dueDate == null) return false;
    return AppDates.dayDifference(t.dueDate!, now) <= 1;
  }).toList();
});

/// Tâches assignées à l'utilisateur et encore sans réponse.
final Provider<List<Task>> tasksAwaitingAnswerProvider = Provider<List<Task>>(
  (Ref ref) => _all(ref).where((Task t) => t.awaitsMyAnswer).toList(),
);

/// Tâches d'un groupe donné.
// Riverpod 3 n'exporte pas les types `*Family` : on laisse l'inférence faire.
final tasksForGroupProvider = Provider.family<List<Task>, String>(
  (Ref ref, String groupId) =>
      _all(ref).where((Task t) => t.groupId == groupId).toList(),
);

/// Une tâche par son identifiant, `null` si elle n'est plus visible.
///
/// L'écran de détail s'y branche plutôt que de recevoir la tâche en argument :
/// après une modification ou un cochage, il se remet à jour tout seul.
final taskByIdProvider = Provider.family<Task?, String>((Ref ref, String id) {
  for (final Task task in _all(ref)) {
    if (task.id == id) return task;
  }
  return null;
});

/// Tâches ouvertes que personne n'a prises, dans un groupe donné.
final unassignedTasksForGroupProvider = Provider.family<List<Task>, String>(
  (Ref ref, String groupId) => ref
      .watch(tasksForGroupProvider(groupId))
      .where((Task t) => !t.isDone && t.assignees.isEmpty)
      .toList(),
);

/// Liste de courses d'une tâche, rechargée à chaque ouverture.
final taskItemsProvider = FutureProvider.autoDispose
    .family<List<TaskListItem>, String>(
      (Ref ref, String taskId) =>
          ref.watch(taskRepositoryProvider).fetchItems(taskId),
    );

/// Écritures sur les tâches. Les widgets ne touchent jamais au dépôt.
final Provider<TaskActions> taskActionsProvider = Provider<TaskActions>(
  TaskActions.new,
);

class TaskActions {
  const TaskActions(this._ref);

  final Ref _ref;

  TaskRepository get _repository => _ref.read(taskRepositoryProvider);

  Future<Task> create({
    required String title,
    String? groupId,
    String? description,
    DateTime? dueAt,
    TaskPriority priority = TaskPriority.medium,
    DateTime? reminderAt,
    String? rrule,
    List<String>? assignees,
    List<String>? items,
  }) async {
    final Task task = await _repository.createTask(
      title: title,
      groupId: groupId,
      description: description,
      dueAt: dueAt,
      priority: priority,
      reminderAt: reminderAt,
      rrule: rrule,
      assignees: assignees,
      items: items,
    );
    await _refresh();
    return task;
  }

  Future<Task> update({
    required String taskId,
    required String title,
    String? description,
    DateTime? dueAt,
    TaskPriority priority = TaskPriority.medium,
    DateTime? reminderAt,
    String? rrule,
  }) async {
    final Task task = await _repository.updateTask(
      taskId: taskId,
      title: title,
      description: description,
      dueAt: dueAt,
      priority: priority,
      reminderAt: reminderAt,
      rrule: rrule,
    );
    await _refresh();
    return task;
  }

  /// Prendre une tâche libre, ou s'en retirer. Renvoie le mot d'état de la
  /// fonction SQL, que l'écran traduit.
  Future<String> claim(String taskId, {required bool take}) async {
    final String outcome = await _repository.claim(taskId: taskId, take: take);
    await _refresh();
    return outcome;
  }

  Future<void> toggleDone(String taskId, {required bool done}) async {
    await _repository.setDone(taskId: taskId, done: done);
    await _refresh();
  }

  Future<void> respond(String taskId, AssigneeStatus status) async {
    await _repository.respond(taskId: taskId, status: status);
    await _refresh();
  }

  Future<void> setAssignees(String taskId, List<String> assignees) async {
    await _repository.setAssignees(taskId: taskId, assignees: assignees);
    await _refresh();
  }

  Future<void> remove(String taskId) async {
    await _repository.deleteTask(taskId);
    await _refresh();
  }

  Future<void> checkItem(
    String taskId,
    String itemId, {
    required bool checked,
  }) async {
    await _repository.checkItem(itemId: itemId, checked: checked);
    _ref.invalidate(taskItemsProvider(taskId));
    await _refresh();
  }

  Future<void> addItem(String taskId, String label) async {
    await _repository.addItem(taskId: taskId, label: label);
    _ref.invalidate(taskItemsProvider(taskId));
    await _refresh();
  }

  Future<void> removeItem(String taskId, String itemId) async {
    await _repository.removeItem(itemId);
    _ref.invalidate(taskItemsProvider(taskId));
    await _refresh();
  }

  Future<void> _refresh() => _ref.read(tasksProvider.notifier).refresh();
}
