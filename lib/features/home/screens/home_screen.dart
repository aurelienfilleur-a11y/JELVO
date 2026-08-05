import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../data/data_providers.dart';
import '../../../router/app_routes.dart';
import '../../calendar/models/calendar_event.dart';
import '../../calendar/providers/calendar_providers.dart';
import '../../contacts/providers/contact_providers.dart';
import '../../groups/models/group.dart';
import '../../groups/providers/group_providers.dart';
import '../../notifications/providers/notification_providers.dart';
import '../../tasks/models/task.dart';
import '../../tasks/providers/task_providers.dart';
import '../providers/home_providers.dart';
import '../widgets/summary_banner.dart';

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
                      _TaskTile(
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
    final List<AvatarData> participants = ref.watch(
      avatarsForContactIdsProvider,
    )(event.participantIds);

    return EventCard(
      title: event.title,
      timeLabel: AppDates.timeRange(event.start, event.end),
      location: event.location,
      groupName: group?.name,
      accentColor: group?.accent.color ?? AppColors.primary,
      participants: participants,
      statusTone: event.status == EventStatus.confirmed
          ? null
          : event.status.tone,
      statusLabel: event.status.label,
      onTap: () => _showDetail(context, event, group),
    );
  }

  void _showDetail(BuildContext context, CalendarEvent event, Group? group) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) => Padding(
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
            Text(event.title, style: AppTypography.h2),
            AppSpacing.gapSm,
            Text(
              '${AppDates.fullDate(event.start)} · '
              '${AppDates.timeRange(event.start, event.end)}',
              style: AppTypography.bodyMuted,
            ),
            if (event.location != null) ...<Widget>[
              AppSpacing.gapSm,
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.place_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  AppSpacing.hGapSm,
                  Expanded(
                    child: Text(
                      event.location!,
                      style: AppTypography.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (group != null) ...<Widget>[
              AppSpacing.gapSm,
              StatusDot(tone: StatusTone.info, label: group.name, filled: true),
            ],
            if (event.notes != null) ...<Widget>[
              AppSpacing.gapLg,
              Text(event.notes!, style: AppTypography.bodyMuted),
            ],
            AppSpacing.gapXl,
            SecondaryButton(
              label: 'Fermer',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ligne de tâche câblée sur le domaine.
class _TaskTile extends ConsumerWidget {
  const _TaskTile({
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

    return TaskRow(
      title: task.title,
      subtitle: group?.name,
      done: task.isDone,
      dueLabel: task.dueDate == null
          ? null
          : AppDates.relativeDay(task.dueDate!, now: now),
      dueTone: task.toneFor(now),
      showDivider: showDivider,
      onToggle: (_) => ref.read(taskActionsProvider).toggleDone(task.id),
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
