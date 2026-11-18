import 'package:flutter/material.dart';

import '../../../core/core.dart';

/// Gabarit commun aux écrans d'authentification : logo, titre, sous-titre et
/// contenu défilant, centré et plafonné en largeur pour rester lisible sur le
/// web comme sur mobile.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.onBack,
    this.stepLabel,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  /// Affiche une flèche de retour quand l'écran est empilé.
  final VoidCallback? onBack;

  /// Repère d'étape, p. ex. « Étape 1 sur 2 ».
  final String? stepLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.couleurs.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenMargin,
                AppSpacing.lg,
                AppSpacing.screenMargin,
                AppSpacing.xxl,
              ),
              children: <Widget>[
                if (onBack != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: onBack,
                      tooltip: 'Retour',
                      icon: const Icon(Icons.arrow_back_rounded),
                      style: IconButton.styleFrom(
                        foregroundColor: context.couleurs.encre,
                      ),
                    ),
                  )
                else
                  const _JelvoMark(),

                AppSpacing.gapXl,
                if (stepLabel != null) ...<Widget>[
                  Text(
                    stepLabel!,
                    style: context.typo.caption.copyWith(
                      color: context.couleurs.primary,
                      fontWeight: AppTypography.semiBold,
                    ),
                  ),
                  AppSpacing.gapXs,
                ],
                Text(title, style: context.typo.h1),
                if (subtitle != null) ...<Widget>[
                  AppSpacing.gapSm,
                  Text(subtitle!, style: context.typo.bodyMuted),
                ],
                AppSpacing.gapXl,
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pastille de marque affichée en tête des écrans racines.
class _JelvoMark extends StatelessWidget {
  const _JelvoMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                context.couleurs.primary,
                context.couleurs.primaryDark,
              ],
            ),
            borderRadius: BorderRadius.circular(AppRadii.button),
            boxShadow: context.ombres.accent,
          ),
          alignment: Alignment.center,
          child: Text(
            'J',
            style: context.typo.h2.copyWith(color: context.couleurs.onAccent),
          ),
        ),
        AppSpacing.hGapMd,
        Text('Jelvo', style: context.typo.h3),
      ],
    );
  }
}

/// Bandeau d'erreur affiché au-dessus d'un formulaire.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.couleurs.dangerSoft,
        borderRadius: AppRadii.fieldRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: context.couleurs.danger,
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Text(
              message,
              style: context.typo.caption.copyWith(
                color: context.couleurs.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
