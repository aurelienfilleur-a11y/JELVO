import 'package:flutter/material.dart';

import '../../../core/core.dart';

/// Les trois chiffres en tête de la carte « Mes tâches ».
@immutable
class TaskCounts {
  const TaskCounts({
    required this.open,
    required this.doneThisWeek,
    required this.overdue,
  });

  /// Tâches encore ouvertes, toutes échéances confondues.
  final int open;

  /// Terminées depuis le lundi de la semaine en cours.
  final int doneThisWeek;

  /// Ouvertes dont l'échéance est passée. **Elles comptent aussi dans
  /// [open]** : ce sont deux lectures de la même liste, pas deux paquets
  /// disjoints. Les soustraire donnerait un « à faire » qui ne correspond à
  /// aucune liste consultable.
  final int overdue;

  int get total => open + doneThisWeek;
}

/// Carte « Mes tâches » : trois compteurs, puis les tâches à traiter.
class TasksCard extends StatelessWidget {
  const TasksCard({
    super.key,
    required this.counts,
    required this.rows,
    required this.onOpenTasks,
  });

  final TaskCounts counts;

  /// Lignes déjà construites par l'écran, qui seul sait résoudre le groupe.
  final List<Widget> rows;

  final VoidCallback onOpenTasks;

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
            child: SectionHeader(
              title: 'Mes tâches',
              actionLabel: 'Voir toutes mes tâches',
              onActionPressed: onOpenTasks,
            ),
          ),
          AppSpacing.gapMd,

          Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: AppRadii.fieldRadius,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _Compteur(
                    valeur: counts.open,
                    libelle: 'À faire',
                    detail: counts.open == 1
                        ? '1 tâche'
                        : '${counts.open} tâches',
                    couleur: AppColors.primary,
                    // L'anneau montre la part **restante** de la semaine :
                    // plein quand tout est à faire, presque vide quand tout
                    // est terminé. Un anneau sans proportion ne serait qu'un
                    // ornement.
                    proportion: counts.total == 0
                        ? 0
                        : counts.open / counts.total,
                  ),
                ),
                const _Separateur(),
                Expanded(
                  child: _Compteur(
                    valeur: counts.doneThisWeek,
                    libelle: 'Terminées',
                    detail: 'cette semaine',
                    couleur: AppColors.success,
                    icone: Icons.check_rounded,
                  ),
                ),
                const _Separateur(),
                Expanded(
                  child: _Compteur(
                    valeur: counts.overdue,
                    libelle: 'En retard',
                    detail: 'à traiter',
                    couleur: AppColors.warning,
                    icone: Icons.schedule_rounded,
                  ),
                ),
              ],
            ),
          ),

          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: EmptyState(
                icon: Icons.task_alt_rounded,
                title: 'Tout est à jour',
                message: 'Aucune tâche n’attend d’être traitée.',
              ),
            )
          else ...<Widget>[
            AppSpacing.gapSm,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Column(children: rows),
            ),
          ],
        ],
      ),
    );
  }
}

class _Separateur extends StatelessWidget {
  const _Separateur();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 36,
    child: VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
  );
}

/// Un compteur : la pastille à gauche, le libellé à droite.
///
/// Le chiffre se lit **soit** dans l'anneau — quand celui-ci porte une
/// proportion, et que le nombre en est le sujet — **soit** en tête du libellé.
/// L'écrire aux deux endroits le ferait lire deux fois.
class _Compteur extends StatelessWidget {
  const _Compteur({
    required this.valeur,
    required this.libelle,
    required this.detail,
    required this.couleur,
    this.icone,
    this.proportion,
  });

  final int valeur;
  final String libelle;
  final String detail;
  final Color couleur;

  /// Pictogramme posé dans la pastille, à la place du chiffre.
  final IconData? icone;

  /// Part remplie de l'anneau, entre 0 et 1. Sans elle, l'anneau est plein.
  final double? proportion;

  bool get _chiffreDansLAnneau => icone == null;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$valeur $libelle, $detail',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 38,
            height: 38,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                CircularProgressIndicator(
                  value: proportion ?? 1,
                  strokeWidth: 3,
                  backgroundColor: couleur.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(couleur),
                ),
                if (_chiffreDansLAnneau)
                  Text(
                    '$valeur',
                    style: AppTypography.caption.copyWith(
                      fontWeight: AppTypography.semiBold,
                      color: couleur,
                    ),
                  )
                else
                  Icon(icone, size: 17, color: couleur),
              ],
            ),
          ),
          AppSpacing.hGapSm,
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  _chiffreDansLAnneau ? libelle : '$valeur $libelle',
                  style: AppTypography.caption.copyWith(
                    fontWeight: AppTypography.semiBold,
                    color: AppColors.midnight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  detail,
                  style: AppTypography.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
