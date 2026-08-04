import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_card.dart';
import 'avatar_stack.dart';

/// Carte représentant un groupe : pastille colorée, nom, description,
/// participants et compteur d'activité.
///
/// Le composant reste volontairement « bête » : il ne connaît pas le modèle
/// `Group` du domaine, ce qui le garde réutilisable et testable isolément.
class GroupCard extends StatelessWidget {
  const GroupCard({
    super.key,
    required this.name,
    this.description,
    this.icon = Icons.groups_rounded,
    this.accentColor = AppColors.primary,
    this.members = const <AvatarData>[],
    this.trailingLabel,
    this.onTap,
  });

  final String name;
  final String? description;
  final IconData icon;

  /// Couleur d'identité du groupe, appliquée à la vignette.
  final Color accentColor;

  final List<AvatarData> members;

  /// Métadonnée de droite : « 3 événements », « 2 tâches »…
  final String? trailingLabel;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  // Vignette teintée : l'accent à faible opacité garde la carte
                  // légère tout en identifiant le groupe d'un coup d'œil.
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.md),
                ),
                child: Icon(icon, size: 22, color: accentColor),
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      style: AppTypography.h3,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (description != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        description!,
                        style: AppTypography.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null) ...<Widget>[
                AppSpacing.hGapSm,
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ],
            ],
          ),
          if (members.isNotEmpty || trailingLabel != null) ...<Widget>[
            AppSpacing.gapLg,
            Row(
              children: <Widget>[
                if (members.isNotEmpty) ...<Widget>[
                  AvatarStack(avatars: members, size: 28, maxVisible: 4),
                  AppSpacing.hGapMd,
                ],
                // `Expanded` plutôt qu'un `Spacer` : sur un écran étroit, le
                // libellé doit pouvoir être tronqué au lieu de déborder.
                Expanded(
                  child: Text(
                    trailingLabel ?? '',
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      fontWeight: AppTypography.medium,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
