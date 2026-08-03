import '../../../data/in_memory_collection.dart';
import '../models/task.dart';

abstract interface class TaskRepository {
  Stream<List<Task>> watchTasks();

  Task? findById(String id);

  void toggleDone(String id);

  void upsert(Task task);

  void remove(String id);
}

class InMemoryTaskRepository implements TaskRepository {
  InMemoryTaskRepository({Iterable<Task>? seed, DateTime? anchor})
    : _collection = InMemoryCollection<Task>(
        idOf: (Task t) => t.id,
        seed: seed ?? demoTasks(anchor ?? DateTime.now()),
      );

  final InMemoryCollection<Task> _collection;

  @override
  Stream<List<Task>> watchTasks() => _collection.watch().map(
    // `items` est non modifiable : on trie une copie.
    (List<Task> tasks) => List<Task>.of(tasks)
      ..sort((Task a, Task b) {
        // Ouvertes d'abord, puis par échéance ; les tâches sans date
        // ferment la marche plutôt que de remonter en tête.
        if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
        final DateTime? da = a.dueDate;
        final DateTime? db = b.dueDate;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      }),
  );

  @override
  Task? findById(String id) => _collection.findById(id);

  @override
  void toggleDone(String id) =>
      _collection.mutate(id, (Task t) => t.copyWith(isDone: !t.isDone));

  @override
  void upsert(Task task) => _collection.upsert(task);

  @override
  void remove(String id) => _collection.remove(id);

  static List<Task> demoTasks(DateTime anchor) {
    final DateTime today = DateTime(anchor.year, anchor.month, anchor.day);
    DateTime day(int offset, [int hour = 18]) =>
        today.add(Duration(days: offset, hours: hour));

    return <Task>[
      Task(
        id: 't1',
        title: 'Réserver le restaurant pour samedi',
        groupId: 'g1',
        assigneeId: 'c1',
        dueDate: day(0),
        priority: TaskPriority.high,
      ),
      Task(
        id: 't2',
        title: 'Préparer la présentation du sprint',
        notes: 'Reprendre les métriques de la semaine dernière',
        groupId: 'g2',
        assigneeId: 'c2',
        dueDate: day(1, 9),
        priority: TaskPriority.high,
      ),
      Task(
        id: 't3',
        title: 'Acheter le cadeau de Léa',
        groupId: 'g1',
        dueDate: day(1, 12),
      ),
      Task(
        id: 't4',
        title: 'Relancer le syndic',
        groupId: 'g4',
        dueDate: day(-1),
        priority: TaskPriority.high,
      ),
      Task(
        id: 't5',
        title: 'Vérifier le matériel de rando',
        groupId: 'g3',
        assigneeId: 'c4',
        dueDate: day(2),
      ),
      Task(
        id: 't6',
        title: 'Payer la facture d’électricité',
        groupId: 'g4',
        dueDate: day(5),
        isDone: true,
      ),
      Task(
        id: 't7',
        title: 'Renouveler le passeport',
        priority: TaskPriority.low,
      ),
    ];
  }
}
