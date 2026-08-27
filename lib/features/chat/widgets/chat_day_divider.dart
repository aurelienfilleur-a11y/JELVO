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
          const Expanded(child: Divider(color: AppColors.border, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              label,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: AppTypography.medium,
              ),
            ),
          ),
          const Expanded(child: Divider(color: AppColors.border, height: 1)),
        ],
      ),
    );
  }
}
