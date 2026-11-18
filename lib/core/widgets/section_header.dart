import 'package:flutter/material.dart';

import '../theme/jelvo_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Titre de section (H3) avec sous-titre et action optionnels.
///
/// Sert à découper les écrans longs — « Aujourd'hui », « Mes groupes »… — et
/// à porter le lien « Tout voir » sur la droite.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onActionPressed,
    this.padding = EdgeInsets.zero,
  });

  final String title;
  final String? subtitle;

  /// Libellé de l'action de droite. Ignoré si [onActionPressed] est nul.
  final String? actionLabel;

  final VoidCallback? onActionPressed;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final bool showAction = actionLabel != null && onActionPressed != null;

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: context.typo.h3),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: context.typo.caption),
                ],
              ],
            ),
          ),
          if (showAction) ...<Widget>[
            AppSpacing.hGapMd,
            TextButton(
              onPressed: onActionPressed,
              style: TextButton.styleFrom(
                foregroundColor: context.couleurs.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: context.typo.caption.copyWith(
                  fontWeight: AppTypography.semiBold,
                ),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
