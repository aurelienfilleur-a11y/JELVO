import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Gabarit commun des écrans d'onglet : en-tête H1 + sous-titre, contenu
/// défilant à la marge d'écran de 16.
///
/// L'en-tête défile avec le contenu plutôt que de rester épinglé : sur des
/// listes courtes, une `AppBar` fixe mangerait inutilement de la hauteur.
class AppScreen extends StatelessWidget {
  const AppScreen({
    super.key,
    required this.title,
    required this.slivers,
    this.subtitle,
    this.headerAction,
  });

  final String title;
  final String? subtitle;

  /// Action affichée à droite du titre (bouton icône, avatar…).
  final Widget? headerAction;

  /// Contenu de l'écran, sous forme de slivers.
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenMargin,
                AppSpacing.lg,
                AppSpacing.screenMargin,
                AppSpacing.xl,
              ),
              sliver: SliverToBoxAdapter(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(title, style: AppTypography.h1),
                          if (subtitle != null) ...<Widget>[
                            AppSpacing.gapXs,
                            Text(subtitle!, style: AppTypography.bodyMuted),
                          ],
                        ],
                      ),
                    ),
                    if (headerAction != null) ...<Widget>[
                      AppSpacing.hGapMd,
                      headerAction!,
                    ],
                  ],
                ),
              ),
            ),
            ...slivers,
            // Dégage la barre de navigation inférieure en fin de liste.
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
          ],
        ),
      ),
    );
  }
}

/// Bouton icône rond de l'en-tête (notifications, filtres…).
class AppScreenAction extends StatelessWidget {
  const AppScreenAction({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.badged = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  /// Affiche une pastille violette en haut à droite (élément non lu).
  final bool badged;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Icon(icon, size: 20, color: AppColors.midnight),
              if (badged)
                Positioned(
                  top: 11,
                  right: 11,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
