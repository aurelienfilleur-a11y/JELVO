import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../router/app_routes.dart';
import '../../contacts/providers/contact_providers.dart';
import '../../tasks/models/task.dart';
import '../../tasks/providers/task_providers.dart';
import '../models/group.dart';
import '../providers/group_providers.dart';
import '../widgets/group_detail_sheet.dart';

/// Écran Groupes : liste des groupes de l'utilisateur, triés par activité.
class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Group>> groupsAsync = ref.watch(groupsProvider);
    final List<Group> groups = ref.watch(activeGroupsProvider);

    return AppScreen(
      title: 'Groupes',
      subtitle: 'Partagez agenda et tâches avec vos proches.',
      headerAction: AppScreenAction(
        icon: Icons.add_rounded,
        tooltip: 'Nouveau groupe',
        onPressed: () => context.pushNamed(AppRoutes.create),
      ),
      slivers: <Widget>[
        if (groupsAsync.isLoading && groups.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (groups.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.groups_rounded,
              title: 'Aucun groupe pour le moment',
              message:
                  'Créez un groupe pour partager un agenda et répartir les tâches.',
              actionLabel: 'Créer un groupe',
              onActionPressed: () => context.pushNamed(AppRoutes.create),
            ),
          )
        else ...<Widget>[
          SliverPadding(
            padding: AppSpacing.screenHorizontal,
            sliver: SliverToBoxAdapter(
              child: SectionHeader(
                title: '${groups.length} groupe${groups.length > 1 ? 's' : ''}',
                subtitle: 'Triés par activité récente',
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
                final List<Task> tasks = ref.watch(
                  tasksForGroupProvider(group.id),
                );

                return GroupCard(
                  name: group.name,
                  description: group.description,
                  icon: group.icon,
                  accentColor: group.accent.color,
                  members: ref.watch(avatarsForContactIdsProvider)(
                    group.memberIds,
                  ),
                  trailingLabel: group.activityLabel,
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) =>
                        GroupDetailSheet(group: group, tasks: tasks),
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
