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
    this.showSharedGroups = false,
    this.showChevron = false,
  });

  final Contact contact;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggled;

  /// Remplace le bouton favori, pour les demandes en attente.
  final Widget? trailing;

  /// Pastille du nombre de groupes en commun. Réservée au carnet : une
  /// demande encore en attente n'en partage aucun par définition.
  final bool showSharedGroups;

  /// Chevron d'ouverture. Il n'apparaît que si la ligne mène quelque part —
  /// un chevron qui n'ouvre rien est pire qu'une ligne inerte.
  final bool showChevron;

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
                EmojiText(
                  contact.fullName,
                  style: AppTypography.body.copyWith(
                    fontWeight: AppTypography.semiBold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (contact.pseudo != null) ...<Widget>[
                  const SizedBox(height: 2),
                  EmojiText(
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
          else ...<Widget>[
            if (showSharedGroups) _PastilleGroupes(contact: contact),
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
            if (showChevron)
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
          ],
        ],
      ),
    );
  }
}

/// Le nombre de groupes partagés, dans une pastille.
///
/// Zéro se dit aussi : « 0 groupe » est une information — on se connaît sans
/// rien organiser ensemble —, là où une pastille absente se lirait comme une
/// donnée manquante.
class _PastilleGroupes extends StatelessWidget {
  const _PastilleGroupes({required this.contact});

  final Contact contact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: AppRadii.pillRadius,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '${contact.sharedGroups}',
            style: AppTypography.caption.copyWith(
              color: AppColors.primary,
              fontWeight: AppTypography.semiBold,
            ),
          ),
          Text(
            contact.sharedGroups > 1 ? 'groupes' : 'groupe',
            style: AppTypography.caption.copyWith(
              color: AppColors.primary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
