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
  const DayTimeline({
    super.key,
    required this.entries,
    required this.onTap,
    this.dansUneCarte = false,
  });

  final List<AgendaEntry> entries;

  /// Ouvre l'élément touché. Les créneaux n'appellent jamais ce rappel.
  final ValueChanged<AgendaEntry> onTap;

  /// Rendu à poser **dans** une carte — celle de l'accueil.
  ///
  /// Une carte blanche ombrée dans une autre carte blanche ne se lit pas :
  /// les lignes deviennent des fonds teintés de l'accent, sans ombre. Le
  /// squelette — gouttière d'heures, rail, pastilles — reste identique, parce
  /// que deux chronologies séparées finiraient par diverger.
  final bool dansUneCarte;

  /// Les mêmes lignes, en sliver.
  ///
  /// La journée d'un calendrier n'a pas de borne : une journée très chargée
  /// construirait d'un coup toutes ses lignes dans une `Column`. Le sliver les
  /// bâtit à mesure du défilement. La carte de l'accueil, elle, tient en trois
  /// lignes et garde la `Column`.
  static Widget enSlivers({
    required List<AgendaEntry> entries,
    required ValueChanged<AgendaEntry> onTap,
  }) {
    return SliverList.builder(
      itemCount: entries.length,
      itemBuilder: (BuildContext context, int index) => _Ligne(
        entry: entries[index],
        premiere: index == 0,
        derniere: index == entries.length - 1,
        onTap: onTap,
        dansUneCarte: false,
      ),
    );
  }

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
            dansUneCarte: dansUneCarte,
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
    required this.dansUneCarte,
  });

  final AgendaEntry entry;
  final bool premiere;
  final bool derniere;
  final ValueChanged<AgendaEntry> onTap;
  final bool dansUneCarte;

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
                  : _Carte(
                      entry: entry,
                      onTap: () => onTap(entry),
                      dansUneCarte: dansUneCarte,
                    ),
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
  const _Carte({
    required this.entry,
    required this.onTap,
    this.dansUneCarte = false,
  });

  final AgendaEntry entry;
  final VoidCallback onTap;
  final bool dansUneCarte;

  @override
  Widget build(BuildContext context) {
    final Widget contenu = InkWell(
      onTap: onTap,
      borderRadius: AppRadii.cardRadius,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        _icone(entry.kind),
                        size: 15,
                        color: dansUneCarte
                            ? entry.accent
                            : AppColors.textSecondary,
                      ),
                      AppSpacing.hGapSm,
                      Expanded(
                        child: EmojiText(
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
                      child: EmojiText(
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
            // Dans la carte de l'accueil, la plage horaire est portée à
            // droite de la ligne : la gouttière ne donne que l'heure de
            // début, et « 09:00 – 10:30 » dit ce qu'elle ne dit pas.
            if (dansUneCarte && entry.kind != AgendaEntryKind.task) ...<Widget>[
              AppSpacing.hGapSm,
              Text(
                AppDates.timeRange(entry.start, entry.end),
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ] else if (!dansUneCarte && entry.avatars.isNotEmpty) ...<Widget>[
              // Les convives passent avant le statut : sur un événement de
              // groupe, savoir qui vient est ce qu'on cherche.
              AppSpacing.hGapSm,
              AvatarStack(avatars: entry.avatars, size: 26, maxVisible: 3),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ] else if (entry.statusTone != null) ...<Widget>[
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
    );

    // **Le fond dit la nature de la ligne** : violet pour un événement, vert
    // pour une tâche, et — côté créneaux — vert ou rouge selon qu'on s'est
    // déclaré disponible ou non. Ce sont les jetons du design system
    // (`primary`, `success`, `danger`), très dilués : aucune couleur nouvelle
    // n'a été introduite pour la maquette.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: entry.accent.withValues(alpha: 0.08),
        borderRadius: AppRadii.cardRadius,
      ),
      child: contenu,
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
    final bool disponible = entry.accent == AppColors.success;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: entry.accent.withValues(alpha: 0.08),
        borderRadius: AppRadii.cardRadius,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                EmojiText(
                  entry.title,
                  style: AppTypography.body.copyWith(
                    color: entry.accent,
                    fontWeight: AppTypography.semiBold,
                  ),
                ),
                if (entry.subtitle != null && entry.subtitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: EmojiText(
                      entry.subtitle!,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          AppSpacing.hGapSm,
          // La pastille pleine reprend le mot sans le répéter : disponible ou
          // non, cela se voit avant de se lire.
          Icon(
            disponible
                ? Icons.check_circle_rounded
                : Icons.remove_circle_rounded,
            size: 22,
            color: entry.accent,
          ),
        ],
      ),
    );
  }
}
