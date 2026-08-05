import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../models/contact.dart';

/// Ligne de contact : avatar, nom, pseudo et bouton favori.
///
/// Le favori est personnel : chacun épingle de son côté, sans effet sur
/// l'autre — d'où les deux colonnes distinctes côté base.
class ContactTile extends StatelessWidget {
  const ContactTile({
    super.key,
    required this.contact,
    this.onTap,
    this.onFavoriteToggled,
    this.trailing,
  });

  final Contact contact;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggled;

  /// Remplace le bouton favori, pour les demandes en attente.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          AvatarStack(
            avatars: <AvatarData>[
              AvatarData(name: contact.fullName, imageUrl: contact.avatarUrl),
            ],
            size: 40,
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  contact.fullName,
                  style: AppTypography.body.copyWith(
                    fontWeight: AppTypography.semiBold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (contact.pseudo != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    contact.pseudoHandle,
                    style: AppTypography.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else
            IconButton(
              onPressed: onFavoriteToggled,
              visualDensity: VisualDensity.compact,
              tooltip: contact.isFavorite
                  ? 'Retirer des favoris'
                  : 'Ajouter aux favoris',
              icon: Icon(
                contact.isFavorite
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                size: 22,
                color: contact.isFavorite
                    ? AppColors.warning
                    : AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}
