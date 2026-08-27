import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../data/data_providers.dart';
import '../../../router/app_routes.dart';
import '../../auth/models/auth_failure.dart';
import '../models/group.dart';
import '../models/group_invite.dart';
import '../providers/group_providers.dart';

/// Liste des invitations nominatives en attente.
class InvitationsScreen extends ConsumerWidget {
  const InvitationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<GroupInvitation>> invitationsAsync = ref.watch(
      invitationsProvider,
    );
    final List<GroupInvitation> invitations =
        invitationsAsync.value ?? const <GroupInvitation>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Invitations'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Retour',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: switch (invitationsAsync) {
          AsyncValue<List<GroupInvitation>>(isLoading: true)
              when invitations.isEmpty =>
            const Center(child: CircularProgressIndicator()),
          AsyncValue<List<GroupInvitation>>(
            hasError: true,
            :final Object? error,
          )
              when invitations.isEmpty =>
            EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Invitations indisponibles',
              message: AuthFailure.from(error!).message,
              actionLabel: 'Réessayer',
              onActionPressed: () =>
                  ref.read(invitationsProvider.notifier).refresh(),
            ),
          _ when invitations.isEmpty => const EmptyState(
            icon: Icons.mark_email_read_outlined,
            title: 'Aucune invitation',
            message:
                'Quand un proche vous invitera dans un groupe, l’invitation '
                'apparaîtra ici.',
          ),
          _ => ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenMargin,
              AppSpacing.lg,
              AppSpacing.screenMargin,
              AppSpacing.xxl,
            ),
            itemCount: invitations.length,
            separatorBuilder: (_, _) => AppSpacing.gapMd,
            itemBuilder: (BuildContext context, int index) {
              final GroupInvitation invitation = invitations[index];
              return GroupCard(
                name: invitation.groupName,
                memberLabel: invitation.memberLabel,
                activityLabel: 'Invitation de ${invitation.senderName}',
                onTap: () => context.pushNamed(
                  AppRoutes.invitation,
                  pathParameters: <String, String>{'id': invitation.id},
                ),
              );
            },
          ),
        },
      ),
    );
  }
}

/// Écran d'une invitation à un groupe.
///
/// Trois blocs, comme les deux autres écrans d'invitation : **qui invite** en
/// haut, **le groupe** au milieu, **les deux réponses** en bas.
///
/// Il se branche sur `invitationDetailProvider` et non sur la liste des
/// invitations en attente : celle-ci ne renvoie que les `pending`, si bien
/// qu'une invitation acceptée, refusée, expirée ou dont le groupe a été
/// supprimé n'y figurait plus, et que les quatre cas se disaient
/// « Invitation introuvable » — le mot le plus vague pour les quatre.
class InvitationScreen extends ConsumerStatefulWidget {
  const InvitationScreen({super.key, required this.invitationId});

  final String invitationId;

  @override
  ConsumerState<InvitationScreen> createState() => _InvitationScreenState();
}

class _InvitationScreenState extends ConsumerState<InvitationScreen> {
  bool _enCours = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<GroupInvitationDetail> detailAsync = ref.watch(
      invitationDetailProvider(widget.invitationId),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Invitation'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Retour',
          onPressed: _enCours ? null : () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: switch (detailAsync) {
          AsyncValue<GroupInvitationDetail>(isLoading: true) => const Center(
            child: CircularProgressIndicator(),
          ),
          AsyncValue<GroupInvitationDetail>(
            hasError: true,
            :final Object? error,
          ) =>
            EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Invitation indisponible',
              message: AuthFailure.from(error!).message,
              actionLabel: 'Réessayer',
              onActionPressed: () =>
                  ref.invalidate(invitationDetailProvider(widget.invitationId)),
            ),
          AsyncValue<GroupInvitationDetail>(:final GroupInvitationDetail? value)
              when value != null =>
            _corps(value),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }

  Widget _corps(GroupInvitationDetail invitation) {
    final DateTime now = ref.watch(nowProvider);

    // Ni contexte ni groupe : il n'y a rien à montrer sous le message.
    if (!invitation.status.gardeLeContexte) {
      return EmptyState(
        icon: invitation.status.icone,
        title: invitation.status.titre,
        message: invitation.status.message,
        actionLabel: 'Revenir aux groupes',
        onActionPressed: () => context.goNamed(AppRoutes.groups),
      );
    }

    final Color accent = invitation.groupId == null
        ? AppColors.primary
        : GroupAccent.forId(invitation.groupId!).color;

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: <Widget>[
        ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(AppSpacing.lg),
          ),
          child: CoverBanner(
            name: invitation.displayGroupName,
            subtitle: invitation.memberLabel,
            accentColor: accent,
            icon: Icons.groups_rounded,
            photoUrl: invitation.photoUrl,
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
                  name: invitation.displaySender,
                  imageUrl: invitation.senderAvatarUrl,
                ),
                action: 'vous invite à rejoindre un groupe',
                since: invitation.createdAt,
                now: now,
              ),

