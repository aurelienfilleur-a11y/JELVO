import 'package:jelvo/features/tasks/models/task.dart';
import 'package:jelvo/features/tasks/repository/task_repository.dart';

/// Dépôt de tâches en mémoire, pour les tests de widget.
class FakeTaskRepository implements TaskRepository {
  FakeTaskRepository({List<Task>? tasks, List<TaskListItem>? items})
    : _tasks = List<Task>.of(tasks ?? demoTasks()),
      _items = List<TaskListItem>.of(items ?? demoItems);

  final List<Task> _tasks;
  final List<TaskListItem> _items;

  /// Dernier appel reçu, pour les assertions.
  String? lastCreatedTitle;
  String? lastToggledId;
  bool? lastToggledDone;
  String? lastCheckedItemId;
  AssigneeStatus? lastResponse;

  /// Deux tâches suffisent : une à échéance proche pour l'accueil, une du
  /// groupe g1 pour l'écran de groupe.
  static List<Task> demoTasks() => <Task>[
    Task(
      id: 't1',
      title: 'Réserver le restaurant pour samedi',
      groupId: 'g1',
      dueDate: DateTime(2026, 8, 3, 18),
      priority: TaskPriority.high,
      myStatus: AssigneeStatus.accepted,
      itemCount: 2,
      checkedCount: 1,
    ),
    const Task(id: 't2', title: 'Renouveler le passeport'),
  ];

  static const List<TaskListItem> demoItems = <TaskListItem>[
    TaskListItem(id: 'i1', label: 'Pain'),
    TaskListItem(id: 'i2', label: 'Fromage', position: 1),
  ];

  @override
  Future<List<Task>> fetchTasks({String? groupId}) async => groupId == null
      ? List<Task>.of(_tasks)
      : _tasks.where((Task t) => t.groupId == groupId).toList();

  @override
  Future<Task> createTask({
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
    lastCreatedTitle = title;
    final Task task = Task(
      id: 't${_tasks.length + 1}',
      title: title,
      groupId: groupId,
      notes: description,
      dueDate: dueAt,
      priority: priority,
      reminderAt: reminderAt,
      rrule: rrule,
      itemCount: items?.length ?? 0,
    );
    _tasks.add(task);
    return task;
  }

  @override
  Future<void> respond({
    required String taskId,
    required AssigneeStatus status,
  }) async => lastResponse = status;

  @override
  Future<void> setDone({required String taskId, required bool done}) async {
    lastToggledId = taskId;
    lastToggledDone = done;
    final int index = _tasks.indexWhere((Task t) => t.id == taskId);
    if (index == -1) return;
    final Task t = _tasks[index];
    _tasks[index] = Task(
      id: t.id,
      title: t.title,
      notes: t.notes,
      dueDate: t.dueDate,
      groupId: t.groupId,
      priority: t.priority,
      completedAt: done ? DateTime(2026, 8, 3, 9) : null,
      itemCount: t.itemCount,
      checkedCount: t.checkedCount,
    );
  }

  @override
  Future<void> setAssignees({
    required String taskId,
    required List<String> assignees,
  }) async {}

  @override
  Future<void> deleteTask(String taskId) async =>
      _tasks.removeWhere((Task t) => t.id == taskId);

  @override
  Future<List<TaskListItem>> fetchItems(String taskId) async =>
      List<TaskListItem>.of(_items);

  @override
  Future<void> checkItem({
    required String itemId,
    required bool checked,
  }) async => lastCheckedItemId = itemId;

  @override
  Future<void> addItem({required String taskId, required String label}) async {
    _items.add(TaskListItem(id: 'i${_items.length + 1}', label: label));
  }

  @override
  Future<void> removeItem(String itemId) async =>
      _items.removeWhere((TaskListItem i) => i.id == itemId);
}
