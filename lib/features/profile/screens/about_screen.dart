import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../../../data/app_config.dart';

/// « À propos de Jelvo » : ce qu'est l'application, et sa version.
///
/// Volontairement court. Une page « à propos » qui aligne des mentions
/// légales, des licences et une politique de confidentialité que personne n'a
/// écrites serait exactement ce que cet écran s'interdit ailleurs : des lignes
/// décoratives.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('À propos de Jelvo'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Retour',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            AppSpacing.xl,
            AppSpacing.screenMargin,
            AppSpacing.xxl,
          ),
          children: <Widget>[
            Center(
              child: Image.asset(
                'web/icons/Icon-192.png',
                width: 88,
                height: 88,
                errorBuilder: (_, _, _) => Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: AppRadii.cardRadius,
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    size: 40,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            AppSpacing.gapLg,
            Center(child: Text('Jelvo', style: AppTypography.h2)),
            const SizedBox(height: 2),
            Center(
              child: Text(
                'Version ${AppConfig.version}',
                style: AppTypography.caption,
              ),
            ),

            AppSpacing.gapXxl,
            AppCard(
              child: Text(
                'Jelvo réunit vos groupes, vos événements, vos tâches et vos '
                'disponibilités au même endroit — pour la famille, les amis, '
                'la colocation.',
                style: AppTypography.bodyMuted,
              ),
            ),

            AppSpacing.gapLg,
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Bon à savoir', style: AppTypography.h3),
                  AppSpacing.gapSm,
                  Text(
                    'Jelvo est une application web installable. Sur iPhone, '
                    'les notifications ne fonctionnent qu’une fois l’icône '
                    'ajoutée à l’écran d’accueil, et l’application installée '
                    'a sa propre session : il faut s’y reconnecter.',
                    style: AppTypography.bodyMuted,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
