import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../data/data_providers.dart';
import '../../../router/app_routes.dart';
import '../../profile/models/profile.dart';
import '../../profile/providers/profile_providers.dart';
import '../models/agenda_entry.dart';
import '../providers/calendar_providers.dart';
import '../widgets/calendar_header.dart';
import '../widgets/calendar_sheets.dart';
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
    final Profile? profil = ref.watch(currentProfileProvider).value;
    final bool aujourdhui = AppDates.isSameDay(selectedDay, now);
    // Un filtre est « posé » dès qu'on a restreint les groupes ou masqué les
    // créneaux : la pastille sur l'icône dit que la journée affichée n'est pas
    // la journée complète.
    final bool filtreActif =
        selection.isNotEmpty || !ref.watch(showAvailabilityProvider);

    return AppScreen(
      title: 'Calendrier',
      leading: _Avatar(profil: profil),
      headerAction: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppScreenAction(
            icon: Icons.search_rounded,
            tooltip: 'Rechercher',
            onPressed: () => CalendarSearchSheet.ouvrir(context),
          ),
          AppSpacing.hGapSm,
          AppScreenAction(
            icon: Icons.tune_rounded,
            tooltip: 'Filtres',
            badged: filtreActif,
            onPressed: () => CalendarFilterSheet.ouvrir(context),
          ),
          AppSpacing.hGapSm,
          AppScreenAction(
            icon: Icons.add_rounded,
            tooltip: 'Créer',
            accented: true,
            onPressed: () => context.pushNamed(AppRoutes.create),
          ),
        ],
      ),
      slivers: <Widget>[
        SliverPadding(
          padding: AppSpacing.screenHorizontal,
          sliver: SliverToBoxAdapter(
            child: Row(
              children: <Widget>[
                _ArrowButton(
                  icon: Icons.chevron_left_rounded,
                  tooltip: 'Semaine précédente',
                  onPressed: () =>
                      ref.read(selectedDayProvider.notifier).shiftDays(-7),
                ),
                Expanded(
                  child: WeekStrip(
                    selectedDay: selectedDay,
                    today: now,
                    markersByDay: ref.watch(weekMarkersProvider),
                    onDaySelected: (DateTime day) =>
                        ref.read(selectedDayProvider.notifier).select(day),
                  ),
                ),
                _ArrowButton(
                  icon: Icons.chevron_right_rounded,
                  tooltip: 'Semaine suivante',
                  onPressed: () =>
                      ref.read(selectedDayProvider.notifier).shiftDays(7),
                ),
              ],
            ),
          ),
        ),

        // « Aujourd'hui • Jeudi 15 mai ». Le bouton de retour n'apparaît que
        // s'il y a quelque part où revenir : sur la journée du jour, il
        // n'aurait rien à faire.
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            AppSpacing.xl,
            AppSpacing.screenMargin,
            AppSpacing.lg,
          ),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      children: <InlineSpan>[
                        TextSpan(
                          text: AppDates.relativeDay(selectedDay, now: now),
                          style: context.typo.h3.copyWith(
                            color: context.couleurs.primary,
                          ),
                        ),
                        TextSpan(
                          text: ' • ${AppDates.fullDate(selectedDay)}',
                          style: context.typo.h3.copyWith(
                            color: context.couleurs.encre,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!aujourdhui) ...<Widget>[
                  AppSpacing.hGapSm,
                  SecondaryButton(
                    label: "Aujourd'hui",
                    expanded: false,
                    onPressed: () =>
                        ref.read(selectedDayProvider.notifier).select(now),
                  ),
                ],
              ],
            ),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            0,
            AppSpacing.screenMargin,
            AppSpacing.lg,
          ),
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

        if (agenda.isEmpty)
          SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.event_note_rounded,
              title: filtreActif ? 'Rien avec ces filtres' : 'Journée libre',
              message: filtreActif
                  ? 'Un filtre est posé : la journée entière porte peut-être '
                        'autre chose.'
                  : 'Ni événement, ni tâche, ni créneau déclaré pour cette '
                        'journée.',
              actionLabel: filtreActif ? 'Tout voir' : 'Créer un événement',
              onActionPressed: filtreActif
                  ? () {
                      ref.read(calendarFilterProvider.notifier).clear();
                      if (!ref.read(showAvailabilityProvider)) {
                        ref.read(showAvailabilityProvider.notifier).toggle();
                      }
                    }
                  : () => context.pushNamed(AppRoutes.create),
            ),
          )
        else
          SliverPadding(
            padding: AppSpacing.screenHorizontal,
            // En sliver : une journée très chargée bâtit ses lignes à mesure
            // du défilement plutôt que toutes d'un coup.
            sliver: DayTimeline.enSlivers(
              entries: agenda,
              onTap: (AgendaEntry entry) => _ouvrir(context, entry),
            ),
          ),
      ],
    );
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

/// La photo de profil de l'en-tête.
///
/// Pas de pastille de présence : `profiles.last_seen_at` n'est écrit nulle
/// part, et un point vert permanent serait un mensonge — même règle que sur
/// l'accueil, le profil et le carnet.
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
          size: 44,
        ),
      ),
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
            color: context.couleurs.background,
            borderRadius: BorderRadius.circular(AppSpacing.sm),
          ),
          child: Icon(icon, size: 20, color: context.couleurs.encre),
        ),
      ),
    );
  }
}
