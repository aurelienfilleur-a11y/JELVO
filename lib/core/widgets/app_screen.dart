import 'package:flutter/material.dart';

import '../theme/jelvo_colors.dart';
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
    this.leading,
  });

  final String title;
  final String? subtitle;

  /// Action affichée à droite du titre (bouton icône, avatar…).
  final Widget? headerAction;

  /// Élément posé **avant** le titre — l'avatar de l'accueil. Les autres
  /// onglets n'en ont pas : leur en-tête commence au titre.
  final Widget? leading;

  /// Contenu de l'écran, sous forme de slivers.
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.couleurs.background,
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    if (leading != null) ...<Widget>[
                      leading!,
                      AppSpacing.hGapMd,
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(title, style: context.typo.h1),
                          if (subtitle != null) ...<Widget>[
                            AppSpacing.gapXs,
                            Text(subtitle!, style: context.typo.bodyMuted),
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
    this.accented = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  /// Affiche une pastille violette en haut à droite (élément non lu).
  final bool badged;

  /// Fond violet clair et icône violette, pour l'action mise en avant d'un
  /// en-tête. Un seul bouton par en-tête doit la porter : deux accents côte à
  /// côte ne désignent plus rien.
  final bool accented;

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
            color: accented
                ? context.couleurs.primarySoft
                : context.couleurs.surface,
            borderRadius: BorderRadius.circular(AppSpacing.md),
            border: Border.all(
              color: accented
                  ? context.couleurs.primarySoft
                  : context.couleurs.border,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Icon(
                icon,
                size: 20,
                color: accented
                    ? context.couleurs.primary
                    : context.couleurs.encre,
              ),
              if (badged)
                Positioned(
                  top: 11,
                  right: 11,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: context.couleurs.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.couleurs.surface,
                        width: 1.5,
                      ),
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
