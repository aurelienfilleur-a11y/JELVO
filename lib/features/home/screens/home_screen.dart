import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../data/data_providers.dart';
import '../../../router/app_routes.dart';
import '../../calendar/models/calendar_event.dart';
import '../../calendar/providers/calendar_providers.dart';
import '../../groups/models/group.dart';
import '../../groups/providers/group_providers.dart';
import '../../notifications/providers/notification_providers.dart';
import '../../tasks/models/task.dart';
import '../../tasks/providers/task_providers.dart';
import '../../tasks/widgets/task_tile.dart';
import '../providers/home_providers.dart';
import '../widgets/summary_banner.dart';
import '../widgets/week_overview.dart';

/// Écran d'accueil : résumé du jour, agenda, tâches urgentes et groupes actifs.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime now = ref.watch(nowProvider);
    final HomeSummary summary = ref.watch(homeSummaryProvider);
    final List<CalendarEvent> todayEvents = ref.watch(todayEventsProvider);
    final List<Task> focusTasks = ref.watch(focusTasksProvider);
    final List<Group> groups = ref.watch(activeGroupsProvider);

    return AppScreen(
      // Pas d'emoji dans le titre : sans police emoji installée, le glyphe
      // manquant s'affiche en carré « tofu » au tout premier écran.
      title: ref.watch(greetingProvider),
      subtitle: 'Voici votre journée en un coup d’œil.',
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
            icon: Icons.person_outline_rounded,
            tooltip: 'Profil',
            onPressed: () => context.pushNamed(AppRoutes.profile),
          ),
        ],
      ),
      slivers: <Widget>[
        SliverPadding(
          padding: AppSpacing.screenHorizontal,
          sliver: SliverToBoxAdapter(
            child: SummaryBanner(
              summary: summary,
              dateLabel: AppDates.fullDate(now),
              onEventsPressed: () => context.goNamed(AppRoutes.calendar),
              onTasksPressed: () => context.pushNamed(AppRoutes.tasks),
              onGroupsPressed: () => context.goNamed(AppRoutes.groups),
            ),
          ),
        ),

        // La semaine d'un coup d'œil, sous le bandeau : c'est la première
        // chose qu'on veut voir en ouvrant l'application.
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            AppSpacing.md,
            AppSpacing.screenMargin,
            0,
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

        _sectionSliver(
          SectionHeader(
            title: "Aujourd'hui",
            subtitle: todayEvents.isEmpty
                ? 'Aucun événement prévu'
                : '${todayEvents.length} événement${todayEvents.length > 1 ? 's' : ''}',
            actionLabel: 'Calendrier',
            onActionPressed: () => context.goNamed(AppRoutes.calendar),
          ),
        ),
        if (todayEvents.isEmpty)
          const SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.event_available_rounded,
              title: 'Journée libre',
              message: 'Rien n’est encore planifié pour aujourd’hui.',
            ),
          )
        else
          _cardListSliver(
            count: todayEvents.length,
            builder: (BuildContext context, int index) {
              final CalendarEvent event = todayEvents[index];
              return _EventTile(event: event);
            },
          ),

        _sectionSliver(
          SectionHeader(
            title: 'À faire bientôt',
            subtitle: focusTasks.isEmpty
                ? 'Rien d’urgent'
                : '${focusTasks.length} tâche${focusTasks.length > 1 ? 's' : ''} à échéance proche',
          ),
        ),
        if (focusTasks.isEmpty)
          const SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.task_alt_rounded,
              title: 'Tout est à jour',
              message: 'Aucune tâche n’arrive à échéance dans les 48 heures.',
            ),
          )
        else
          SliverPadding(
            padding: AppSpacing.screenHorizontal,
            sliver: SliverToBoxAdapter(
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  children: <Widget>[
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
          ),

        _sectionSliver(
          SectionHeader(
            title: 'Mes groupes',
            subtitle: 'Les plus actifs en ce moment',
            actionLabel: 'Tout voir',
            onActionPressed: () => context.goNamed(AppRoutes.groups),
          ),
        ),
        _cardListSliver(
          count: groups.length > 2 ? 2 : groups.length,
          builder: (BuildContext context, int index) =>
              _GroupTile(group: groups[index]),
        ),
      ],
    );
  }

  /// En-tête de section, avec l'espacement vertical standard au-dessus.
  static Widget _sectionSliver(Widget child) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        AppSpacing.xl,
        AppSpacing.screenMargin,
        AppSpacing.md,
      ),
      sliver: SliverToBoxAdapter(child: child),
    );
  }

  /// Liste de cartes séparées de 12, à la marge d'écran.
  static Widget _cardListSliver({
    required int count,
    required Widget Function(BuildContext, int) builder,
  }) {
    return SliverPadding(
      padding: AppSpacing.screenHorizontal,
      sliver: SliverList.separated(
        itemCount: count,
        separatorBuilder: (_, _) => AppSpacing.gapMd,
        itemBuilder: builder,
      ),
    );
  }
}

/// Carte d'événement câblée sur le domaine : résout le groupe et les
/// participants avant de déléguer à `EventCard`.
class _EventTile extends ConsumerWidget {
  const _EventTile({required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Group? group = event.groupId == null
        ? null
        : ref.watch(groupByIdProvider(event.groupId!));

    return EventCard(
      title: event.title,
      timeLabel: AppDates.timeRange(event.start, event.end),
      location: event.location,
      groupName: group?.name,
      accentColor: group?.accent.color ?? AppColors.primary,
      participants: event.avatars,
      statusTone: event.myResponse == EventResponse.yes
          ? null
          : event.myResponse.tone,
      statusLabel: event.myResponse.label,
      onTap: () => context.pushNamed(
        AppRoutes.eventDetail,
        pathParameters: <String, String>{'id': event.id},
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

/// Carte de groupe câblée sur le domaine.
class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    return GroupCard(
      name: group.name,
      description: group.description,
      icon: group.icon,
      accentColor: group.accent.color,
      trailingLabel: group.memberLabel,
      onTap: () => context.pushNamed(
        AppRoutes.groupDetail,
        pathParameters: <String, String>{'id': group.id},
      ),
    );
  }
}
