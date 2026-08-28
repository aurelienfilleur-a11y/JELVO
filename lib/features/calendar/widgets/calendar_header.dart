import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../providers/calendar_providers.dart';

/// Les quatre compteurs du calendrier, sur une seule ligne.
///
/// Quatre et pas cinq : au-delà, à 360 dp de large, chaque colonne descend
/// sous les 80 dp et les libellés se coupent.
class CalendarCountersRow extends StatelessWidget {
  const CalendarCountersRow({
    super.key,
    required this.counters,
    this.onTasksPressed,
    this.onInvitationsPressed,
    this.onAvailabilityPressed,
  });

  final CalendarCounters counters;
  final VoidCallback? onTasksPressed;
  final VoidCallback? onInvitationsPressed;
  final VoidCallback? onAvailabilityPressed;

  @override
  Widget build(BuildContext context) {
    // `IntrinsicHeight` et non `stretch` seul : la ligne vit dans un sliver,
    // donc sans hauteur imposée, et `stretch` y demanderait une hauteur
    // infinie. Les quatre cartes doivent pourtant s'aligner, « 4 h 30 » étant
    // plus haut à rendre que « 0 ».
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: _Compteur(
              icon: Icons.event_rounded,
              value: '${counters.events}',
              label: 'Événements',
              tint: context.couleurs.primary,
            ),
          ),
          AppSpacing.hGapSm,
          Expanded(
            child: _Compteur(
              icon: Icons.task_alt_rounded,
              value: '${counters.tasks}',
              label: 'Tâches',
              tint: context.couleurs.success,
              onPressed: onTasksPressed,
            ),
          ),
          AppSpacing.hGapSm,
          Expanded(
            child: _Compteur(
              icon: Icons.hourglass_bottom_rounded,
              value: counters.freeLabel,
              label: 'Disponible',
              tint: context.couleurs.warning,
              onPressed: onAvailabilityPressed,
            ),
          ),
          AppSpacing.hGapSm,
          Expanded(
            child: _Compteur(
              icon: Icons.mark_email_unread_outlined,
              value: '${counters.pendingInvitations}',
              label: 'Invitations',
              tint: context.couleurs.danger,
              onPressed: onInvitationsPressed,
            ),
          ),
        ],
      ),
    );
  }
}

class _Compteur extends StatelessWidget {
  const _Compteur({
    required this.icon,
    required this.value,
    required this.label,
    required this.tint,
    this.onPressed,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color tint;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final Widget contenu = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18, color: tint),
          const SizedBox(height: 6),
          FittedBox(
            child: Text(
              value,
              style: context.typo.h3.copyWith(color: context.couleurs.encre),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: context.typo.caption.copyWith(
              color: context.couleurs.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    return AppCard(
      padding: EdgeInsets.zero,
      child: onPressed == null
          ? contenu
          : InkWell(
              onTap: onPressed,
              borderRadius: AppRadii.cardRadius,
              child: contenu,
            ),
    );
  }
}

/// Une entrée du filtre par groupe : sa clé et ce qu'on lit dessus.
@immutable
class CalendarFilterChoice {
  const CalendarFilterChoice({
    required this.key,
    required this.label,
    required this.color,
  });

  final String key;
  final String label;
  final Color color;
}

/// Barre de filtres par groupe, défilante à l'horizontale.
///
/// « Tout » n'est pas un filtre de plus mais l'état de sélection vide : c'est
/// pourquoi il apparaît sélectionné quand rien d'autre ne l'est.
class GroupFilterBar extends StatelessWidget {
  const GroupFilterBar({
    super.key,
    required this.choices,
    required this.selection,
    required this.onToggle,
    required this.onClear,
  });

  final List<CalendarFilterChoice> choices;
  final Set<String> selection;
  final ValueChanged<String> onToggle;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: AppSpacing.screenHorizontal,
        children: <Widget>[
          FilterChip(
            label: const Text('Tout'),
            selected: selection.isEmpty,
            showCheckmark: false,
            onSelected: (_) => onClear(),
          ),
          for (final CalendarFilterChoice choix in choices) ...<Widget>[
            AppSpacing.hGapSm,
            FilterChip(
              avatar: CircleAvatar(backgroundColor: choix.color, radius: 6),
              label: Text(choix.label),
              selected: selection.contains(choix.key),
              showCheckmark: false,
              onSelected: (_) => onToggle(choix.key),
            ),
          ],
        ],
      ),
    );
  }
}
