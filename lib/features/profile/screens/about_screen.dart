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
      backgroundColor: context.couleurs.background,
      appBar: AppBar(
        title: Text(AppTexts.of(context).profileProposJelvo),
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
                    color: context.couleurs.primarySoft,
                    borderRadius: AppRadii.cardRadius,
                  ),
                  child: Icon(
                    Icons.calendar_month_rounded,
                    size: 40,
                    color: context.couleurs.primary,
                  ),
                ),
              ),
            ),
            AppSpacing.gapLg,
            Center(child: Text('Jelvo', style: context.typo.h2)),
            const SizedBox(height: 2),
            Center(
              child: Text(
                AppTexts.of(context).profileVersion(AppConfig.version),
                style: context.typo.caption,
              ),
            ),

            AppSpacing.gapXxl,
            AppCard(
              child: Text(
                AppTexts.of(context).profileJelvoReunitGroupesEvenements,
                style: context.typo.bodyMuted,
              ),
            ),

            AppSpacing.gapLg,
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    AppTexts.of(context).profileBonSavoir,
                    style: context.typo.h3,
                  ),
                  AppSpacing.gapSm,
                  Text(
                    AppTexts.of(context).profileJelvoApplicationWebInstallable,
                    style: context.typo.bodyMuted,
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
