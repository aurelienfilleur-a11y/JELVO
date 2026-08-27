import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'emoji_text.dart';
import 'app_card.dart';
import 'avatar_stack.dart';
import 'cover_banner.dart';

/// Grande carte d'un groupe dans la liste : photo de couverture en bandeau,
/// puis le nom, l'effectif, la rangée d'avatars et une ligne d'activité.
///
/// Le composant reste volontairement « bête » : il ne connaît pas le modèle
/// `Group` du domaine, ce qui le garde réutilisable et testable isolément.
class GroupCard extends StatelessWidget {
  const GroupCard({
    super.key,
    required this.name,
    this.icon = Icons.groups_rounded,
    this.accentColor = AppColors.primary,
    this.photoUrl,
    this.members = const <AvatarData>[],
    this.hiddenMembers = 0,
    this.memberLabel,
    this.activityLabel,
    this.unreadCount = 0,
    this.onTap,
  });

  final String name;
  final IconData icon;

  /// Couleur d'identité du groupe, appliquée au repli du bandeau.
  final Color accentColor;

  /// Photo de couverture. Absente, `CoverBanner` retombe sur le dégradé
  /// d'accent — le même repli que partout ailleurs.
  final String? photoUrl;

  final List<AvatarData> members;

  /// Membres que la rangée ne montre pas, pour le « +N ».
  ///
  /// Il est passé plutôt que déduit : la rangée ne reçoit qu'un aperçu, et
  /// `members.length` ne dit donc pas l'effectif du groupe.
  final int hiddenMembers;

  /// « 8 membres ».
  final String? memberLabel;

  /// « 3 tâches en cours · 2 événements à venir », ou ce qui en tient lieu
  /// quand il ne se passe rien.
  final String? activityLabel;

  /// Messages non lus de la conversation. Zéro n'affiche rien.
  ///
  /// Un nombre et non un booléen : la carte a la place de le dire, là où la
  /// pastille de l'onglet ne l'a pas. Les deux ne répondent d'ailleurs pas à
  /// la même question — l'onglet dit *combien de conversations*, la carte dit
  /// *combien de messages ici*.
  final int unreadCount;

  final VoidCallback? onTap;

  /// Hauteur du bandeau. Paysage, comme sur la maquette : une photo de groupe
  /// se regarde en large, et c'est le format sous lequel elle est téléversée.
  static const double _bandeau = 132;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      // La photo va d'un bord à l'autre de la carte : sans rognage, elle
      // dépasserait des coins arrondis.
      clipContent: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CoverBanner(
            name: '',
            accentColor: accentColor,
            icon: icon,
            photoUrl: photoUrl,
            height: _bandeau,
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          EmojiText(
                            name,
                            style: AppTypography.h3,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (memberLabel != null) ...<Widget>[
                            const SizedBox(height: 2),
                            Text(
                              memberLabel!,
                              style: AppTypography.caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (members.isNotEmpty) ...<Widget>[
                      AppSpacing.hGapSm,
                      AvatarStack(
                        avatars: members,
                        size: 30,
                        // La rangée montre ce qu'elle a reçu ; le reste part
                        // dans le « +N », calculé sur l'effectif réel.
                        maxVisible: members.length,
                        extraCount: hiddenMembers,
                      ),
                    ],
                    if (unreadCount > 0) ...<Widget>[
                      AppSpacing.hGapSm,
                      _PastilleNonLus(count: unreadCount),
                    ],
                  ],
                ),
                if (activityLabel != null) ...<Widget>[
                  AppSpacing.gapSm,
                  Text(
                    activityLabel!,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
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
}

/// Le compteur de messages non lus, en pastille violette pleine.
///
/// Violet et non rouge : ce n'est pas une alerte, c'est de l'activité. Le
/// rouge de `NavBadge` sert les compteurs de la barre, qui réclament une
/// action.
class _PastilleNonLus extends StatelessWidget {
  const _PastilleNonLus({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '$count message${count > 1 ? 's' : ''} non lu'
          '${count > 1 ? 's' : ''}',
      child: Container(
        constraints: const BoxConstraints(minWidth: 26),
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        // Pastille et non cercle strict : à un chiffre les deux se
        // confondent, mais un cercle rognerait « 12 ».
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: AppRadii.pillRadius,
        ),
        alignment: Alignment.center,
        child: Text(
          count > 99 ? '99+' : '$count',
          style: AppTypography.caption.copyWith(
            color: Colors.white,
            fontWeight: AppTypography.semiBold,
          ),
        ),
      ),
    );
  }
}
