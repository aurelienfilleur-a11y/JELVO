import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../data/data_providers.dart';
import '../../../router/app_routes.dart';
import '../../auth/models/auth_failure.dart';
import '../../auth/providers/auth_providers.dart';
import '../../groups/models/group.dart';
import '../../groups/providers/group_providers.dart';
import '../models/task.dart';
import '../providers/task_providers.dart';

/// Écran d'une tâche qui vous est confiée.
///
/// Troisième déclinaison du même motif : **qui confie** en haut, **la tâche**
/// au milieu, **Refuser / Accepter** en bas. Distinct de `TaskDetailScreen`,
/// qui sert à faire la tâche — cocher, modifier, tenir la liste — là où
/// celui-ci sert seulement à dire si on la prend.
class TaskAssignmentScreen extends ConsumerStatefulWidget {
  const TaskAssignmentScreen({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<TaskAssignmentScreen> createState() =>
      _TaskAssignmentScreenState();
}

class _TaskAssignmentScreenState extends ConsumerState<TaskAssignmentScreen> {
  bool _enCours = false;

  @override
  Widget build(BuildContext context) {
    final Task? tache = ref.watch(taskByIdProvider(widget.taskId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tâche confiée'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Retour',
          onPressed: _enCours ? null : () => _revenir(context),
        ),
      ),
      body: SafeArea(
        child: tache == null
            ? EmptyState(
                icon: Icons.task_alt_rounded,
                title: 'Tâche introuvable',
                message:
                    'Elle a été supprimée, ou vous n’y avez plus accès. Il n’y '
                    'a plus rien à accepter.',
                actionLabel: 'Revenir à l’accueil',
                onActionPressed: () => context.goNamed(AppRoutes.home),
              )
            : _corps(tache),
      ),
    );
  }

  Widget _corps(Task tache) {
    final DateTime now = ref.watch(nowProvider);
    final String? moi = ref.watch(currentUserIdProvider);
    final Group? groupe = tache.groupId == null
        ? null
        : ref.watch(groupByIdProvider(tache.groupId!));
    // `mes_taches` renvoie le nom du groupe ; la liste locale ne sert que de
    // repli, car un assigné n'est pas forcément membre.
    final String? nomDuGroupe = tache.groupName ?? groupe?.name;

    // `mon_statut` est nul quand on n'est pas assigné : il n'y a alors rien à
    // répondre, et proposer deux boutons serait proposer deux boutons sans
    // effet.
    final AssigneeStatus? statut = tache.myStatus;
    final bool aRepondre = statut == AssigneeStatus.pending;

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: <Widget>[
        // La couverture du groupe, comme sur les deux autres écrans. Une tâche
        // personnelle n'en a pas : le repli d'accent, dérivé de son
        // identifiant, tient la même place sans rien inventer.
        ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(AppSpacing.lg),
          ),
          child: CoverBanner(
            name: nomDuGroupe ?? 'Personnel',
            subtitle: tache.dueDate == null
                ? null
                : 'Échéance ${AppDates.shortDate(tache.dueDate!)}',
            accentColor: GroupAccent.forId(tache.groupId ?? tache.id).color,
            icon: Icons.task_alt_rounded,
            photoUrl: tache.groupPhotoUrl ?? groupe?.photoUrl,
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            AppSpacing.xl,
            AppSpacing.screenMargin,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              InvitationHeader(
                author: AvatarData(
                  name: tache.authorName ?? 'Un membre',
                  imageUrl: tache.authorAvatarUrl,
                ),
                // Sans auteur identifiable, la phrase se reformule sans sujet —
                // même règle que la notification système.
                action: tache.authorName == null
                    ? 'Cette tâche vous a été confiée'
                    : 'vous a confié une tâche',
                // Pas d'ancienneté : `task_assignees` ne retient pas **quand** la
                // tâche a été confiée. La date de création de la tâche s'en
                // approche, mais serait fausse pour un assigné ajouté après coup.
                now: now,
              ),

              AppSpacing.gapXl,
              EmojiText(tache.title, style: AppTypography.h2),

              AppSpacing.gapLg,
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    InvitationDetailRow(
                      icon: Icons.groups_outlined,
                      label: 'Groupe',
                      value: nomDuGroupe ?? 'Personnel',
                    ),
                    if (tache.notes != null && tache.notes!.isNotEmpty)
                      InvitationDetailRow(
                        icon: Icons.notes_rounded,
                        label: 'Description',
                        value: tache.notes!,
                      ),
                    if (tache.dueDate != null)
                      InvitationDetailRow(
                        icon: Icons.event_outlined,
                        label: 'Échéance',
                        value:
                            '${AppDates.fullDate(tache.dueDate!)} à '
                            '${AppDates.time(tache.dueDate!)}',
                      ),
                    // `task_priority` existe bel et bien : `low`, `medium`, `high`.
                    InvitationDetailRow(
                      icon: Icons.flag_outlined,
                      label: 'Priorité',
                      value: tache.priority.label,
                      dernier: true,
                    ),
                  ],
                ),
              ),

