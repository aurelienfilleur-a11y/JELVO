import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'primary_button.dart';

/// État vide : icône dans un cercle teinté, titre, message et action.
///
/// À privilégier sur un simple `Text('Aucun résultat')` — c'est souvent le
/// premier écran que voit un nouvel utilisateur.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onActionPressed,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    final bool showAction = actionLabel != null && onActionPressed != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: AppColors.primary),
            ),
            AppSpacing.gapLg,
            Text(title, textAlign: TextAlign.center, style: AppTypography.h3),
            if (message != null) ...<Widget>[
              AppSpacing.gapSm,
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMuted,
              ),
            ],
            if (showAction) ...<Widget>[
              AppSpacing.gapXl,
              PrimaryButton(
                label: actionLabel!,
                onPressed: onActionPressed,
                expanded: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
