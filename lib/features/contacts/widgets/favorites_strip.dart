import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../models/contact.dart';

/// Bande horizontale des favoris, en tête du carnet.
///
/// Elle ne crée aucun mécanisme : le favori existe déjà, personnel et posé
/// d'une étoile sur la ligne du contact. Elle ne fait que **remonter** ceux
/// qu'on a marqués là où on les cherche — en haut, à portée de pouce.
///
/// Pas de pastille de présence : `profiles.last_seen_at` n'est écrit nulle
/// part, et un point vert permanent serait un mensonge — même règle que sur
/// l'accueil et le profil.
class FavoritesStrip extends StatelessWidget {
  const FavoritesStrip({
    super.key,
    required this.favoris,
    required this.onGerer,
    this.onTapContact,
  });

  final List<Contact> favoris;
  final VoidCallback onGerer;
  final void Function(Contact)? onTapContact;

  static const double hauteur = 132;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: AppSpacing.screenHorizontal,
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.star_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              AppSpacing.hGapSm,
              Expanded(child: Text('Favoris', style: AppTypography.h3)),
              TextButton(onPressed: onGerer, child: const Text('Gérer')),
            ],
          ),
        ),
        AppSpacing.gapSm,

        if (favoris.isEmpty)
          // **La bande ne disparaît pas quand il y a des contacts à épingler**
          // : elle dit à quoi elle sert, exactement au moment où le geste est
          // possible. Elle n'apparaît en revanche pas sur un carnet vide —
          // ce serait la deuxième invitation d'affilée sur un écran qui n'a
          // encore rien.
          Padding(
            padding: AppSpacing.screenHorizontal,
            child: AppCard(
              onTap: onGerer,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.star_border_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  AppSpacing.hGapMd,
                  Expanded(
                    child: Text(
                      'Épinglez vos proches pour les retrouver ici.',
                      style: AppTypography.caption,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: hauteur,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: AppSpacing.screenHorizontal,
              itemCount: favoris.length,
              separatorBuilder: (_, _) => AppSpacing.hGapMd,
              itemBuilder: (BuildContext context, int index) =>
                  _Vignette(contact: favoris[index], onTap: onTapContact),
            ),
          ),
      ],
    );
  }
}

/// Une petite carte : le visage, puis le prénom.
class _Vignette extends StatelessWidget {
  const _Vignette({required this.contact, this.onTap});

  final Contact contact;
  final void Function(Contact)? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: AppCard(
        onTap: onTap == null ? null : () => onTap!(contact),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            AvatarImage(
              data: AvatarData(
                name: contact.fullName,
                imageUrl: contact.avatarUrl,
              ),
              size: 52,
            ),
            AppSpacing.gapSm,
            Text(
              contact.shortName,
              style: AppTypography.caption.copyWith(
                color: AppColors.midnight,
                fontWeight: AppTypography.semiBold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
