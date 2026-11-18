import 'package:flutter/material.dart';

import '../theme/jelvo_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Bouton secondaire : fond blanc, contour `border`, libellé violet.
///
/// Même gabarit que [PrimaryButton] (hauteur 52, rayon 14) pour qu'ils
/// s'alignent proprement côte à côte dans une `Row`.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expanded = true,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;

  /// Teinte le libellé et le contour en `danger` (quitter un groupe, supprimer…).
  final bool isDestructive;

  static const double _height = 52;

  @override
  Widget build(BuildContext context) {
    final Color foreground = isDestructive
        ? context.couleurs.danger
        : context.couleurs.primary;

    final Widget button = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: context.couleurs.surface,
        foregroundColor: foreground,
        disabledForegroundColor: context.couleurs.textSecondary,
        side: BorderSide(
          color: isDestructive
              ? context.couleurs.dangerSoft
              : context.couleurs.border,
        ),
        minimumSize: Size(expanded ? double.infinity : 0, _height),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        textStyle: context.typo.button,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadii.buttonRadius,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 18),
            AppSpacing.hGapSm,
          ],
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}
