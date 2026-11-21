import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../../calendar/models/agenda_entry.dart';
import '../../calendar/widgets/day_timeline.dart';

/// Carte « Mon agenda » de l'accueil : la journée en cours, en chronologie.
///
/// Elle réutilise `DayTimeline`, la même que l'écran du calendrier, dans sa
/// variante « dans une carte ». Deux chronologies séparées auraient fini par
/// diverger — c'est déjà l'argument qui a fait renoncer à recalculer les
/// jointures côté client pour le chat.
class AgendaCard extends StatelessWidget {
  const AgendaCard({
    super.key,
    required this.entries,
    required this.onOpenEntry,
    required this.onOpenCalendar,
    this.maxEntries = 3,
  });

  final List<AgendaEntry> entries;
  final ValueChanged<AgendaEntry> onOpenEntry;
  final VoidCallback onOpenCalendar;

  /// Au-delà, la carte mangerait l'accueil : le reste se lit au calendrier.
  final int maxEntries;

  @override
  Widget build(BuildContext context) {
    final List<AgendaEntry> visibles = entries.take(maxEntries).toList();
    final int reste = entries.length - visibles.length;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: SectionHeader(
              title: AppTexts.of(context).homeAgenda,
              actionLabel: AppTexts.of(context).homeVoirCalendrier,
              onActionPressed: onOpenCalendar,
            ),
          ),
          AppSpacing.gapMd,

          if (visibles.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: EmptyState(
                icon: Icons.event_available_rounded,
                title: AppTexts.of(context).homeNoEventTitle,
                message: AppTexts.of(context).homeNoEventMessage,
              ),
            )
          else
            DayTimeline(
              entries: visibles,
              onTap: onOpenEntry,
              dansUneCarte: true,
            ),

          // Le pied n'apparaît que s'il reste quelque chose à voir : proposer
          // « voir tout » sur une liste déjà complète est une promesse vide.
          if (reste > 0) ...<Widget>[
            Divider(height: 1, color: context.couleurs.border),
            TextButton.icon(
              onPressed: onOpenCalendar,
              icon: const Icon(Icons.expand_more_rounded, size: 18),
              label: Text(
                reste == 1
                    ? AppTexts.of(context).homeVoirAgenda1
                    : AppTexts.of(context).homeVoirAgendaReste(reste),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
