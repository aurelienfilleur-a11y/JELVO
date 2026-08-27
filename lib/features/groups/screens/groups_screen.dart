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
class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  final TextEditingController _recherche = TextEditingController();

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Group>> groupsAsync = ref.watch(myGroupsProvider);
    final List<Group> tous = ref.watch(activeGroupsProvider);
    final List<Group> groups = ref.watch(filteredGroupsProvider);
    final String terme = ref.watch(groupQueryProvider);
    final List<GroupInvitation> invitations =
        ref.watch(invitationsProvider).value ?? const <GroupInvitation>[];

    return AppScreen(
      title: 'Mes groupes',
      headerAction: AppScreenAction(
        icon: Icons.add_rounded,
        tooltip: 'Nouveau groupe',
        accented: true,
        onPressed: () => context.pushNamed(AppRoutes.groupCreate),
      ),
      slivers: <Widget>[
        // La recherche n'apparaît qu'à partir de trois groupes : en deçà, la
        // liste tient à l'écran et un champ vide ne ferait que la repousser.
        if (tous.length >= 3)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenMargin,
              0,
              AppSpacing.screenMargin,
              AppSpacing.lg,
            ),
            sliver: SliverToBoxAdapter(
              child: AppTextField(
                hint: 'Rechercher un groupe',
                controller: _recherche,
                prefixIcon: Icons.search_rounded,
                suffixIcon: terme.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.cancel_rounded, size: 20),
                        color: AppColors.textSecondary,
                        tooltip: 'Effacer la recherche',
                        onPressed: () {
                          _recherche.clear();
                          ref.read(groupQueryProvider.notifier).set('');
                        },
                      ),
                onChanged: (String valeur) =>
                    ref.read(groupQueryProvider.notifier).set(valeur),
              ),
            ),
          ),

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
        // **Deux vides, deux causes.** Aucun groupe appelle à en créer un ;
        // une recherche sans résultat appelle à la corriger. Confondre les
        // deux proposerait de créer « Corse » à quelqu'un qui l'a déjà.
        else if (tous.isEmpty)
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
        else if (groups.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.search_off_rounded,
              title: 'Aucun groupe à ce nom',
              message: 'Aucun de vos groupes ne correspond à « $terme ».',
              actionLabel: 'Effacer la recherche',
              onActionPressed: () {
                _recherche.clear();
                ref.read(groupQueryProvider.notifier).set('');
              },
            ),
          )
        else
          SliverPadding(
            padding: AppSpacing.screenHorizontal,
            sliver: SliverList.separated(
              itemCount: groups.length,
              separatorBuilder: (_, _) => AppSpacing.gapLg,
              itemBuilder: (BuildContext context, int index) {
                final Group group = groups[index];
                return GroupCard(
                  name: group.name,
                  icon: group.icon,
                  accentColor: group.accent.color,
                  photoUrl: group.photoUrl,
                  members: group.memberPreviews,
                  hiddenMembers: group.hiddenMemberCount,
                  memberLabel: group.memberLabel,
                  activityLabel: ref.watch(groupActivityProvider(group.id)),
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
