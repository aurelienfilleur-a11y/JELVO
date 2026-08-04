import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';

/// Conteneur de base des cartes : surface blanche, rayon 16, contour `border`
/// et ombre très douce.
///
/// `GroupCard`, `EventCard` et les blocs des écrans s'appuient tous dessus,
/// afin qu'un changement de rayon ou d'ombre ne se fasse qu'à un seul endroit.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color = AppColors.surface,
    this.borderColor = AppColors.border,
    this.shadows = AppShadows.card,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color? borderColor;
  final List<BoxShadow> shadows;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppRadii.cardRadius,
        border: borderColor == null ? null : Border.all(color: borderColor!),
        boxShadow: shadows,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.cardRadius,
          splashColor: AppColors.primarySoft,
          highlightColor: AppColors.primarySoft,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
