import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../data/data_providers.dart';
import '../../../router/app_routes.dart';
import '../../auth/models/auth_failure.dart';
import '../../auth/providers/auth_providers.dart';
import '../../calendar/models/recurrence.dart';
import '../../groups/models/group.dart';
import '../../groups/providers/group_providers.dart';
import '../models/task.dart';
import '../providers/task_providers.dart';
import '../widgets/task_form_sheet.dart';

/// Détail d'une tâche : tout ce qu'elle porte, et tout ce qu'on peut en faire.
///
/// L'écran se branche sur `taskByIdProvider` plutôt que de recevoir la tâche en
/// argument : après une modification, un cochage ou une prise en charge, il se
/// remet à jour sans que l'appelant ait à le rafraîchir.
class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Task? task = ref.watch(taskByIdProvider(taskId));

    return Scaffold(
      backgroundColor: context.couleurs.background,
      appBar: AppBar(
        title: const Text('Tâche'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Retour',
          onPressed: () => _revenir(context),
        ),
        actions: <Widget>[
          if (task != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Modifier la tâche',
              onPressed: () => ouvrirFormulaireDeTache(context, task: task),
            ),
          if (task != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Supprimer la tâche',
              onPressed: () => _confirmerSuppression(context, ref, task),
            ),
        ],
      ),
      body: task == null
          ? SafeArea(
              child: EmptyState(
                icon: Icons.task_alt_rounded,
                title: 'Tâche introuvable',
                message: 'Elle a été supprimée, ou vous n’y avez plus accès.',
                actionLabel: 'Retour',
                onActionPressed: () => _revenir(context),
              ),
            )
          : _Corps(task: task),
    );
  }

  static void _revenir(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(AppRoutes.home);
    }
  }

  Future<void> _confirmerSuppression(
    BuildContext context,
    WidgetRef ref,
    Task task,
  ) async {
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool confirme = await confirmerSuppressionDeTache(context, task);
    if (!confirme) return;

    try {
      await ref.read(taskActionsProvider).remove(task.id);
      messenger.showSnackBar(
        SnackBar(content: Text('« ${task.title} » a été supprimée.')),
      );
      if (navigator.canPop()) navigator.pop();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(AuthFailure.from(error).message)),
      );
    }
  }
}

/// Boîte de confirmation partagée : la suppression part aussi de la case à
/// cocher d'une ligne de tâche, et le libellé doit y être le même.
Future<bool> confirmerSuppressionDeTache(
  BuildContext context,
  Task task,
) async {
  final bool? reponse = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: const Text('Supprimer la tâche'),
      content: Text(
        '« ${task.title} » disparaîtra pour tout le monde. Cette action ne '
        'peut pas être annulée depuis l’application.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(foregroundColor: context.couleurs.danger),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  return reponse ?? false;
}

class _Corps extends ConsumerWidget {
  const _Corps({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime now = ref.watch(nowProvider);
    final Group? group = task.groupId == null
        ? null
        : ref.watch(groupByIdProvider(task.groupId!));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        AppSpacing.lg,
        AppSpacing.screenMargin,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        _Entete(task: task, now: now, group: group),
        AppSpacing.gapLg,
        _Caracteristiques(task: task, now: now, group: group),
        AppSpacing.gapLg,
        _Assignes(task: task),
        AppSpacing.gapLg,
        _ListeDeCourses(task: task),
        AppSpacing.gapXl,
        _ActionPrincipale(task: task),
      ],
    );
  }
}

/// Titre, statut et description.
class _Entete extends StatelessWidget {
  const _Entete({required this.task, required this.now, required this.group});

  final Task task;
  final DateTime now;
  final Group? group;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: EmojiText(
                  task.title,
                  style: context.typo.h2.copyWith(
                    decoration: task.isDone ? TextDecoration.lineThrough : null,
                    color: task.isDone
                        ? context.couleurs.textSecondary
                        : context.couleurs.encre,
                  ),
                ),
              ),
              AppSpacing.hGapMd,
              StatusDot(
                tone: task.toneFor(now),
                label: task.statusLabel(now),
                filled: true,
              ),
            ],
          ),
          if (task.notes != null && task.notes!.isNotEmpty) ...<Widget>[
            AppSpacing.gapMd,
            EmojiText(task.notes!, style: context.typo.bodyMuted),
          ],
        ],
      ),
    );
  }
}

