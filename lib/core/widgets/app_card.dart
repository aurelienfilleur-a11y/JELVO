import 'package:flutter/material.dart';

import '../theme/jelvo_colors.dart';
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
    // `null` veut dire « celle du thème », résolue au `build` : une valeur
    // par défaut ne peut pas lire le contexte. Une carte qui ne veut pas de
    // contour passe `Colors.transparent`, pas `null`.
    this.color,
    this.borderColor,
    this.shadows,
    this.clipContent = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final List<BoxShadow>? shadows;

  /// Rogne le contenu au rayon de la carte.
  ///
  /// Nécessaire dès qu'un enfant va d'un bord à l'autre — la photo de
  /// couverture d'un groupe déborderait sinon des coins arrondis. Éteint par
  /// défaut : le rognage coûte une couche de composition, et les cartes à
  /// marge intérieure n'en ont pas besoin.
  final bool clipContent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? context.couleurs.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: borderColor ?? context.couleurs.border),
        boxShadow: shadows ?? context.ombres.card,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.cardRadius,
          splashColor: context.couleurs.primarySoft,
          highlightColor: context.couleurs.primarySoft,
          child: clipContent
              ? ClipRRect(
                  borderRadius: AppRadii.cardRadius,
                  child: Padding(padding: padding, child: child),
                )
              : Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