              if (tache.assignees.isNotEmpty) ...<Widget>[
                AppSpacing.gapXl,
                SectionHeader(
                  title: tache.assignees.length > 1 ? 'Assignés' : 'Assignée à',
                ),
                AppSpacing.gapMd,
                for (final TaskAssignee a in tache.assignees)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: <Widget>[
                        AvatarImage(
                          data: AvatarData(
                            name: a.displayName,
                            imageUrl: a.avatarUrl,
                          ),
                          size: 32,
                        ),
                        AppSpacing.hGapMd,
                        Expanded(
                          child: Text(
                            a.userId == moi
                                ? '${a.displayName} (vous)'
                                : a.displayName,
                            style: AppTypography.body,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        AppSpacing.hGapSm,
                        StatusDot(
                          tone: _tonPour(a.status),
                          label: a.status.label,
                        ),
                      ],
                    ),
                  ),
              ],

              if (tache.isOverdue(now)) ...<Widget>[
                AppSpacing.gapXl,
                _Bandeau(
                  icone: Icons.warning_amber_rounded,
                  couleur: AppColors.danger,
                  fond: AppColors.dangerSoft,
                  texte: 'L’échéance est déjà passée.',
                ),
              ],

              AppSpacing.gapXxl,
              if (aRepondre)
                InvitationActions(
                  refuser: 'Refuser',
                  accepter: 'Accepter',
                  enCours: _enCours,
                  onRefuser: () => _repondre(tache, AssigneeStatus.declined),
                  onAccepter: () => _repondre(tache, AssigneeStatus.accepted),
                )
              else ...<Widget>[
                _Bandeau(
                  icone: statut == null
                      ? Icons.info_outline_rounded
                      : Icons.how_to_reg_rounded,
                  couleur: statut == AssigneeStatus.declined
                      ? AppColors.textSecondary
                      : AppColors.success,
                  fond: statut == AssigneeStatus.declined
                      ? AppColors.border
                      : AppColors.successSoft,
                  texte: switch (statut) {
                    AssigneeStatus.accepted => 'Vous avez accepté cette tâche.',
                    AssigneeStatus.declined => 'Vous avez décliné cette tâche.',
                    AssigneeStatus.done => 'Vous avez terminé votre part.',
                    AssigneeStatus.pending ||
                    null => 'Cette tâche ne vous est pas assignée.',
                  },
                ),
                AppSpacing.gapLg,
                PrimaryButton(
                  label: 'Ouvrir la tâche',
                  onPressed: () => context.pushReplacementNamed(
                    AppRoutes.taskDetail,
                    pathParameters: <String, String>{'id': tache.id},
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static StatusTone _tonPour(AssigneeStatus statut) => switch (statut) {
    AssigneeStatus.accepted => StatusTone.info,
    AssigneeStatus.declined => StatusTone.danger,
    AssigneeStatus.done => StatusTone.success,
    AssigneeStatus.pending => StatusTone.neutral,
  };

  static void _revenir(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(AppRoutes.home);
    }
  }

  Future<void> _repondre(Task tache, AssigneeStatus statut) async {
    final ScaffoldMessengerState messager = ScaffoldMessenger.of(context);

    setState(() => _enCours = true);
    try {
      await ref.read(taskActionsProvider).respond(tache.id, statut);
      messager.showSnackBar(
        SnackBar(
          content: Text(
            statut == AssigneeStatus.accepted
                ? 'Tâche acceptée.'
                : 'Tâche déclinée.',
          ),
        ),
      );
    } catch (error) {
      messager.showSnackBar(
        SnackBar(content: Text(AuthFailure.from(error).message)),
      );
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }
}

/// Un pavé teinté : icône et texte.
class _Bandeau extends StatelessWidget {
  const _Bandeau({
    required this.icone,
    required this.couleur,
    required this.fond,
    required this.texte,
  });

  final IconData icone;
  final Color couleur;
  final Color fond;
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: AppRadii.fieldRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icone, size: 18, color: couleur),
          AppSpacing.hGapSm,
          Expanded(
            child: Text(
              texte,
              style: AppTypography.caption.copyWith(color: AppColors.midnight),
            ),
          ),
        ],
      ),
    );
  }
}
