import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../data/data_providers.dart';
import '../../../router/app_routes.dart';
import '../../auth/models/auth_failure.dart';
import '../models/group_invite.dart';
import '../providers/group_providers.dart';
import '../widgets/group_banner.dart';

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
                description: 'Invitation de ${invitation.senderName}',
                trailingLabel: invitation.memberLabel,
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

/// Écran d'une invitation : émetteur, groupe, description, membres, et les
/// deux seules réponses possibles.
class InvitationScreen extends ConsumerStatefulWidget {
  const InvitationScreen({super.key, required this.invitationId});

  final String invitationId;

  @override
  ConsumerState<InvitationScreen> createState() => _InvitationScreenState();
}

class _InvitationScreenState extends ConsumerState<InvitationScreen> {
  bool _working = false;

  @override
  Widget build(BuildContext context) {
    final List<GroupInvitation> invitations =
        ref.watch(invitationsProvider).value ?? const <GroupInvitation>[];
    final DateTime now = ref.watch(nowProvider);

    GroupInvitation? invitation;
    for (final GroupInvitation candidate in invitations) {
      if (candidate.id == widget.invitationId) invitation = candidate;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Invitation'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Retour',
          onPressed: _working ? null : () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: invitation == null
            ? EmptyState(
                icon: Icons.mail_outline_rounded,
                title: 'Invitation introuvable',
                message:
                    'Cette invitation a été annulée, ou vous y avez déjà '
                    'répondu.',
                actionLabel: 'Revenir aux groupes',
                onActionPressed: () => context.goNamed(AppRoutes.groups),
              )
            : _content(invitation, now),
      ),
    );
  }

  Widget _content(GroupInvitation invitation, DateTime now) {
    final bool expired = invitation.isExpired(now);

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: <Widget>[
        ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(AppSpacing.lg),
          ),
          child: GroupBanner(
            name: invitation.groupName,
            subtitle: invitation.memberLabel,
            accentColor: AppColors.primary,
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
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: <Widget>[
                    AvatarStack(
                      avatars: <AvatarData>[
                        AvatarData(
                          name: invitation.senderName,
                          imageUrl: invitation.senderAvatarUrl,
                        ),
                      ],
                      size: 40,
                    ),
                    AppSpacing.hGapMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            invitation.senderName,
                            style: AppTypography.body.copyWith(
                              fontWeight: AppTypography.semiBold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'vous invite à rejoindre ce groupe',
                            style: AppTypography.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Annoncé avant les deux boutons, et non après : ce qui change
              // la nature de l'offre se lit avant d'y répondre.
              if (invitation.membershipExpiresAt != null) ...<Widget>[
                AppSpacing.gapXl,
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.warningSoft,
                    borderRadius: AppRadii.fieldRadius,
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.schedule_rounded,
                        size: 18,
                        color: AppColors.warning,
                      ),
                      AppSpacing.hGapSm,
                      Expanded(
                        child: Text(
                          'Adhésion temporaire : jusqu’au '
                          '${AppDates.fullDate(invitation.membershipExpiresAt!)}.',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.midnight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (invitation.description != null &&
                  invitation.description!.isNotEmpty) ...<Widget>[
                AppSpacing.gapXl,
                const SectionHeader(title: 'À propos du groupe'),
                AppSpacing.gapSm,
                Text(invitation.description!, style: AppTypography.bodyMuted),
              ],

              if (invitation.memberNames.isNotEmpty) ...<Widget>[
                AppSpacing.gapXl,
                SectionHeader(
                  title: 'Membres',
                  subtitle: invitation.memberLabel,
                ),
                AppSpacing.gapMd,
                Row(
                  children: <Widget>[
                    AvatarStack(
                      avatars: invitation.memberNames
                          .map((String n) => AvatarData(name: n))
                          .toList(),
                      size: 36,
                    ),
                    AppSpacing.hGapMd,
                    Expanded(
                      child: Text(
                        invitation.memberNames.join(', '),
                        style: AppTypography.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              if (expired) ...<Widget>[
                AppSpacing.gapXl,
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.warningSoft,
                    borderRadius: AppRadii.fieldRadius,
                  ),
                  child: Text(
                    'Cette invitation a expiré. Demandez-en une nouvelle au '
                    'groupe.',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],

              AppSpacing.gapXxl,
              Row(
                children: <Widget>[
                  Expanded(
                    child: SecondaryButton(
                      label: 'Refuser',
                      isDestructive: true,
                      onPressed: _working ? null : () => _decline(invitation),
                    ),
                  ),
                  AppSpacing.hGapMd,
                  Expanded(
                    child: PrimaryButton(
                      label: 'Rejoindre',
                      isLoading: _working,
                      onPressed: expired ? null : () => _accept(invitation),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _accept(GroupInvitation invitation) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final GoRouter router = GoRouter.of(context);

    setState(() => _working = true);
    try {
      final JoinOutcome outcome = await ref
          .read(groupActionsProvider)
          .acceptInvitation(invitation.id);
      messenger.showSnackBar(SnackBar(content: Text(outcome.message)));

      if (outcome.isSuccess) {
        router.goNamed(
          AppRoutes.groupDetail,
          pathParameters: <String, String>{'id': invitation.groupId},
        );
      }
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(AuthFailure.from(error).message)),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _decline(GroupInvitation invitation) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);

    setState(() => _working = true);
    try {
      await ref.read(groupActionsProvider).declineInvitation(invitation.id);
      messenger.showSnackBar(
        const SnackBar(content: Text('Invitation refusée.')),
      );
      navigator.maybePop();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(AuthFailure.from(error).message)),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }
}
