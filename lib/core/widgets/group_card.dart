import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
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
    this.unreadCount = 0,
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

  /// Messages non lus de la conversation. Zéro n'affiche rien.
  ///
  /// Un nombre et non un booléen : la carte a la place de le dire, là où la
  /// pastille de l'onglet ne l'a pas. Les deux ne répondent d'ailleurs pas à
  /// la même question — l'onglet dit *combien de conversations*, la carte dit
  /// *combien de messages ici*.
  final int unreadCount;

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
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            name,
                            style: AppTypography.h3,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (unreadCount > 0) ...<Widget>[
                          AppSpacing.hGapSm,
                          _PastilleNonLus(count: unreadCount),
                        ],
                      ],
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

/// Compteur de messages non lus posé à côté du nom du groupe.
///
/// Violet plein plutôt que rouge : ce n'est pas une alerte, c'est une
/// conversation qui attend. Le rouge de [NavBadge] est réservé à ce qui
/// demande une décision — une invitation, une demande de contact.
class _PastilleNonLus extends StatelessWidget {
  const _PastilleNonLus({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: count == 1 ? '1 message non lu' : '$count messages non lus',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        constraints: const BoxConstraints(minWidth: 20),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Text(
          count > 99 ? '99+' : '$count',
          textAlign: TextAlign.center,
          style: AppTypography.caption.copyWith(
            color: Colors.white,
            fontWeight: AppTypography.semiBold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
