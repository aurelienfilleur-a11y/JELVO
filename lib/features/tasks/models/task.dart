import 'package:flutter/foundation.dart';

import '../../../core/widgets/status_dot.dart';

/// Priorité d'une tâche.
///
/// Reflète le type `task_priority` de la base, qui ne connaît que ces trois
/// valeurs — d'où `medium` et non `normal`.
enum TaskPriority {
  low('Basse', 'low'),
  medium('Normale', 'medium'),
  high('Haute', 'high');

  const TaskPriority(this.label, this.dbValue);

  final String label;
  final String dbValue;

  static TaskPriority fromDb(String? value) => switch (value) {
    'low' => TaskPriority.low,
    'high' => TaskPriority.high,
    _ => TaskPriority.medium,
  };
}

/// Réponse d'une personne assignée à une tâche.
///
/// Reflète le type `assignee_status`. `done` marque la part de cette personne
/// comme faite, sans préjuger de la tâche entière.
enum AssigneeStatus {
  pending('En attente'),
  accepted('Acceptée'),
  declined('Refusée'),
  done('Terminée');

  const AssigneeStatus(this.label);

  final String label;

  static AssigneeStatus fromDb(String? value) => switch (value) {
    'accepted' => AssigneeStatus.accepted,
    'declined' => AssigneeStatus.declined,
    'done' => AssigneeStatus.done,
    _ => AssigneeStatus.pending,
  };

  String get dbValue => name;
}

/// Une personne assignée, avec son profil et sa réponse.
@immutable
class TaskAssignee {
  const TaskAssignee({
    required this.userId,
    required this.status,
    this.name,
    this.avatarUrl,
  });

  factory TaskAssignee.fromJson(Map<String, dynamic> json) {
    return TaskAssignee(
      userId: json['user_id'] as String,
      status: AssigneeStatus.fromDb(json['status'] as String?),
      name: json['nom'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  final String userId;
  final AssigneeStatus status;
  final String? name;
  final String? avatarUrl;

  String get displayName => name ?? 'Membre';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskAssignee && other.userId == userId);

  @override
  int get hashCode => userId.hashCode;
}

/// Un article de la liste de courses rattachée à une tâche.
@immutable
class TaskListItem {
  const TaskListItem({
    required this.id,
    required this.label,
    this.position = 0,
    this.checkedAt,
    this.checkedBy,
    this.checkedByName,
  });

  factory TaskListItem.fromRow(Map<String, dynamic> row) {
    return TaskListItem(
      id: row['id'] as String,
      label: (row['label'] as String?) ?? '',
      position: (row['position'] as int?) ?? 0,
      checkedAt: DateTime.tryParse((row['checked_at'] as String?) ?? ''),
      checkedBy: row['checked_by'] as String?,
      checkedByName: row['coche_par'] as String?,
    );
  }

  final String id;
  final String label;
  final int position;
  final DateTime? checkedAt;
  final String? checkedBy;

  /// Qui a coché l'article — dans une colocation, cela évite de prendre le
  /// pain en double.
  final String? checkedByName;

  bool get isChecked => checkedAt != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is TaskListItem && other.id == id);

  @override
  int get hashCode => id.hashCode;
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
    this.createdBy,
    this.completedAt,
    this.priority = TaskPriority.medium,
    this.reminderAt,
    this.rrule,
    this.myStatus,
    this.assignees = const <TaskAssignee>[],
    this.itemCount = 0,
    this.checkedCount = 0,
    this.authorName,
    this.authorAvatarUrl,
    this.groupName,
    this.groupPhotoUrl,
  });

  factory Task.fromRow(Map<String, dynamic> row) {
    final Object? bruts = row['assignes'];
    return Task(
      id: row['id'] as String,
      title: (row['title'] as String?) ?? '',
      notes: row['description'] as String?,
      dueDate: DateTime.tryParse((row['due_at'] as String?) ?? '')?.toLocal(),
      groupId: row['group_id'] as String?,
      createdBy: row['created_by'] as String?,
      completedAt: DateTime.tryParse(
        (row['completed_at'] as String?) ?? '',
      )?.toLocal(),
      priority: TaskPriority.fromDb(row['priority'] as String?),
      reminderAt: DateTime.tryParse(
        (row['reminder_at'] as String?) ?? '',
      )?.toLocal(),
      rrule: row['rrule'] as String?,
      myStatus: row['mon_statut'] == null
          ? null
          : AssigneeStatus.fromDb(row['mon_statut'] as String?),
      assignees: bruts is List
          ? bruts
                .whereType<Map<String, dynamic>>()
                .map(TaskAssignee.fromJson)
                .toList()
          : const <TaskAssignee>[],
      itemCount: (row['articles'] as int?) ?? 0,
      checkedCount: (row['articles_coches'] as int?) ?? 0,
      authorName: row['auteur'] as String?,
      authorAvatarUrl: row['auteur_avatar'] as String?,
      groupName: row['groupe_nom'] as String?,
      groupPhotoUrl: row['groupe_photo'] as String?,
    );
  }

  final String id;
  final String title;
  final String? notes;
  final DateTime? dueDate;

  /// Groupe de rattachement, `null` pour une tâche personnelle.
  final String? groupId;

  final String? createdBy;

  /// Renseigné dès que la tâche est terminée : c'est la **seule** source du
  /// statut, aucun état n'est stocké en double.
  final DateTime? completedAt;

  final TaskPriority priority;
  final DateTime? reminderAt;
  final String? rrule;

  /// Réponse de l'utilisateur courant, `null` s'il n'est pas assigné.
  final AssigneeStatus? myStatus;

  final List<TaskAssignee> assignees;
  final int itemCount;
  final int checkedCount;

  /// Nom de qui a créé la tâche — donc de qui l'a confiée.
  ///
  /// `null` si son profil a disparu : l'écran d'attribution reformule alors
  /// sans sujet, comme le fait déjà la notification système.
  final String? authorName;

  final String? authorAvatarUrl;

  /// Nom et photo de couverture du groupe, renvoyés par `mes_taches`.
  ///
  /// Un assigné peut ne pas être membre du groupe : les relire côté client
  /// afficherait « Personnel » à tort.
  final String? groupName;

  final String? groupPhotoUrl;

  bool get isDone => completedAt != null;

  bool get isPersonal => groupId == null;

  bool get hasList => itemCount > 0;

  bool get isRecurring => rrule != null && rrule!.isNotEmpty;

  /// L'utilisateur est assigné et n'a pas encore répondu.
  bool get awaitsMyAnswer => myStatus == AssigneeStatus.pending;

  /// Vrai si l'échéance est dépassée et la tâche toujours ouverte.
  bool isOverdue(DateTime now) =>
      !isDone && dueDate != null && dueDate!.isBefore(now);

  /// Libellé du statut, tel qu'affiché.
  String statusLabel(DateTime now) {
    if (isDone) return 'Terminée';
    if (isOverdue(now)) return 'En retard';
    return 'À faire';
  }

  /// Teinte de la pastille d'échéance : rouge si en retard, orange si due
  /// aujourd'hui ou demain, neutre au-delà.
  StatusTone toneFor(DateTime now) {
    if (isDone) return StatusTone.neutral;
    if (dueDate == null) return StatusTone.info;
    if (dueDate!.isBefore(now)) return StatusTone.danger;
    return dueDate!.difference(now).inHours <= 48
        ? StatusTone.warning
        : StatusTone.info;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Task && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
