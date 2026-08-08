import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../data/data_providers.dart';
import '../../../router/app_routes.dart';
import '../../groups/models/group.dart';
import '../../groups/providers/group_providers.dart';
import '../models/calendar_event.dart';
import '../providers/calendar_providers.dart';
import '../widgets/week_strip.dart';

/// Écran Calendrier : bande hebdomadaire + agenda du jour sélectionné.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime now = ref.watch(nowProvider);
    final DateTime selectedDay = ref.watch(selectedDayProvider);
    final List<CalendarEvent> events = ref.watch(eventsForSelectedDayProvider);

    return AppScreen(
      title: 'Calendrier',
      subtitle: AppDates.monthYear(selectedDay),
      headerAction: AppScreenAction(
        icon: Icons.today_rounded,
        tooltip: "Aujourd'hui",
        onPressed: () => ref.read(selectedDayProvider.notifier).select(now),
      ),
      slivers: <Widget>[
        SliverPadding(
          padding: AppSpacing.screenHorizontal,
          sliver: SliverToBoxAdapter(
            child: AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.lg,
              ),
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            AppDates.monthYear(selectedDay),
                            style: AppTypography.h3,
                          ),
                        ),
                        _ArrowButton(
                          icon: Icons.chevron_left_rounded,
                          tooltip: 'Semaine précédente',
                          onPressed: () => ref
                              .read(selectedDayProvider.notifier)
                              .shiftDays(-7),
                        ),
                        AppSpacing.hGapSm,
                        _ArrowButton(
                          icon: Icons.chevron_right_rounded,
                          tooltip: 'Semaine suivante',
                          onPressed: () => ref
                              .read(selectedDayProvider.notifier)
                              .shiftDays(7),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapLg,
                  WeekStrip(
                    selectedDay: selectedDay,
                    today: now,
                    eventCountByDay: ref.watch(eventCountByDayProvider),
                    onDaySelected: (DateTime day) =>
                        ref.read(selectedDayProvider.notifier).select(day),
                  ),
                ],
              ),
            ),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            AppSpacing.xl,
            AppSpacing.screenMargin,
            AppSpacing.md,
          ),
          sliver: SliverToBoxAdapter(
            child: SectionHeader(
              title: AppDates.relativeDay(selectedDay, now: now),
              subtitle: AppDates.fullDate(selectedDay),
              actionLabel: 'Ajouter',
              onActionPressed: () => context.pushNamed(AppRoutes.create),
            ),
          ),
        ),

        if (events.isEmpty)
          SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.event_note_rounded,
              title: 'Aucun événement',
              message:
                  'Cette journée est libre. Profitez-en ou planifiez '
                  'quelque chose.',
              actionLabel: 'Créer un événement',
              onActionPressed: () => context.pushNamed(AppRoutes.create),
            ),
          )
        else
          SliverPadding(
            padding: AppSpacing.screenHorizontal,
            sliver: SliverList.separated(
              itemCount: events.length,
              separatorBuilder: (_, _) => AppSpacing.gapMd,
              itemBuilder: (BuildContext context, int index) {
                final CalendarEvent event = events[index];
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
                  // Une réponse « oui » n'a pas besoin d'être signalée : c'est
                  // le cas attendu.
                  statusTone: event.myResponse == EventResponse.yes
                      ? null
                      : event.myResponse.tone,
                  statusLabel: event.myResponse.label,
                  onTap: () {},
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Petit bouton rond de navigation entre les semaines.
class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppSpacing.sm),
          ),
          child: Icon(icon, size: 20, color: AppColors.midnight),
        ),
      ),
    );
  }
}
