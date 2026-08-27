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
    this.showPriority = false,
  });

  final Task task;
  final DateTime now;
  final String? groupName;
  final bool showDivider;

  /// Affiche la priorité en pastille après le titre.
  ///
  /// Éteint par défaut : sur une liste où tout est « Normale », la pastille ne
  /// distinguerait rien. Elle n'a de sens que là où le tri s'en réclame — la
  /// section « Tâches prioritaires » d'un groupe.
  final bool showPriority;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TaskRow(
      title: task.title,
      subtitle: task.hasList
          ? '${task.checkedCount} sur ${task.itemCount} articles'
          : (groupName ?? task.notes),
      done: task.isDone,
      // La priorité normale ne se dit pas : c'est le défaut de `creer_tache`,
      // et l'annoncer sur les trois quarts des lignes noierait les deux qui
      // comptent.
      badge: showPriority && task.priority != TaskPriority.medium
          ? _PastillePriorite(priority: task.priority)
          : null,
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
              child: EmojiText(
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

/// La priorité d'une tâche, en pastille teintée.
///
/// Seule « Haute » prend une couleur — `danger`, celui de l'urgence. Une
/// priorité basse n'est pas une alerte : lui donner `warning` lui prêterait
/// une urgence qu'elle dit précisément ne pas avoir. Elle garde donc le gris
/// du texte secondaire.
class _PastillePriorite extends StatelessWidget {
  const _PastillePriorite({required this.priority});

  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    final (Color teinte, Color fond) = switch (priority) {
      TaskPriority.high => (AppColors.danger, AppColors.dangerSoft),
      TaskPriority.medium => (AppColors.textSecondary, AppColors.background),
      TaskPriority.low => (AppColors.textSecondary, AppColors.background),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(color: fond, borderRadius: AppRadii.pillRadius),
      child: Text(
        '${priority.label} priorité',
        style: AppTypography.caption.copyWith(
          color: teinte,
          fontWeight: AppTypography.medium,
        ),
      ),
    );
  }
}
