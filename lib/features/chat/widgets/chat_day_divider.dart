import 'package:flutter/material.dart';

import '../../../core/core.dart';

/// Séparateur de date entre deux journées de conversation.
///
/// « Aujourd'hui », « Hier », puis la date en toutes lettres — c'est
/// `AppDates.relativeDay`, celui qu'emploient déjà le calendrier et l'accueil :
/// une seconde façon de nommer les jours finirait par diverger de la première.
class ChatDayDivider extends StatelessWidget {
  const ChatDayDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: <Widget>[
          Expanded(child: Divider(color: context.couleurs.border, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              label,
              style: context.typo.caption.copyWith(
                color: context.couleurs.textSecondary,
                fontWeight: AppTypography.medium,
              ),
            ),
          ),
          Expanded(child: Divider(color: context.couleurs.border, height: 1)),
        ],
      ),
    );
  }
}
