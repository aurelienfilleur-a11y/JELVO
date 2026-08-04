import 'package:flutter/foundation.dart';

import '../../../core/widgets/status_dot.dart';

/// Priorité d'une tâche, utilisée pour le tri et la teinte de l'échéance.
enum TaskPriority {
  low('Basse'),
  normal('Normale'),
  high('Haute');

  const TaskPriority(this.label);

  final String label;
}

/// Une tâche personnelle ou partagée dans un groupe.
@immutable
class Task {
  const Task({
    required this.id,
    required this.title,
    this.notes,
    this.dueDate,
    this.groupId,
    this.assigneeId,
    this.isDone = false,
    this.priority = TaskPriority.normal,
  });

  final String id;
  final String title;
  final String? notes;
  final DateTime? dueDate;

  /// Groupe de rattachement, `null` pour une tâche personnelle.
  final String? groupId;

  final String? assigneeId;
  final bool isDone;
  final TaskPriority priority;

  /// Vrai si l'échéance est dépassée et la tâche toujours ouverte.
  bool isOverdue(DateTime now) =>
      !isDone && dueDate != null && dueDate!.isBefore(now);

  /// Teinte de la pastille d'échéance : rouge si en retard, orange si due
  /// aujourd'hui ou demain, neutre au-delà.
  StatusTone toneFor(DateTime now) {
    if (isDone) return StatusTone.neutral;
    if (dueDate == null) return StatusTone.info;
    if (isOverdue(now)) return StatusTone.danger;

    final DateTime day = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    final DateTime today = DateTime(now.year, now.month, now.day);
    final int days = day.difference(today).inDays;
    return days <= 1 ? StatusTone.warning : StatusTone.info;
  }

  Task copyWith({
    String? title,
    String? notes,
    DateTime? dueDate,
    String? groupId,
    String? assigneeId,
    bool? isDone,
    TaskPriority? priority,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      dueDate: dueDate ?? this.dueDate,
      groupId: groupId ?? this.groupId,
      assigneeId: assigneeId ?? this.assigneeId,
      isDone: isDone ?? this.isDone,
      priority: priority ?? this.priority,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Task && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
