import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../../groups/models/group.dart';

/// En-tête de la conversation : retour, photo du groupe, nom et effectif.
///
/// **Ni téléphone ni caméra.** La maquette pose deux pictogrammes d'appel ;
/// Jelvo n'a ni appel audio ni appel vidéo — aucune table, aucun service,
/// aucun écran. Les laisser en gris promettrait une fonctionnalité qui
/// n'arrive pas, et les laisser actifs ouvrirait sur du vide.
///
/// Toucher l'en-tête ouvre l'écran du groupe : c'est le geste attendu, et il
/// évite un chevron de plus à côté de celui de la barre de raccourcis.
class ChatHeader extends StatelessWidget implements PreferredSizeWidget {
  const ChatHeader({
    super.key,
    required this.group,
    required this.onBack,
    required this.onOpenGroup,
  });

  /// `null` tant que la liste des groupes n'est pas chargée : l'en-tête garde
  /// alors sa hauteur et son bouton de retour, sans inventer de nom.
  final Group? group;

  final VoidCallback onBack;
  final VoidCallback onOpenGroup;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final Group? g = group;

    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 64,
        child: Row(
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Retour',
              onPressed: onBack,
            ),
            Expanded(
              child: InkWell(
                onTap: g == null ? null : onOpenGroup,
                borderRadius: AppRadii.cardRadius,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    children: <Widget>[
                      _Vignette(group: g),
                      AppSpacing.hGapMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            EmojiText(
                              g?.name ?? 'Discussion',
                              style: AppTypography.h3,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (g != null)
                              Text(
                                g.memberLabel,
                                style: AppTypography.caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AppSpacing.hGapSm,
          ],
        ),
      ),
    );
  }
}

/// Photo du groupe en rond, ou son icône sur l'accent — le repli habituel.
class _Vignette extends StatelessWidget {
  const _Vignette({required this.group});

  final Group? group;

  static const double _taille = 40;

  @override
  Widget build(BuildContext context) {
    final Group? g = group;
    if (g == null) {
      return const SizedBox(width: _taille, height: _taille);
    }

    final Widget repli = Container(
      width: _taille,
      height: _taille,
      color: g.accent.color,
      alignment: Alignment.center,
      child: Icon(g.icon, size: 20, color: Colors.white),
    );

    return ClipOval(
      child: g.photoUrl == null
          ? repli
          : Image.network(
              g.photoUrl!,
              width: _taille,
              height: _taille,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => repli,
              loadingBuilder:
                  (BuildContext _, Widget enfant, ImageChunkEvent? p) =>
                      p == null ? enfant : repli,
            ),
    );
  }
}

/// Barre de raccourcis sous l'en-tête : ce qui est en cours dans le groupe.
///
/// **Deux compteurs, et non quatre.** La maquette en montre aussi « liste » et
/// « dépense » : ni les listes ni les dépenses n'existent dans Jelvo, et un
/// compteur qu'aucune donnée n'alimente vaudrait zéro pour tout le monde, pour
/// toujours. C'est la même règle que sur l'écran du groupe, et les deux qui
/// restent sortent du même endroit — `mes_taches` et `mon_agenda`, déjà
/// chargées, sans lecture de plus.
///
/// **Zéro ne se dit pas**, ici comme sur la carte d'un groupe : « 0 tâche ·
/// 0 événement » est vrai, inutile, et se lit comme un défaut de chargement.
/// Une moitié vide s'efface, et un groupe sans rien l'annonce en toutes
/// lettres — le chevron, lui, reste : c'est aussi un chemin.
///
/// Le chevron mène à l'écran du groupe, où ces deux nombres se déplient.
class ChatShortcutBar extends StatelessWidget {
  const ChatShortcutBar({
    super.key,
    required this.taches,
    required this.evenements,
    required this.onOpenGroup,
  });

  final int taches;
  final int evenements;
  final VoidCallback onOpenGroup;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        0,
        AppSpacing.screenMargin,
        AppSpacing.sm,
      ),
      child: AppCard(
        onTap: onOpenGroup,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            if (taches == 0 && evenements == 0)
              Expanded(
                child: Text(
                  'Rien de prévu pour l’instant',
                  style: AppTypography.bodyMuted,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            else ...<Widget>[
              if (taches > 0)
                _Compteur(
                  icon: Icons.check_circle_outline_rounded,
                  teinte: AppColors.success,
                  fond: AppColors.successSoft,
                  valeur: taches,
                  // Le singulier compte : « 1 tâches » se voit tout de suite.
                  libelle: taches > 1 ? 'tâches' : 'tâche',
                ),
              if (taches > 0 && evenements > 0) AppSpacing.hGapLg,
              if (evenements > 0)
                _Compteur(
                  icon: Icons.calendar_month_rounded,
                  teinte: AppColors.primary,
                  fond: AppColors.primarySoft,
                  valeur: evenements,
                  libelle: evenements > 1 ? 'événements' : 'événement',
                ),
              const Spacer(),
            ],
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _Compteur extends StatelessWidget {
  const _Compteur({
    required this.icon,
    required this.teinte,
    required this.fond,
    required this.valeur,
    required this.libelle,
  });

  final IconData icon;
  final Color teinte;
  final Color fond;
  final int valeur;
  final String libelle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: fond,
            borderRadius: AppRadii.fieldRadius,
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 17, color: teinte),
        ),
        AppSpacing.hGapSm,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '$valeur',
              style: AppTypography.body.copyWith(
                fontWeight: AppTypography.semiBold,
                height: 1.1,
              ),
            ),
            Text(libelle, style: AppTypography.caption.copyWith(height: 1.1)),
          ],
        ),
      ],
    );
  }
}