/// Échéance, priorité, groupe, rappel et récurrence, une ligne chacun.
class _Caracteristiques extends StatelessWidget {
  const _Caracteristiques({
    required this.task,
    required this.now,
    required this.group,
  });

  final Task task;
  final DateTime now;
  final Group? group;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        children: <Widget>[
          _Ligne(
            icon: Icons.event_outlined,
            label: 'Échéance',
            value: task.dueDate == null
                ? 'Aucune'
                : '${AppDates.fullDate(task.dueDate!)} · '
                      '${AppDates.time(task.dueDate!)}',
            tone: task.isOverdue(now) ? context.couleurs.danger : null,
          ),
          _Ligne(
            icon: Icons.flag_outlined,
            label: 'Priorité',
            value: task.priority.label,
          ),
          _Ligne(
            icon: Icons.groups_outlined,
            label: 'Groupe',
            value: group?.name ?? (task.isPersonal ? 'Personnelle' : '—'),
          ),
          if (task.reminderAt != null)
            _Ligne(
              icon: Icons.notifications_none_rounded,
              label: 'Rappel',
              value:
                  '${AppDates.shortDate(task.reminderAt!)} · '
                  '${AppDates.time(task.reminderAt!)}',
            ),
          if (task.isRecurring)
            _Ligne(
              icon: Icons.repeat_rounded,
              label: 'Répétition',
              value: Recurrence.fromRrule(task.rrule).label,
              dernier: true,
            ),
        ],
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({
    required this.icon,
    required this.label,
    required this.value,
    this.tone,
    this.dernier = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? tone;
  final bool dernier;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 18, color: context.couleurs.textSecondary),
              AppSpacing.hGapMd,
              Expanded(child: Text(label, style: context.typo.body)),
              AppSpacing.hGapSm,
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.typo.body.copyWith(
                    color: tone ?? context.couleurs.primary,
                    fontWeight: AppTypography.semiBold,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!dernier) Divider(height: 1, color: context.couleurs.border),
      ],
    );
  }
}

/// Assignés, et le geste qui manquait : prendre une tâche que personne n'a
/// prise, ou s'en retirer.
class _Assignes extends ConsumerWidget {
  const _Assignes({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? moi = ref.watch(currentUserIdProvider);
    final bool jeSuisAssigne = task.assignees.any(
      (TaskAssignee a) => a.userId == moi,
    );
    final bool libre = task.assignees.isEmpty;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Assignée à', style: context.typo.h3),
          AppSpacing.gapMd,
          if (libre)
            Text(
              'Personne pour l’instant. N’importe quel membre du groupe peut '
              's’en charger.',
              style: context.typo.bodyMuted,
            )
          else
            Column(
              children: <Widget>[
                for (final TaskAssignee assigne in task.assignees)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: <Widget>[
                        AvatarStack(
                          avatars: <AvatarData>[
                            AvatarData(
                              name: assigne.displayName,
                              imageUrl: assigne.avatarUrl,
                            ),
                          ],
                          size: 32,
                        ),
                        AppSpacing.hGapMd,
                        Expanded(
                          child: Text(
                            assigne.userId == moi
                                ? '${assigne.displayName} (vous)'
                                : assigne.displayName,
                            style: context.typo.body,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        AppSpacing.hGapSm,
                        StatusDot(
                          tone: _tonePour(assigne.status),
                          label: assigne.status.label,
                        ),
                      ],
                    ),
                  ),
              ],
            ),

          // Une tâche personnelle n'a pas de membres à qui la confier.
          if (!task.isPersonal && (libre || jeSuisAssigne)) ...<Widget>[
            AppSpacing.gapMd,
            SecondaryButton(
              label: jeSuisAssigne ? 'Me retirer' : 'Je m’en charge',
              icon: jeSuisAssigne
                  ? Icons.person_remove_alt_1_outlined
                  : Icons.pan_tool_alt_outlined,
              onPressed: () => _prendre(context, ref, take: !jeSuisAssigne),
            ),
          ],
        ],
      ),
    );
  }

  static StatusTone _tonePour(AssigneeStatus status) => switch (status) {
    AssigneeStatus.accepted => StatusTone.success,
    AssigneeStatus.declined => StatusTone.danger,
    AssigneeStatus.done => StatusTone.success,
    AssigneeStatus.pending => StatusTone.warning,
  };

  Future<void> _prendre(
    BuildContext context,
    WidgetRef ref, {
    required bool take,
  }) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final String outcome = await ref
          .read(taskActionsProvider)
          .claim(task.id, take: take);
      messenger.showSnackBar(SnackBar(content: Text(_messagePour(outcome))));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(AuthFailure.from(error).message)),
      );
    }
  }

  static String _messagePour(String outcome) => switch (outcome) {
    'pris' => 'Vous vous chargez de cette tâche.',
    'deja_pris' => 'Vous vous en chargiez déjà.',
    'lache' => 'Vous ne vous en chargez plus.',
    'non_assigne' => 'Vous n’étiez pas assigné à cette tâche.',
    'deja_assignee' =>
      'Quelqu’un s’en charge déjà. Passez par « Modifier » pour changer les '
          'assignés.',
    _ => 'L’action n’a pas abouti. Réessayez dans un instant.',
  };
}

