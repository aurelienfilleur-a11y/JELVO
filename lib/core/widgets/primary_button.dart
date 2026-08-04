import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Bouton d'action principal : fond violet plein, texte blanc, rayon 14.
///
/// Passer `onPressed: null` désactive le bouton ; `isLoading: true` le désactive
/// aussi et remplace le libellé par un indicateur de progression, ce qui évite
/// le double appui sur une action réseau.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Icône optionnelle affichée avant le libellé.
  final IconData? icon;

  final bool isLoading;

  /// Occupe toute la largeur disponible (défaut) ou se limite à son contenu.
  final bool expanded;

  static const double _height = 52;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !isLoading;

    final Widget button = FilledButton(
      onPressed: enabled ? onPressed : null,
      style:
          FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.border,
            disabledForegroundColor: AppColors.textSecondary,
            elevation: 0,
            minimumSize: Size(expanded ? double.infinity : 0, _height),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            textStyle: AppTypography.button,
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadii.buttonRadius,
            ),
          ).copyWith(
            // Assombrit vers `primaryDark` au survol / à l'appui plutôt que
            // d'appliquer l'overlay blanc par défaut de Material.
            overlayColor: const WidgetStatePropertyAll<Color>(
              AppColors.primaryDark,
            ),
          ),
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: 18),
                  AppSpacing.hGapSm,
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}
