import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../../data/data_providers.dart';
import '../../contacts/models/contact.dart';
import '../../contacts/providers/contact_providers.dart';
import '../../tasks/models/task.dart';
import '../../tasks/providers/task_providers.dart';
import '../models/group.dart';

/// Feuille de détail d'un groupe : membres et tâches ouvertes.
///
/// Plafonnée à 80 % de la hauteur d'écran pour qu'un groupe très fourni reste
/// une feuille et ne se comporte pas comme un écran plein.
class GroupDetailSheet extends ConsumerWidget {
  const GroupDetailSheet({super.key, required this.group, required this.tasks});

  final Group group;
  final List<Task> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime now = ref.watch(nowProvider);
    final List<Contact> members = ref
        .watch(contactRepositoryProvider)
        .findByIds(group.memberIds);
    final List<Task> openTasks = tasks.where((Task t) => !t.isDone).toList();

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: group.accent.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.md),
                  ),
                  child: Icon(group.icon, color: group.accent.color),
                ),
                AppSpacing.hGapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(group.name, style: AppTypography.h2),
                      Text(
                        '${group.memberCount} membre'
                        '${group.memberCount > 1 ? 's' : ''}',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (group.description != null) ...<Widget>[
              AppSpacing.gapLg,
              Text(group.description!, style: AppTypography.bodyMuted),
            ],

            AppSpacing.gapXl,
            const SectionHeader(title: 'Membres'),
            AppSpacing.gapMd,
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final Contact member in members)
                  Chip(
                    avatar: CircleAvatar(
                      backgroundColor: group.accent.color,
                      child: Text(
                        AvatarData(name: member.fullName).initials,
                        style: AppTypography.caption.copyWith(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    label: Text(member.firstName),
                  ),
              ],
            ),

            AppSpacing.gapXl,
            SectionHeader(
              title: 'Tâches ouvertes',
              subtitle: openTasks.isEmpty ? 'Aucune tâche en cours' : null,
            ),
            if (openTasks.isNotEmpty) ...<Widget>[
              AppSpacing.gapSm,
              for (int i = 0; i < openTasks.length; i++)
                TaskRow(
                  title: openTasks[i].title,
                  subtitle: openTasks[i].notes,
                  done: openTasks[i].isDone,
                  dueLabel: openTasks[i].dueDate == null
                      ? null
                      : AppDates.relativeDay(openTasks[i].dueDate!, now: now),
                  dueTone: openTasks[i].toneFor(now),
                  showDivider: i < openTasks.length - 1,
                  onToggle: (_) =>
                      ref.read(taskActionsProvider).toggleDone(openTasks[i].id),
                ),
            ],

            AppSpacing.gapXl,
            Row(
              children: <Widget>[
                Expanded(
                  child: SecondaryButton(
                    label: 'Fermer',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                AppSpacing.hGapMd,
                Expanded(
                  child: PrimaryButton(
                    label: 'Ouvrir',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: () {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Le détail complet du groupe arrive bientôt.',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
