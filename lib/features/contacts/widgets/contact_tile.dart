import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../models/contact.dart';

/// Ligne de contact : avatar, nom, e-mail, relation et bouton favori.
class ContactTile extends StatelessWidget {
  const ContactTile({
    super.key,
    required this.contact,
    this.onTap,
    this.onFavoriteToggled,
  });

  final Contact contact;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggled;

  @override
  Widget build(BuildContext context) {
    final AvatarData avatar = AvatarData(
      name: contact.fullName,
      imageUrl: contact.avatarUrl,
    );

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          AvatarStack(avatars: <AvatarData>[avatar], size: 40),
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
                const SizedBox(height: 2),
                Text(
                  contact.email ?? contact.phone ?? contact.relation.label,
                  style: AppTypography.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (contact.sharesCalendar) ...<Widget>[
            AppSpacing.hGapSm,
            const StatusDot(
              tone: StatusTone.success,
              label: 'Agenda',
              filled: true,
            ),
          ],
          AppSpacing.hGapSm,
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
