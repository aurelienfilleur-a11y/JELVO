import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../models/calendar_event.dart';

/// Les trois réponses possibles à un événement, côte à côte.
///
/// Extrait en widget parce qu'elles doivent apparaître à deux endroits : sur
/// le détail de l'événement, et **dans la notification qui l'annonce**.
/// Répondre depuis la notification est le cas le plus fréquent — c'est là
/// qu'on apprend l'invitation.
class ResponseButtons extends StatelessWidget {
  const ResponseButtons({
    super.key,
    required this.courante,
    required this.onRepondre,
    this.compact = false,
  });

  /// Réponse déjà donnée, mise en évidence.
  final EventResponse courante;

  final ValueChanged<EventResponse> onRepondre;

  /// Version resserrée, pour une ligne de notification.
  final bool compact;

  /// **Refus à gauche, acceptation à droite** — le même ordre que les deux
  /// boutons des autres invitations.
  ///
  /// L'ordre inverse a été utilisé jusqu'ici. Le garder à un endroit et pas à
  /// l'autre aurait été le pire des deux : trois boutons identiques dont le
  /// premier veut dire « oui » ici et « non » là, à un doigt d'écart.
  static const List<EventResponse> _choix = <EventResponse>[
    EventResponse.no,
    EventResponse.maybe,
    EventResponse.yes,
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < _choix.length; i++) ...<Widget>[
          if (i > 0) AppSpacing.hGapSm,
          Expanded(
            child: _Bouton(
              reponse: _choix[i],
              choisie: courante == _choix[i],
              compact: compact,
              onTap: () => onRepondre(_choix[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _Bouton extends StatelessWidget {
  const _Bouton({
    required this.reponse,
    required this.choisie,
    required this.compact,
    required this.onTap,
  });

  final EventResponse reponse;
  final bool choisie;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color couleur = switch (reponse.tone) {
      StatusTone.success => AppColors.success,
      StatusTone.warning => AppColors.warning,
      StatusTone.danger => AppColors.danger,
      _ => AppColors.textSecondary,
    };

    return Semantics(
      selected: choisie,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.buttonRadius,
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: compact ? AppSpacing.sm : AppSpacing.md,
          ),
          decoration: BoxDecoration(
            // La réponse retenue est pleine, les autres en contour : on doit
            // voir d'un coup d'œil ce qu'on a déjà répondu.
            color: choisie ? couleur : Colors.transparent,
            borderRadius: AppRadii.buttonRadius,
            border: Border.all(color: choisie ? couleur : AppColors.border),
          ),
          child: Text(
            reponse.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (compact ? AppTypography.caption : AppTypography.body)
                .copyWith(
                  color: choisie ? Colors.white : couleur,
                  fontWeight: AppTypography.semiBold,
                ),
          ),
        ),
      ),
    );
  }
}
