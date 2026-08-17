import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../router/app_routes.dart';
import '../../chat/providers/chat_providers.dart';
import '../../auth/models/auth_failure.dart';
import '../models/group.dart';
import '../models/group_invite.dart';
import '../providers/group_providers.dart';

/// Écran Groupes : invitations reçues, puis groupes de l'utilisateur.
class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Group>> groupsAsync = ref.watch(myGroupsProvider);
    final List<Group> groups = ref.watch(activeGroupsProvider);
    final List<GroupInvitation> invitations =
        ref.watch(invitationsProvider).value ?? const <GroupInvitation>[];

    return AppScreen(
      title: 'Groupes',
      subtitle: 'Partagez agenda et tâches avec vos proches.',
      headerAction: AppScreenAction(
        icon: Icons.add_rounded,
        tooltip: 'Nouveau groupe',
        onPressed: () => context.pushNamed(AppRoutes.groupCreate),
      ),
      slivers: <Widget>[
        if (invitations.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenMargin,
              0,
              AppSpacing.screenMargin,
              AppSpacing.xl,
            ),
            sliver: SliverToBoxAdapter(
              child: _InvitationsBanner(count: invitations.length),
            ),
          ),

        if (groupsAsync.isLoading && groups.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (groupsAsync.hasError && groups.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Groupes indisponibles',
              message: AuthFailure.from(groupsAsync.error!).message,
              actionLabel: 'Réessayer',
              onActionPressed: () =>
                  ref.read(myGroupsProvider.notifier).refresh(),
            ),
          )
        else if (groups.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.groups_rounded,
              title: 'Aucun groupe pour le moment',
              message:
                  'Créez un groupe pour partager un agenda et répartir les '
                  'tâches avec vos proches.',
              actionLabel: 'Créer un groupe',
              onActionPressed: () => context.pushNamed(AppRoutes.groupCreate),
            ),
          )
        else ...<Widget>[
          SliverPadding(
            padding: AppSpacing.screenHorizontal,
            sliver: SliverToBoxAdapter(
              child: SectionHeader(
                title: '${groups.length} groupe${groups.length > 1 ? 's' : ''}',
                subtitle: 'Par ordre alphabétique',
              ),
            ),
          ),
          const SliverToBoxAdapter(child: AppSpacing.gapMd),
          SliverPadding(
            padding: AppSpacing.screenHorizontal,
            sliver: SliverList.separated(
              itemCount: groups.length,
              separatorBuilder: (_, _) => AppSpacing.gapMd,
              itemBuilder: (BuildContext context, int index) {
                final Group group = groups[index];
                return GroupCard(
                  name: group.name,
                  description: group.description,
                  icon: group.icon,
                  accentColor: group.accent.color,
                  trailingLabel: group.memberLabel,
                  // Savoir *lequel* est actif, pas seulement qu'il se passe
                  // quelque chose quelque part.
                  unreadCount: ref.watch(unreadForGroupProvider(group.id)),
                  onTap: () => context.pushNamed(
                    AppRoutes.groupDetail,
                    pathParameters: <String, String>{'id': group.id},
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

/// Bandeau menant aux invitations en attente.
class _InvitationsBanner extends StatelessWidget {
  const _InvitationsBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.pushNamed(AppRoutes.invitations),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppSpacing.md),
            ),
            child: const Icon(
              Icons.mark_email_unread_outlined,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '$count invitation${count > 1 ? 's' : ''} en attente',
                  style: AppTypography.body.copyWith(
                    fontWeight: AppTypography.semiBold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'On vous a invité à rejoindre un groupe.',
                  style: AppTypography.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
