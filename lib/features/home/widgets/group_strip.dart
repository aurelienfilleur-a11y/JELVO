import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../../groups/models/group.dart';

/// Bande horizontale des groupes, photo de couverture en tête de carte.
///
/// Le défilement horizontal est ce qui permet d'en montrer quatre ou cinq sans
/// pousser le reste de l'accueil hors de l'écran. Une grille les aurait tous
/// affichés, et l'agenda serait passé sous la ligne de flottaison.
class GroupStrip extends StatelessWidget {
  const GroupStrip({super.key, required this.groups, required this.onOpen});

  final List<Group> groups;
  final ValueChanged<Group> onOpen;

  static const double _largeurCarte = 150;
  static const double _hauteurPhoto = 108;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Hauteur fixée : la carte contient une photo de hauteur connue, deux
      // lignes de texte et les marges. Sans cela, la bande se calerait sur la
      // plus haute et danserait d'un groupe à l'autre.
      height: _hauteurPhoto + 82,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: AppSpacing.screenHorizontal,
        itemCount: groups.length,
        separatorBuilder: (_, _) => AppSpacing.hGapMd,
        itemBuilder: (BuildContext context, int index) => _Carte(
          group: groups[index],
          largeur: _largeurCarte,
          hauteurPhoto: _hauteurPhoto,
          onTap: () => onOpen(groups[index]),
        ),
      ),
    );
  }
}

class _Carte extends StatelessWidget {
  const _Carte({
    required this.group,
    required this.largeur,
    required this.hauteurPhoto,
    required this.onTap,
  });

  final Group group;
  final double largeur;
  final double hauteurPhoto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: largeur,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.cardRadius,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: AppRadii.fieldRadius,
                child: SizedBox(
                  height: hauteurPhoto,
                  width: double.infinity,
                  child: _Couverture(group: group),
                ),
              ),
              AppSpacing.gapSm,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      group.name,
                      style: context.typo.body.copyWith(
                        fontWeight: AppTypography.semiBold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      group.memberLabel,
                      style: context.typo.caption,
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
    );
  }
}

/// Photo de couverture, ou son repli.
///
/// **Le repli n'invente pas de catégorie.** `groups` ne porte ni thème ni
/// pictogramme : poser une icône de valise sur « Voyage Italie » supposerait
/// de deviner à quoi sert le groupe d'après son nom. On affiche l'initiale sur
/// l'accent dérivé de l'identifiant — la même couleur que partout ailleurs
/// pour ce groupe, donc reconnaissable, et vraie.
class _Couverture extends StatelessWidget {
  const _Couverture({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final String? url = group.photoUrl;
    if (url == null || url.isEmpty) return _Repli(group: group);

    return Image.network(
      url,
      fit: BoxFit.cover,
      // Une URL morte — bucket vidé, lien expiré — ne doit pas laisser un
      // rectangle gris : on retombe sur le même repli que l'absence de photo.
      errorBuilder: (_, _, _) => _Repli(group: group),
      loadingBuilder:
          (BuildContext context, Widget child, ImageChunkEvent? progres) {
            if (progres == null) return child;
            return _Repli(group: group);
          },
    );
  }
}

class _Repli extends StatelessWidget {
  const _Repli({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final Color accent = group.accent.color(context.couleurs);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            accent.withValues(alpha: 0.22),
            accent.withValues(alpha: 0.10),
          ],
        ),
      ),
      child: Center(
        child: Text(
          _initiale(group.name),
          style: context.typo.h1.copyWith(color: accent),
        ),
      ),
    );
  }

  /// Première lettre du nom, en capitale. Un nom vide ne peut pas arriver —
  /// la création l'interdit — mais un `[0]` sur une chaîne vide lèverait, et
  /// une exception dans une carte de liste vide tout l'écran.
  static String _initiale(String nom) {
    final String propre = nom.trim();
    return propre.isEmpty ? '?' : propre.characters.first.toUpperCase();
  }
}
