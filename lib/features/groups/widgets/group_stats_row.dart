import 'package:flutter/material.dart';

import '../../../core/core.dart';

/// Rangée de compteurs du groupe.
///
/// **Deux compteurs, et non quatre.** La maquette en montrait aussi « listes
/// actives » et « notes » : ni les listes ni les notes n'existent dans Jelvo,
/// et un compteur qu'aucune donnée n'alimente vaudrait zéro pour tout le monde,
/// pour toujours. Les deux qui restent sortent proprement de la base — voir
/// `groupStatsProvider`.
///
/// Chaque compteur **ouvre la liste qu'il résume** : un chiffre qu'on ne peut
/// pas ouvrir n'apprend rien de plus que lui-même. C'est la règle déjà tenue
/// par les statistiques du profil.
class GroupStatsRow extends StatelessWidget {
  const GroupStatsRow({
    super.key,
    required this.tachesEnRetard,
    required this.evenementsAVenir,
    required this.onTachesPressed,
    required this.onEvenementsPressed,
  });

  final int tachesEnRetard;
  final int evenementsAVenir;
  final VoidCallback onTachesPressed;
  final VoidCallback onEvenementsPressed;

  @override
  Widget build(BuildContext context) {
    // `IntrinsicHeight` et non `CrossAxisAlignment.stretch` : la rangée vit
    // dans une colonne sans hauteur bornée, où `stretch` demanderait une
    // hauteur infinie. Les deux cartes gardent ainsi la même hauteur quel que
    // soit le nombre de chiffres.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: _Compteur(
              valeur: tachesEnRetard,
              // Deux lignes, comme sur la maquette, et la hauteur est donc la
              // même que le compteur voisin.
              libelle: 'tâches\nen retard',
              icon: Icons.schedule_rounded,
              // Rouge seulement s'il y a du retard : une pastille rouge sur un
              // zéro annoncerait un problème qui n'existe pas.
              couleur: tachesEnRetard > 0
                  ? AppColors.danger
                  : AppColors.textSecondary,
              fond: tachesEnRetard > 0
                  ? AppColors.dangerSoft
                  : AppColors.background,
              onPressed: onTachesPressed,
            ),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: _Compteur(
              valeur: evenementsAVenir,
              libelle: 'événements\nà venir',
              icon: Icons.calendar_month_rounded,
              couleur: AppColors.primary,
              fond: AppColors.primarySoft,
              onPressed: onEvenementsPressed,
            ),
          ),
        ],
      ),
    );
  }
}

class _Compteur extends StatelessWidget {
  const _Compteur({
    required this.valeur,
    required this.libelle,
    required this.icon,
    required this.couleur,
    required this.fond,
    required this.onPressed,
  });

  final int valeur;
  final String libelle;
  final IconData icon;
  final Color couleur;
  final Color fond;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onPressed,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('$valeur', style: AppTypography.h1),
                const SizedBox(height: 2),
                Text(
                  libelle,
                  style: AppTypography.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          AppSpacing.hGapSm,
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: fond,
              borderRadius: AppRadii.fieldRadius,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: couleur),
          ),
        ],
      ),
    );
  }
}
