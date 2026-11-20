import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../providers/profile_providers.dart';

/// Carte « Mes statistiques » : trois compteurs, tous lus sur des listes que
/// l'application charge déjà.
///
/// **Aucun chiffre n'est inventé**, et le troisième porte un libellé plus
/// prudent que la maquette : « Tâches terminées » et non « réalisées ».
/// `tasks` ne connaît que `completed_at`, jamais qui a coché — attribuer
/// l'action à quelqu'un serait une invention.
class ProfileStatsCard extends StatelessWidget {
  const ProfileStatsCard({
    super.key,
    required this.stats,
    this.titre = 'Mes statistiques',
    this.onOpenGroups,
    this.onOpenCalendar,
    this.onOpenTasks,
  });

  final ProfileStats stats;

  /// « Mes statistiques » sur son propre profil, « Ses statistiques » sur
  /// celui de quelqu'un d'autre.
  final String titre;

  /// Les trois ouvrent **la liste que le compteur résume** — un chiffre qu'on
  /// ne peut pas ouvrir n'apprend rien de plus que lui-même.
  ///
  /// `null` sur le profil de quelqu'un d'autre, et le compteur n'est alors pas
  /// touchable : les listes de l'application sont les **siennes**, et ouvrir
  /// « ses groupes » depuis le profil de Léa montrerait les miens. Une
  /// destination qui ne tient pas sa promesse est pire qu'une absence de
  /// destination.
  final VoidCallback? onOpenGroups;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenTasks;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text(titre, style: context.typo.h3),
          ),
          AppSpacing.gapMd,
          Row(
            children: <Widget>[
              Expanded(
                child: _Compteur(
                  icon: Icons.groups_2_rounded,
                  couleur: context.couleurs.primary,
                  fond: context.couleurs.primarySoft,
                  valeur: stats.groups,
                  libelle: 'Groupes',
                  onTap: onOpenGroups,
                ),
              ),
              const _Trait(),
              Expanded(
                child: _Compteur(
                  icon: Icons.event_rounded,
                  couleur: context.couleurs.success,
                  fond: context.couleurs.successSoft,
                  valeur: stats.events,
                  libelle: 'Événements',
                  onTap: onOpenCalendar,
                ),
              ),
              const _Trait(),
              Expanded(
                child: _Compteur(
                  icon: Icons.task_alt_rounded,
                  couleur: context.couleurs.warning,
                  fond: context.couleurs.warningSoft,
                  valeur: stats.completedTasks,
                  libelle: 'Tâches terminées',
                  onTap: onOpenTasks,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Trait extends StatelessWidget {
  const _Trait();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 72,
    child: VerticalDivider(
      width: 1,
      thickness: 1,
      color: context.couleurs.border,
    ),
  );
}

class _Compteur extends StatelessWidget {
  const _Compteur({
    required this.icon,
    required this.couleur,
    required this.fond,
    required this.valeur,
    required this.libelle,
    required this.onTap,
  });

  final IconData icon;
  final Color couleur;
  final Color fond;
  final int valeur;
  final String libelle;

  /// Chaque compteur mène à la liste qu'il résume : un chiffre qu'on ne peut
  /// pas ouvrir n'apprend rien de plus que lui-même.
  /// `null` rend le compteur inerte — sans `InkWell`, donc sans effet de
  /// pression qui promettrait une ouverture.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: '$valeur $libelle',
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.fieldRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: fond,
                  borderRadius: AppRadii.fieldRadius,
                ),
                child: Icon(icon, size: 19, color: couleur),
              ),
              AppSpacing.gapSm,
              Text('$valeur', style: context.typo.h2),
              const SizedBox(height: 2),
              Text(
                libelle,
                style: context.typo.caption,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