              AppSpacing.gapXl,
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (invitation.description != null &&
                        invitation.description!.isNotEmpty)
                      InvitationDetailRow(
                        icon: Icons.notes_rounded,
                        label: 'Description',
                        value: invitation.description!,
                      ),
                    InvitationDetailRow(
                      icon: Icons.group_outlined,
                      label: 'Membres',
                      value: invitation.memberLabel,
                      dernier: invitation.groupCreatedAt == null,
                    ),
                    if (invitation.groupCreatedAt != null)
                      InvitationDetailRow(
                        icon: Icons.cake_outlined,
                        label: 'Créé le',
                        value: AppDates.fullDate(invitation.groupCreatedAt!),
                        dernier: true,
                      ),
                  ],
                ),
              ),

              if (invitation.members.isNotEmpty) ...<Widget>[
                AppSpacing.gapXl,
                SectionHeader(
                  title: 'Déjà dans le groupe',
                  subtitle: invitation.memberLabel,
                ),
                AppSpacing.gapMd,
                Row(
                  children: <Widget>[
                    AvatarStack(
                      avatars: invitation.members
                          .map(
                            (InvitationMember m) =>
                                AvatarData(name: m.name, imageUrl: m.avatarUrl),
                          )
                          .toList(),
                      size: 36,
                    ),
                    AppSpacing.hGapMd,
                    Expanded(
                      child: Text(
                        invitation.members
                            .map((InvitationMember m) => m.name)
                            .join(', '),
                        style: AppTypography.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              // Annoncé avant les boutons, et non après : ce qui change la
              // nature de l'offre se lit avant d'y répondre.
              if (invitation.membershipExpiresAt != null) ...<Widget>[
                AppSpacing.gapXl,
                _Bandeau(
                  icone: Icons.schedule_rounded,
                  couleur: AppColors.warning,
                  fond: AppColors.warningSoft,
                  texte:
                      'Adhésion temporaire : jusqu’au '
                      '${AppDates.fullDate(invitation.membershipExpiresAt!)}.',
                ),
              ],

              AppSpacing.gapXxl,
              if (invitation.status.peutRepondre)
                InvitationActions(
                  refuser: 'Refuser',
                  accepter: 'Rejoindre',
                  enCours: _enCours,
                  onRefuser: () => _refuser(invitation),
                  onAccepter: () => _accepter(invitation),
                )
              else
                _Denouement(
                  statut: invitation.status,
                  onOuvrirLeGroupe: invitation.groupId == null
                      ? null
                      : () => context.goNamed(
                          AppRoutes.groupDetail,
                          pathParameters: <String, String>{
                            'id': invitation.groupId!,
                          },
                        ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _accepter(GroupInvitationDetail invitation) async {
    final ScaffoldMessengerState messager = ScaffoldMessenger.of(context);
    final GoRouter routeur = GoRouter.of(context);
    final String? id = invitation.id;
    if (id == null) return;

    setState(() => _enCours = true);
    try {
      final JoinOutcome resultat = await ref
          .read(groupActionsProvider)
          .acceptInvitation(id);
      messager.showSnackBar(SnackBar(content: Text(resultat.message)));

      if (resultat.isSuccess && invitation.groupId != null) {
        routeur.goNamed(
          AppRoutes.groupDetail,
          pathParameters: <String, String>{'id': invitation.groupId!},
        );
      } else {
        // Refus de la base : l'écran doit repartir de l'état réel plutôt que
        // de garder deux boutons qui viennent de ne rien faire.
        ref.invalidate(invitationDetailProvider(widget.invitationId));
      }
    } catch (error) {
      messager.showSnackBar(
        SnackBar(content: Text(AuthFailure.from(error).message)),
      );
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _refuser(GroupInvitationDetail invitation) async {
    final ScaffoldMessengerState messager = ScaffoldMessenger.of(context);
    final NavigatorState navigateur = Navigator.of(context);
    final String? id = invitation.id;
    if (id == null) return;

    setState(() => _enCours = true);
    try {
      await ref.read(groupActionsProvider).declineInvitation(id);
      messager.showSnackBar(
        const SnackBar(content: Text('Invitation refusée.')),
      );
      navigateur.maybePop();
    } catch (error) {
      messager.showSnackBar(
        SnackBar(content: Text(AuthFailure.from(error).message)),
      );
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }
}

/// Ce qui remplace les deux boutons quand l'invitation ne se répond plus.
///
/// **Jamais de bouton sans effet.** Une invitation déjà acceptée n'ouvre pas
/// « Rejoindre » grisé : elle dit ce qui s'est passé, et propose la seule
/// suite qui a du sens — ouvrir le groupe.
class _Denouement extends StatelessWidget {
  const _Denouement({required this.statut, this.onOuvrirLeGroupe});

  final InvitationScreenStatus statut;
  final VoidCallback? onOuvrirLeGroupe;

  @override
  Widget build(BuildContext context) {
    final bool membre =
        statut == InvitationScreenStatus.acceptee ||
        statut == InvitationScreenStatus.dejaMembre;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Bandeau(
          icone: statut.icone,
          couleur: membre ? AppColors.success : AppColors.textSecondary,
          fond: membre ? AppColors.successSoft : AppColors.border,
          titre: statut.titre,
          texte: statut.message,
        ),
        if (membre && onOuvrirLeGroupe != null) ...<Widget>[
          AppSpacing.gapLg,
          PrimaryButton(label: 'Ouvrir le groupe', onPressed: onOuvrirLeGroupe),
        ],
      ],
    );
  }
}

/// Un pavé teinté : icône, titre facultatif, texte.
class _Bandeau extends StatelessWidget {
  const _Bandeau({
    required this.icone,
    required this.couleur,
    required this.fond,
    required this.texte,
    this.titre,
  });

  final IconData icone;
  final Color couleur;
  final Color fond;
  final String texte;
  final String? titre;

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (titre != null) ...<Widget>[
                  Text(
                    titre!,
                    style: AppTypography.body.copyWith(
                      fontWeight: AppTypography.semiBold,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  texte,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.midnight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
