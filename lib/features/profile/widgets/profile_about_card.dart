import 'package:flutter/material.dart';

import '../../../core/core.dart';

/// Carte « À propos » : une ligne par information, icône à gauche, libellé,
/// valeur dessous, chevron à droite quand la ligne mène quelque part.
///
/// **Deux lignes seulement**, contrairement à la maquette : Jelvo ne collecte
/// ni numéro de téléphone ni localisation. Les afficher vides aurait suggéré
/// qu'il manque quelque chose à remplir.
class ProfileAboutCard extends StatelessWidget {
  const ProfileAboutCard({
    super.key,
    required this.bio,
    required this.email,
    required this.onEditBio,
  });

  final String? bio;
  final String? email;
  final VoidCallback onEditBio;

  @override
  Widget build(BuildContext context) {
    final String? biographie = bio?.trim();

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text('À propos', style: AppTypography.h3),
          ),
          AppSpacing.gapSm,

          _Ligne(
            icon: Icons.article_outlined,
            label: 'Bio',
            // Une bio vide n'est pas un trou à cacher : la ligne reste, et
            // invite à la remplir plutôt que de disparaître.
            value: biographie == null || biographie.isEmpty
                ? 'Ajoutez quelques mots sur vous'
                : biographie,
            attenue: biographie == null || biographie.isEmpty,
            onTap: onEditBio,
          ),
          const Divider(height: 1, indent: 52, color: AppColors.border),
          _Ligne(
            icon: Icons.mail_outline_rounded,
            label: 'Email',
            value: email ?? 'Adresse indisponible',
            attenue: email == null,
            // Pas de chevron : l'adresse vient de la session, et la changer
            // relèverait d'un parcours d'authentification que Jelvo n'a pas.
            onTap: null,
          ),
        ],
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.attenue = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  /// Valeur de remplacement — bio vide, adresse absente : elle se lit en gris
  /// clair, pour ne pas passer pour une donnée réelle.
  final bool attenue;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.fieldRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: AppRadii.fieldRadius,
              ),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            AppSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: AppTypography.body.copyWith(
                      fontWeight: AppTypography.semiBold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: AppTypography.caption.copyWith(
                      color: attenue
                          ? AppColors.textSecondary
                          : AppColors.midnight,
                      fontStyle: attenue ? FontStyle.italic : null,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onTap != null) ...<Widget>[
              AppSpacing.hGapSm,
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
