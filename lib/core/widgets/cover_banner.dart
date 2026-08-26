import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Bandeau d'en-tête : photo de couverture si elle existe, dégradé d'accent
/// sinon, et nom en surimpression.
///
/// Il vivait dans la feature `groups`, ce qui l'y enfermait : les écrans
/// d'invitation à un événement et d'attribution d'une tâche montrent la même
/// couverture, et une feature ne lit pas les widgets d'une autre. Comme tout
/// composant de `core`, il ne prend que des `String`, une `Color` et une
/// `IconData` — jamais un `Group`.
///
/// Le dégradé sombre en bas n'est pas décoratif : sans lui, un texte blanc
/// posé sur une photo claire devient illisible.
class CoverBanner extends StatelessWidget {
  const CoverBanner({
    super.key,
    required this.name,
    required this.accentColor,
    required this.icon,
    this.photoUrl,
    this.subtitle,
    this.height = 168,
  });

  final String name;
  final Color accentColor;
  final IconData icon;
  final String? photoUrl;
  final String? subtitle;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (photoUrl != null)
            Image.network(
              photoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _accentBackground,
            )
          else
            _accentBackground,

          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.transparent,
                  AppColors.midnight.withValues(alpha: 0.55),
                ],
              ),
            ),
          ),

          Positioned(
            left: AppSpacing.screenMargin,
            right: AppSpacing.screenMargin,
            bottom: AppSpacing.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  style: AppTypography.h2.copyWith(color: Colors.white),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTypography.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget get _accentBackground => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[accentColor, accentColor.withValues(alpha: 0.72)],
      ),
    ),
    child: Center(
      child: Icon(icon, size: 56, color: Colors.white.withValues(alpha: 0.5)),
    ),
  );
}
