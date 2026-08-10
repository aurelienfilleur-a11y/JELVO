import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/models/auth_failure.dart';
import '../models/task.dart';

/// Accès aux tâches, à leurs assignés et à leur liste de courses.
///
/// Toutes les écritures passent par des fonctions SQL : `tasks` et
/// `task_assignees` n'ont pas de politique DELETE, et le `returning` d'une
/// insertion repasserait par la politique SELECT. Voir
/// `supabase/tranche3_taches_et_evenements.sql`.
abstract interface class TaskRepository {
  /// Tâches visibles, toutes ou celles d'un seul groupe.
  Future<List<Task>> fetchTasks({String? groupId});

  Future<Task> createTask({
    required String title,
    String? groupId,
    String? description,
    DateTime? dueAt,
    TaskPriority priority,
    DateTime? reminderAt,
    String? rrule,
    List<String>? assignees,
    List<String>? items,
  });

  /// Remplace **tous** les champs modifiables : l'écran de détail envoie
  /// l'état complet du formulaire. Une sémantique « ne change que ce qui est
  /// fourni » interdirait de vider une échéance.
  Future<Task> updateTask({
    required String taskId,
    required String title,
    String? description,
    DateTime? dueAt,
    TaskPriority priority,
    DateTime? reminderAt,
    String? rrule,
  });

  /// Se prendre ou se retirer une tâche libre. Renvoie le mot d'état de
  /// `s_attribuer_tache` : `pris`, `lache`, `deja_pris`, `deja_assignee`…
  Future<String> claim({required String taskId, required bool take});

  /// L'assigné accepte ou refuse.
  Future<void> respond({
    required String taskId,
    required AssigneeStatus status,
  });

  Future<void> setDone({required String taskId, required bool done});

  Future<void> setAssignees({
    required String taskId,
    required List<String> assignees,
  });

  Future<void> deleteTask(String taskId);

  Future<List<TaskListItem>> fetchItems(String taskId);

  Future<void> checkItem({required String itemId, required bool checked});

  Future<void> addItem({required String taskId, required String label});

  Future<void> removeItem(String itemId);
}

class SupabaseTaskRepository implements TaskRepository {
  const SupabaseTaskRepository(this._client);

  final SupabaseClient _client;

  bool get _signedIn => _client.auth.currentUser != null;

  @override
  Future<List<Task>> fetchTasks({String? groupId}) async {
    if (!_signedIn) return const <Task>[];
    try {
      final Object? result = await _client.rpc<Object?>(
        'mes_taches',
        params: <String, dynamic>{'p_group_id': groupId},
      );
      return _rows(result).map(Task.fromRow).toList();
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

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
    try {
      final Object? result = await _client.rpc<Object?>(
        'creer_tache',
        params: <String, dynamic>{
          'p_title': title,
          'p_group_id': groupId,
          'p_description': description,
          'p_due_at': dueAt?.toUtc().toIso8601String(),
          'p_priority': priority.dbValue,
          'p_reminder_at': reminderAt?.toUtc().toIso8601String(),
          'p_rrule': rrule,
          'p_assignees': assignees,
          'p_items': items,
        },
      );
      final List<Map<String, dynamic>> rows = _rows(result);
      if (rows.isEmpty) {
        throw const AuthFailure(
          'La tâche n’a pas pu être créée. Réessayez dans un instant.',
        );
      }
      return Task.fromRow(rows.first);
    } catch (error) {
      throw AuthFailure.from(error);
    }
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
    try {
      final Object? result = await _client.rpc<Object?>(
        'modifier_tache',
        params: <String, dynamic>{
          'p_task_id': taskId,
          'p_title': title,
          'p_description': description,
          'p_due_at': dueAt?.toUtc().toIso8601String(),
          'p_priority': priority.dbValue,
          'p_reminder_at': reminderAt?.toUtc().toIso8601String(),
          'p_rrule': rrule,
        },
      );
      final List<Map<String, dynamic>> rows = _rows(result);
      if (rows.isEmpty) {
        throw const AuthFailure(
          'La tâche n’a pas pu être modifiée. Réessayez dans un instant.',
        );
      }
      return Task.fromRow(rows.first);
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<String> claim({required String taskId, required bool take}) async {
    try {
      final Object? result = await _client.rpc<Object?>(
        's_attribuer_tache',
        params: <String, dynamic>{'p_task_id': taskId, 'p_prendre': take},
      );
      return (result as String?) ?? 'inconnu';
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<void> respond({
    required String taskId,
    required AssigneeStatus status,
  }) => _call('repondre_tache', <String, dynamic>{
    'p_task_id': taskId,
    'p_statut': status.dbValue,
  });

  @override
  Future<void> setDone({required String taskId, required bool done}) => _call(
    'terminer_tache',
    <String, dynamic>{'p_task_id': taskId, 'p_terminee': done},
  );

  @override
  Future<void> setAssignees({
    required String taskId,
    required List<String> assignees,
  }) => _call('definir_assignes_tache', <String, dynamic>{
    'p_task_id': taskId,
    'p_assignees': assignees,
  });

  @override
  Future<void> deleteTask(String taskId) =>
      _call('supprimer_tache', <String, dynamic>{'p_task_id': taskId});

  @override
  Future<List<TaskListItem>> fetchItems(String taskId) async {
    try {
      final Object? result = await _client.rpc<Object?>(
        'articles_de_tache',
        params: <String, dynamic>{'p_task_id': taskId},
      );
      return _rows(result).map(TaskListItem.fromRow).toList();
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<void> checkItem({required String itemId, required bool checked}) =>
      _call('cocher_article', <String, dynamic>{
        'p_item_id': itemId,
        'p_coche': checked,
      });

  @override
  Future<void> addItem({required String taskId, required String label}) =>
      _call('ajouter_article', <String, dynamic>{
        'p_task_id': taskId,
        'p_label': label,
      });

  @override
  Future<void> removeItem(String itemId) =>
      _call('supprimer_article', <String, dynamic>{'p_item_id': itemId});

  Future<void> _call(String fonction, Map<String, dynamic> params) async {
    try {
      await _client.rpc<Object?>(fonction, params: params);
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  static List<Map<String, dynamic>> _rows(Object? result) {
    if (result is List) {
      return result.whereType<Map<String, dynamic>>().toList();
    }
    if (result is Map<String, dynamic>) return <Map<String, dynamic>>[result];
    return const <Map<String, dynamic>>[];
  }
}
