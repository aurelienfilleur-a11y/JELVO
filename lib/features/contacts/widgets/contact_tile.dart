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
    this.onTapPerson,
    this.onFavoriteToggled,
    this.trailing,
    this.showSharedGroups = false,
    this.showChevron = false,
  });

  final Contact contact;

  /// Ouvre ce que la **relation** permet : épingler, retirer. C'est le geste
  /// du chevron.
  final VoidCallback? onTap;

  /// Ouvre le profil de la **personne** — l'avatar et le nom, pas la ligne
  /// entière.
  ///
  /// Les deux cibles disent deux choses différentes, et c'est délibéré : la
  /// fiche agit sur le lien qu'on a avec quelqu'un, le profil montre
  /// quelqu'un. Confondre les deux obligerait à choisir laquelle des deux
  /// disparaît, alors que « Gérer » de la bande des favoris ouvre déjà la
  /// première depuis un autre endroit.
  final VoidCallback? onTapPerson;
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
          GestureDetector(
            onTap: onTapPerson,
            child: AvatarStack(
              avatars: <AvatarData>[
                AvatarData(name: contact.fullName, imageUrl: contact.avatarUrl),
              ],
              size: 40,
            ),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: GestureDetector(
              onTap: onTapPerson,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  EmojiText(
                    contact.fullName,
                    style: context.typo.body.copyWith(
                      fontWeight: AppTypography.semiBold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (contact.pseudo != null) ...<Widget>[
                    const SizedBox(height: 2),
                    EmojiText(
                      contact.pseudoHandle,
                      style: context.typo.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
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
                    ? context.couleurs.warning
                    : context.couleurs.textSecondary,
              ),
            ),
            if (showChevron)
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: context.couleurs.textSecondary,
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
        color: context.couleurs.primarySoft,
        borderRadius: AppRadii.pillRadius,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '${contact.sharedGroups}',
            style: context.typo.caption.copyWith(
              color: context.couleurs.primary,
              fontWeight: AppTypography.semiBold,
            ),
          ),
          Text(
            contact.sharedGroups > 1 ? 'groupes' : 'groupe',
            style: context.typo.caption.copyWith(
              color: context.couleurs.primary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
