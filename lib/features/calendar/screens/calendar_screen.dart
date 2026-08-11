import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../data/data_providers.dart';
import '../../../router/app_routes.dart';
import '../../groups/models/group.dart';
import '../../groups/providers/group_providers.dart';
import '../models/agenda_entry.dart';
import '../providers/calendar_providers.dart';
import '../widgets/calendar_header.dart';
import '../widgets/day_timeline.dart';
import '../widgets/week_strip.dart';

/// Calendrier personnel.
///
/// Il n'a pas de contenu propre : il **agrège** les événements de tous les
/// groupes, les rendez-vous personnels, les tâches datées et les créneaux de
/// disponibilité. C'est `dayAgendaProvider` qui fait ce travail, et non
/// l'écran — les compteurs en tête lisent la même agrégation, sans quoi le
/// nombre affiché et la liste finiraient par se contredire.
///
/// Un rendez-vous personnel n'a pas besoin d'être filtré ici : il n'est jamais
/// renvoyé qu'à son propriétaire, `mon_agenda` s'en charge côté base.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime now = ref.watch(nowProvider);
    final DateTime selectedDay = ref.watch(selectedDayProvider);
    final List<AgendaEntry> agenda = ref.watch(agendaForSelectedDayProvider);
    final CalendarCounters counters = ref.watch(
      calendarCountersProvider(selectedDay),
    );
    final Set<String> selection = ref.watch(calendarFilterProvider);

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
            child: CalendarCountersRow(
              counters: counters,
              onTasksPressed: () => context.pushNamed(AppRoutes.tasks),
              onInvitationsPressed: () =>
                  context.pushNamed(AppRoutes.invitations),
              onAvailabilityPressed: () =>
                  context.pushNamed(AppRoutes.availability),
            ),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            AppSpacing.md,
            AppSpacing.screenMargin,
            0,
          ),
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
          padding: const EdgeInsets.only(top: AppSpacing.md),
          sliver: SliverToBoxAdapter(
            child: GroupFilterBar(
              choices: _choix(ref),
              selection: selection,
              onToggle: (String cle) =>
                  ref.read(calendarFilterProvider.notifier).toggle(cle),
              onClear: () => ref.read(calendarFilterProvider.notifier).clear(),
            ),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            AppSpacing.lg,
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

        if (agenda.isEmpty)
          SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.event_note_rounded,
              title: selection.isEmpty
                  ? 'Journée libre'
                  : 'Rien avec ce filtre',
              message: selection.isEmpty
                  ? 'Ni événement, ni tâche, ni créneau déclaré pour cette '
                        'journée.'
                  : 'Aucun élément des groupes sélectionnés ce jour-là.',
              actionLabel: selection.isEmpty
                  ? 'Créer un événement'
                  : 'Tout voir',
              onActionPressed: selection.isEmpty
                  ? () => context.pushNamed(AppRoutes.create)
                  : () => ref.read(calendarFilterProvider.notifier).clear(),
            ),
          )
        else
          SliverPadding(
            padding: AppSpacing.screenHorizontal,
            sliver: SliverToBoxAdapter(
              child: DayTimeline(
                entries: agenda,
                onTap: (AgendaEntry entry) => _ouvrir(context, entry),
              ),
            ),
          ),
      ],
    );
  }

  /// « Personnel » d'abord : c'est le seul choix qui existe toujours, y
  /// compris pour quelqu'un qui n'a encore aucun groupe.
  static List<CalendarFilterChoice> _choix(WidgetRef ref) {
    return <CalendarFilterChoice>[
      const CalendarFilterChoice(
        key: CalendarGroupFilter.personal,
        label: 'Personnel',
        color: AppColors.primary,
      ),
      for (final Group groupe in ref.watch(activeGroupsProvider))
        CalendarFilterChoice(
          key: groupe.id,
          label: groupe.name,
          color: groupe.accent.color,
        ),
    ];
  }

  static void _ouvrir(BuildContext context, AgendaEntry entry) {
    switch (entry.kind) {
      case AgendaEntryKind.groupEvent:
      case AgendaEntryKind.personalEvent:
        context.pushNamed(
          AppRoutes.eventDetail,
          pathParameters: <String, String>{'id': entry.id},
        );
      case AgendaEntryKind.task:
        context.pushNamed(
          AppRoutes.taskDetail,
          pathParameters: <String, String>{'id': entry.id},
        );
      case AgendaEntryKind.availability:
        break;
    }
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
