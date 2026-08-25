import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../data/data_providers.dart';
import '../../../router/app_routes.dart';
import '../../calendar/models/agenda_entry.dart';
import '../../calendar/providers/calendar_providers.dart';
import '../../groups/models/group.dart';
import '../../groups/providers/group_providers.dart';
import '../../notifications/providers/notification_providers.dart';
import '../../profile/models/profile.dart';
import '../../profile/providers/profile_providers.dart';
import '../../tasks/models/task.dart';
import '../../tasks/widgets/task_tile.dart';
import '../providers/home_providers.dart';
import '../widgets/agenda_card.dart';
import '../widgets/group_strip.dart';
import '../widgets/tasks_card.dart';
import '../widgets/week_overview.dart';

/// Écran d'accueil.
///
/// Quatre blocs, dans cet ordre : l'en-tête qui dit à qui l'on parle et quel
/// jour on est, la bande des groupes, la journée en cours, puis les tâches.
/// L'ordre n'est pas décoratif — il descend du « où suis-je » vers le « qu'ai-je
/// à faire », et c'est la première moitié qu'on regarde en ouvrant.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime now = ref.watch(nowProvider);
    final Profile? profil = ref.watch(currentProfileProvider).value;
    final List<Group> groups = ref.watch(activeGroupsProvider);
    final List<AgendaEntry> agenda = ref.watch(todayAgendaProvider);
    final List<Task> focusTasks = ref.watch(homeTaskRowsProvider);

    return AppScreen(
      // Pas d'emoji dans le titre, contrairement à la maquette : sans police
      // emoji installée, le glyphe manquant s'affiche en carré « tofu » au
      // tout premier écran.
      title: _salutation(ref, profil),
      subtitle: AppDates.dayAndMonth(now),
      leading: _Avatar(profil: profil),
      headerAction: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          NavBadge(
            count: ref.watch(unreadCountProvider),
            child: AppScreenAction(
              icon: Icons.notifications_none_rounded,
              tooltip: 'Notifications',
              onPressed: () => context.pushNamed(AppRoutes.notifications),
            ),
          ),
          AppSpacing.hGapSm,
          AppScreenAction(
            icon: Icons.calendar_today_rounded,
            tooltip: 'Calendrier',
            accented: true,
            onPressed: () => context.goNamed(AppRoutes.calendar),
          ),
        ],
      ),
      slivers: <Widget>[
        // La semaine reste sous l'en-tête. Elle ne figure pas sur la maquette,
        // mais c'est le seul endroit d'où l'on ouvre le calendrier à une date
        // précise, et elle est éprouvée par les tests.
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            0,
            AppSpacing.screenMargin,
            AppSpacing.lg,
          ),
          sliver: SliverToBoxAdapter(
            child: WeekOverview(
              days: ref.watch(currentWeekProvider),
              today: now,
              onDaySelected: (DateTime jour) {
                ref.read(selectedDayProvider.notifier).select(jour);
                context.goNamed(AppRoutes.calendar);
              },
            ),
          ),
        ),

        // — Mes groupes —
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            0,
            AppSpacing.screenMargin,
            AppSpacing.md,
          ),
          sliver: SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Mes groupes',
              actionLabel: groups.isEmpty ? null : 'Voir tout',
              onActionPressed: groups.isEmpty
                  ? null
                  : () => context.goNamed(AppRoutes.groups),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: groups.isEmpty
              ? Padding(
                  padding: AppSpacing.screenHorizontal,
                  child: EmptyState(
                    icon: Icons.groups_2_outlined,
                    title: 'Aucun groupe pour le moment',
                    message:
                        'Créez un groupe pour partager un agenda, des tâches '
                        'et une conversation.',
                    actionLabel: 'Créer un groupe',
                    onActionPressed: () =>
                        context.pushNamed(AppRoutes.groupCreate),
                  ),
                )
              : GroupStrip(
                  groups: groups,
                  onOpen: (Group group) => context.pushNamed(
                    AppRoutes.groupDetail,
                    pathParameters: <String, String>{'id': group.id},
                  ),
                ),
        ),

        // — Mon agenda —
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            AppSpacing.lg,
            AppSpacing.screenMargin,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: AgendaCard(
              entries: agenda,
              onOpenCalendar: () => context.goNamed(AppRoutes.calendar),
              onOpenEntry: (AgendaEntry entry) => _ouvrir(context, entry),
            ),
          ),
        ),

        // — Mes tâches —
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            AppSpacing.lg,
            AppSpacing.screenMargin,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: TasksCard(
              counts: ref.watch(taskCountsProvider),
              onOpenTasks: () => context.pushNamed(AppRoutes.tasks),
              rows: <Widget>[
                for (int i = 0; i < focusTasks.length; i++)
                  _TacheDAccueil(
                    task: focusTasks[i],
                    now: now,
                    showDivider: i < focusTasks.length - 1,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// « Bonjour Camille », ou « Bonjour » seul tant que le profil se charge.
  ///
  /// Le prénom n'est pas attendu : un écran qui reste blanc le temps d'une
  /// lecture réseau donne l'impression d'une application lente, alors que la
  /// salutation seule est déjà juste.
  static String _salutation(WidgetRef ref, Profile? profil) {
    final String base = ref.watch(greetingProvider);
    final String prenom = profil?.firstName.trim() ?? '';
    return prenom.isEmpty ? base : '$base $prenom';
  }

  static void _ouvrir(BuildContext context, AgendaEntry entry) {
    switch (entry.kind) {
      case AgendaEntryKind.task:
        context.pushNamed(
          AppRoutes.taskDetail,
          pathParameters: <String, String>{'id': entry.id},
        );
      case AgendaEntryKind.groupEvent:
      case AgendaEntryKind.personalEvent:
        context.pushNamed(
          AppRoutes.eventDetail,
          pathParameters: <String, String>{'id': entry.id},
        );
      case AgendaEntryKind.availability:
        break;
    }
  }
}

/// Photo de profil de l'en-tête, qui ouvre le profil.
///
/// **Pas de pastille de présence**, contrairement à la maquette : Jelvo ne
/// sait pas qui est en ligne. `profiles.last_seen_at` existe mais n'est écrit
/// nulle part, et une pastille verte permanente serait un mensonge.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.profil});

  final Profile? profil;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Profil',
      child: InkWell(
        onTap: () => context.pushNamed(AppRoutes.profile),
        customBorder: const CircleBorder(),
        child: AvatarImage(
          data: AvatarData(
            name: profil?.displayName ?? 'Vous',
            imageUrl: profil?.avatarAAfficher,
          ),
          size: 52,
        ),
      ),
    );
  }
}

/// Ligne de tâche de l'accueil : le nom du groupe en sous-titre.
class _TacheDAccueil extends ConsumerWidget {
  const _TacheDAccueil({
    required this.task,
    required this.now,
    required this.showDivider,
  });

  final Task task;
  final DateTime now;
  final bool showDivider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Group? group = task.groupId == null
        ? null
        : ref.watch(groupByIdProvider(task.groupId!));

    return TaskTile(
      task: task,
      now: now,
      groupName: group?.name,
      showDivider: showDivider,
    );
  }
}
