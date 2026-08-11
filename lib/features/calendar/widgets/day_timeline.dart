import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../models/agenda_entry.dart';

/// Déroulé vertical d'une journée.
///
/// Une gouttière d'heures à gauche, un rail, et une ligne par élément. Le rail
/// continu est ce qui distingue une timeline d'une simple liste : il dit que
/// les lignes se suivent dans le temps, et non par ordre d'importance.
///
/// Les créneaux de disponibilité y figurent en retrait — pas de carte, pas
/// d'ombre : ils décrivent le fond de la journée, pas ce qui s'y passe.
class DayTimeline extends StatelessWidget {
  const DayTimeline({super.key, required this.entries, required this.onTap});

  final List<AgendaEntry> entries;

  /// Ouvre l'élément touché. Les créneaux n'appellent jamais ce rappel.
  final ValueChanged<AgendaEntry> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (int i = 0; i < entries.length; i++)
          _Ligne(
            entry: entries[i],
            premiere: i == 0,
            derniere: i == entries.length - 1,
            onTap: onTap,
          ),
      ],
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({
    required this.entry,
    required this.premiere,
    required this.derniere,
    required this.onTap,
  });

  final AgendaEntry entry;
  final bool premiere;
  final bool derniere;
  final ValueChanged<AgendaEntry> onTap;

  static const double _gouttiere = 48;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: _gouttiere,
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Text(
                entry.timeLabel ?? '',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: AppTypography.medium,
                ),
              ),
            ),
          ),
          _Rail(
            couleur: entry.accent,
            premiere: premiere,
            derniere: derniere,
            creux: entry.kind == AgendaEntryKind.availability,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.md,
                bottom: AppSpacing.md,
              ),
              child: entry.kind == AgendaEntryKind.availability
                  ? _Creneau(entry: entry)
                  : _Carte(entry: entry, onTap: () => onTap(entry)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Le trait vertical et sa pastille.
class _Rail extends StatelessWidget {
  const _Rail({
    required this.couleur,
    required this.premiere,
    required this.derniere,
    required this.creux,
  });

  final Color couleur;
  final bool premiere;
  final bool derniere;

  /// Pastille creuse pour un créneau : il ne se passe rien, il se peut
  /// seulement quelque chose.
  final bool creux;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      child: Column(
        children: <Widget>[
          SizedBox(
            height: AppSpacing.md,
            child: premiere
                ? null
                : const VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: AppColors.border,
                  ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: creux ? AppColors.surface : couleur,
              border: Border.all(color: couleur, width: 2),
              shape: BoxShape.circle,
            ),
          ),
          if (!derniere)
            const Expanded(
              child: VerticalDivider(
                width: 1,
                thickness: 1,
                color: AppColors.border,
              ),
            ),
        ],
      ),
    );
  }
}

class _Carte extends StatelessWidget {
  const _Carte({required this.entry, required this.onTap});

  final AgendaEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.cardRadius,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              Container(
                width: 3,
                height: 34,
                decoration: BoxDecoration(
                  color: entry.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          _icone(entry.kind),
                          size: 15,
                          color: AppColors.textSecondary,
                        ),
                        AppSpacing.hGapSm,
                        Expanded(
                          child: Text(
                            entry.title,
                            style: AppTypography.h3,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (entry.subtitle != null && entry.subtitle!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          entry.subtitle!,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              if (entry.statusTone != null) ...<Widget>[
                AppSpacing.hGapSm,
                StatusDot(
                  tone: entry.statusTone!,
                  label: entry.statusLabel,
                  filled: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static IconData _icone(AgendaEntryKind kind) => switch (kind) {
    AgendaEntryKind.groupEvent => Icons.groups_2_outlined,
    AgendaEntryKind.personalEvent => Icons.person_outline_rounded,
    AgendaEntryKind.task => Icons.task_alt_rounded,
    AgendaEntryKind.availability => Icons.schedule_rounded,
  };
}

/// Un créneau de disponibilité : une bande discrète, sans carte ni ombre.
class _Creneau extends StatelessWidget {
  const _Creneau({required this.entry});

  final AgendaEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppRadii.fieldRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.schedule_rounded, size: 15, color: entry.accent),
          AppSpacing.hGapSm,
          Expanded(
            child: Text(
              '${entry.title} · ${entry.subtitle ?? ''}',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
