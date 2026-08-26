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
  String? lastCreatedGroupId;
  List<String>? lastCreatedAssignees;
  String? lastToggledId;
  bool? lastToggledDone;
  String? lastCheckedItemId;
  AssigneeStatus? lastResponse;
  String? lastUpdatedTitle;
  String? lastClaimedId;
  bool? lastClaimTake;
  String? lastDeletedId;

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
    lastCreatedGroupId = groupId;
    // `null` et `[]` ne veulent pas dire la même chose côté SQL : le test doit
    // pouvoir les distinguer.
    lastCreatedAssignees = assignees;
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
  Future<Task> updateTask({
    required String taskId,
    required String title,
    String? description,
    DateTime? dueAt,
    TaskPriority priority = TaskPriority.medium,
    DateTime? reminderAt,
    String? rrule,
  }) async {
    lastUpdatedTitle = title;
    final int index = _tasks.indexWhere((Task t) => t.id == taskId);
    final Task ancienne = index == -1
        ? Task(id: taskId, title: title)
        : _tasks[index];
    final Task modifiee = Task(
      id: taskId,
      title: title,
      notes: description,
      dueDate: dueAt,
      groupId: ancienne.groupId,
      createdBy: ancienne.createdBy,
      completedAt: ancienne.completedAt,
      priority: priority,
      reminderAt: reminderAt,
      rrule: rrule,
      myStatus: ancienne.myStatus,
      assignees: ancienne.assignees,
      itemCount: ancienne.itemCount,
      checkedCount: ancienne.checkedCount,
    );
    if (index == -1) {
      _tasks.add(modifiee);
    } else {
      _tasks[index] = modifiee;
    }
    return modifiee;
  }

  @override
  Future<String> claim({required String taskId, required bool take}) async {
    lastClaimedId = taskId;
    lastClaimTake = take;
    return take ? 'pris' : 'lache';
  }

  /// Mot d'état imposé, pour éprouver la course : la seconde personne à
  /// toucher « Oui » doit se voir refuser proprement.
  String? takeOutcome;

  String? lastTakenId;
  String? lastWithdrawnId;

  @override
  Future<String> takeTask(String taskId) async {
    lastTakenId = taskId;
    final String mot = takeOutcome ?? 'prise';
    if (mot == 'prise') {
      _remplacerAssignes(taskId, <TaskAssignee>[
        const TaskAssignee(
          userId: 'moi',
          status: AssigneeStatus.accepted,
          name: 'Camille Rousseau',
        ),
      ], prise: true);
    }
    return mot;
  }

  @override
  Future<String> withdrawFromTask(String taskId) async {
    lastWithdrawnId = taskId;
    final String mot = takeOutcome ?? 'desiste';
    if (mot == 'desiste') {
      _remplacerAssignes(taskId, const <TaskAssignee>[], prise: false);
    }
    return mot;
  }

  /// Reflète sur la tâche ce que la fonction SQL ferait, pour que la relecture
  /// qui suit l'action montre le nouvel état.
  void _remplacerAssignes(
    String taskId,
    List<TaskAssignee> assignes, {
    required bool prise,
  }) {
    for (int i = 0; i < _tasks.length; i++) {
      if (_tasks[i].id != taskId) continue;
      final Task t = _tasks[i];
      _tasks[i] = Task(
        id: t.id,
        title: t.title,
        notes: t.notes,
        dueDate: t.dueDate,
        groupId: t.groupId,
        createdBy: t.createdBy,
        completedAt: t.completedAt,
        priority: t.priority,
        reminderAt: t.reminderAt,
        rrule: t.rrule,
        myStatus: assignes.isEmpty ? null : assignes.first.status,
        assignees: assignes,
        itemCount: t.itemCount,
        checkedCount: t.checkedCount,
        authorName: t.authorName,
        authorAvatarUrl: t.authorAvatarUrl,
        groupName: t.groupName,
        groupPhotoUrl: t.groupPhotoUrl,
      );
    }
    lastTakePrise = prise;
  }

  bool? lastTakePrise;

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
  Future<void> deleteTask(String taskId) async {
    lastDeletedId = taskId;
    _tasks.removeWhere((Task t) => t.id == taskId);
  }

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