/// Liste de courses : cochable, avec l'auteur du cochage et l'ajout en bas.
class _ListeDeCourses extends ConsumerStatefulWidget {
  const _ListeDeCourses({required this.task});

  final Task task;

  @override
  ConsumerState<_ListeDeCourses> createState() => _ListeDeCoursesState();
}

class _ListeDeCoursesState extends ConsumerState<_ListeDeCourses> {
  final TextEditingController _controller = EmojiTextEditingController();
  bool _envoi = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<TaskListItem>> articles = ref.watch(
      taskItemsProvider(widget.task.id),
    );
    final List<TaskListItem> liste = articles.value ?? const <TaskListItem>[];
    final int coches = liste.where((TaskListItem a) => a.isChecked).length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text('Liste', style: context.typo.h3)),
              if (liste.isNotEmpty)
                Text(
                  '$coches sur ${liste.length}',
                  style: context.typo.caption,
                ),
            ],
          ),
          AppSpacing.gapMd,
          if (articles.isLoading && liste.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (liste.isEmpty)
            Text(
              'Rien à cocher. Ajoutez ce qu’il faut prendre : chacun verra ce '
              'qui reste.',
              style: context.typo.bodyMuted,
            )
          else
            for (final TaskListItem article in liste)
              _ArticleRow(taskId: widget.task.id, article: article),

          AppSpacing.gapMd,
          Row(
            children: <Widget>[
              Expanded(
                child: AppTextField(
                  controller: _controller,
                  hint: 'Ajouter un article',
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _ajouter(),
                ),
              ),
              AppSpacing.hGapSm,
              IconButton(
                icon: _envoi
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_rounded),
                tooltip: 'Ajouter à la liste',
                color: context.couleurs.primary,
                onPressed: _envoi ? null : _ajouter,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _ajouter() async {
    final String libelle = _controller.text.trim();
    if (libelle.isEmpty) return;

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _envoi = true);
    try {
      await ref.read(taskActionsProvider).addItem(widget.task.id, libelle);
      _controller.clear();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(AuthFailure.from(error).message)),
      );
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }
}

class _ArticleRow extends ConsumerWidget {
  const _ArticleRow({required this.taskId, required this.article});

  final String taskId;
  final TaskListItem article;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TaskRow(
      title: article.label,
      subtitle: article.isChecked && article.checkedByName != null
          ? 'Coché par ${article.checkedByName}'
          : null,
      done: article.isChecked,
      showDivider: false,
      onToggle: (bool value) => ref
          .read(taskActionsProvider)
          .checkItem(taskId, article.id, checked: value),
      trailing: IconButton(
        icon: const Icon(Icons.close_rounded, size: 18),
        tooltip: 'Retirer de la liste',
        color: context.couleurs.textSecondary,
        onPressed: () =>
            ref.read(taskActionsProvider).removeItem(taskId, article.id),
      ),
    );
  }
}

/// Terminer ou rouvrir : l'action la plus fréquente, donc pleine largeur.
class _ActionPrincipale extends ConsumerWidget {
  const _ActionPrincipale({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PrimaryButton(
      label: task.isDone ? 'Rouvrir la tâche' : 'Marquer comme terminée',
      icon: task.isDone ? Icons.undo_rounded : Icons.check_rounded,
      onPressed: () async {
        final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
        try {
          await ref
              .read(taskActionsProvider)
              .toggleDone(task.id, done: !task.isDone);
        } catch (error) {
          messenger.showSnackBar(
            SnackBar(content: Text(AuthFailure.from(error).message)),
          );
        }
      },
    );
  }
}
