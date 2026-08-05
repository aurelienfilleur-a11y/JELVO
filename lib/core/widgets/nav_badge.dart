import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Pastille de compteur posée sur un enfant — icône d'onglet, bouton de barre.
///
/// Rien n'est peint quand [count] est nul : un compteur à zéro ne doit pas
/// laisser un rond vide derrière lui. Au-delà de [max], le libellé passe à
/// « 99+ » plutôt que d'élargir la pastille au point de déborder de l'icône.
class NavBadge extends StatelessWidget {
  const NavBadge({
    super.key,
    required this.count,
    required this.child,
    this.max = 99,
    this.color = AppColors.danger,
  });

  final int count;
  final Widget child;
  final int max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;

    final String label = count > max ? '$max+' : '$count';

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        child,
        Positioned(
          top: -4,
          right: -8,
          child: Container(
            constraints: const BoxConstraints(minWidth: 18),
            height: 18,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(9),
              // Le liseré blanc détache la pastille de l'icône : sans lui, les
              // deux se confondent dès que l'icône est sombre.
              border: Border.all(color: AppColors.surface, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: AppTypography.caption.copyWith(
                color: Colors.white,
                fontSize: 10,
                height: 1,
                fontWeight: AppTypography.semiBold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
