import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../router/app_routes.dart';
import '../../auth/models/auth_failure.dart';
import '../models/task.dart';
import '../providers/task_providers.dart';
import '../screens/task_detail_screen.dart';

/// Ligne de tâche câblée sur le domaine : ouverture du détail au toucher,
/// choix « Terminée / Supprimer » sur la case.
///
/// Une case à cocher qui supprimerait sans prévenir serait un piège ; une case
/// qui ne ferait que terminer obligerait à ouvrir le détail pour supprimer. Le
/// petit menu tranche : deux gestes fréquents au même endroit, tous deux
/// nommés.
class TaskTile extends ConsumerWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.now,
    this.groupName,
    this.showDivider = true,
  });

  final Task task;
  final DateTime now;
  final String? groupName;
  final bool showDivider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TaskRow(
      title: task.title,
      subtitle: task.hasList
          ? '${task.checkedCount} sur ${task.itemCount} articles'
          : (groupName ?? task.notes),
      done: task.isDone,
      dueLabel: task.dueDate == null
          ? null
          : AppDates.relativeDay(task.dueDate!, now: now),
      dueTone: task.toneFor(now),
      assignee: task.assignees.isEmpty && !task.isPersonal
          ? 'Libre'
          : (task.assignees.length == 1
                ? task.assignees.first.displayName
                : null),
      showDivider: showDivider,
      onTap: () => context.pushNamed(
        AppRoutes.taskDetail,
        pathParameters: <String, String>{'id': task.id},
      ),
      onToggle: (_) => _menu(context, ref),
    );
  }

  Future<void> _menu(BuildContext context, WidgetRef ref) async {
    final _ChoixCase? choix = await showModalBottomSheet<_ChoixCase>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                task.title,
                style: AppTypography.h3,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            AppSpacing.gapMd,
            ListTile(
              leading: Icon(
                task.isDone ? Icons.undo_rounded : Icons.check_circle_outline,
                color: AppColors.success,
              ),
              title: Text(task.isDone ? 'Rouvrir' : 'Terminée'),
              onTap: () => Navigator.of(sheetContext).pop(_ChoixCase.terminer),
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.danger,
              ),
              title: const Text('Supprimer'),
              onTap: () => Navigator.of(sheetContext).pop(_ChoixCase.supprimer),
            ),
            AppSpacing.gapMd,
          ],
        ),
      ),
    );
    if (choix == null || !context.mounted) return;

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      if (choix == _ChoixCase.terminer) {
        await ref
            .read(taskActionsProvider)
            .toggleDone(task.id, done: !task.isDone);
        return;
      }
      final bool confirme = await confirmerSuppressionDeTache(context, task);
      if (!confirme) return;
      await ref.read(taskActionsProvider).remove(task.id);
      messenger.showSnackBar(
        SnackBar(content: Text('« ${task.title} » a été supprimée.')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(AuthFailure.from(error).message)),
      );
    }
  }
}

enum _ChoixCase { terminer, supprimer }
