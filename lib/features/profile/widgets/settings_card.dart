import 'package:flutter/material.dart';

import '../../../core/core.dart';

/// Une carte titrée de l'écran Paramètres, et ses lignes.
///
/// Le titre est **hors** de la carte dans le reste de l'application
/// (`SectionHeader`) ; ici il est dedans, comme sur la maquette : quatre
/// blocs qui se lisent chacun d'un coup d'œil.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.titre, required this.lignes});

  final String titre;
  final List<Widget> lignes;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text(titre, style: context.typo.h3),
          ),
          for (int i = 0; i < lignes.length; i++) ...<Widget>[
            if (i > 0)
              Divider(height: 1, indent: 44, color: context.couleurs.border),
            lignes[i],
          ],
        ],
      ),
    );
  }
}

/// Une ligne de réglage : icône, libellé, valeur courante en violet, chevron.
///
/// **Aucune ligne ne s'affiche sans mener quelque part.** [onTap] est
/// obligatoire, et le chevron l'accompagne : c'est la règle déjà posée pour
/// l'e-mail du profil — un chevron qui n'ouvre rien est pire qu'une ligne
/// inerte.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icone,
    required this.libelle,
    required this.onTap,
    this.valeur,
    this.couleurValeur,
    this.destructif = false,
  });

  final IconData icone;
  final String libelle;
  final VoidCallback onTap;

  /// L'état courant, à droite. Omise quand la ligne n'a rien à annoncer.
  final String? valeur;

  final Color? couleurValeur;

  /// Rouge, sans chevron : une action, pas un réglage.
  final bool destructif;

  @override
  Widget build(BuildContext context) {
    final Color teinte = destructif
        ? context.couleurs.danger
        : context.couleurs.encre;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.fieldRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              icone,
              size: 20,
              color: destructif
                  ? context.couleurs.danger
                  : context.couleurs.primary,
            ),
            AppSpacing.hGapMd,
            Expanded(
              child: Text(
                libelle,
                style: context.typo.body.copyWith(color: teinte),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (valeur != null) ...<Widget>[
              AppSpacing.hGapSm,
              Flexible(
                child: Text(
                  valeur!,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typo.caption.copyWith(
                    color: couleurValeur ?? context.couleurs.primary,
                    fontWeight: AppTypography.semiBold,
                  ),
                ),
              ),
            ],
            if (!destructif) ...<Widget>[
              AppSpacing.hGapSm,
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: context.couleurs.textSecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
