import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Une personne représentée dans un [AvatarStack].
class AvatarData {
  const AvatarData({required this.name, this.imageUrl, this.color});

  final String name;

  /// Avatar à afficher, tel que le renvoient les fonctions SQL de lecture.
  ///
  /// Deux formes possibles, et une seule règle pour les distinguer :
  ///
  ///   - `preset:p2_07` — un des avatars prédéfinis embarqués ;
  ///   - toute autre valeur — l'URL d'une photo téléversée.
  ///
  /// La résolution est faite **ici et nulle part ailleurs** : c'est ce qui a
  /// permis d'ajouter les avatars prédéfinis sans toucher aux dix écrans qui
  /// construisent un `AvatarData` à partir d'un simple champ texte.
  ///
  /// Nulle, illisible ou introuvable, on retombe sur les initiales.
  final String? imageUrl;

  /// Préfixe d'un avatar prédéfini dans [imageUrl].
  static const String prefixePredefini = 'preset:';

  /// Chemin d'asset d'un avatar prédéfini, ou `null` si la valeur désigne une
  /// photo.
  ///
  /// L'appartenance au catalogue n'est **pas** vérifiée : un identifiant
  /// inconnu donne un chemin qui n'existe pas, et le rendu retombe sur les
  /// initiales par son `errorBuilder`. Le noyau n'a donc pas à connaître la
  /// liste des quatre-vingt-treize fichiers.
  static String? assetPourAvatar(String? valeur) {
    if (valeur == null || !valeur.startsWith(prefixePredefini)) return null;
    final String id = valeur.substring(prefixePredefini.length);
    return id.isEmpty ? null : 'assets/avatars/$id.png';
  }

  /// Couleur de fond forcée. Par défaut, dérivée du nom (stable entre deux
  /// rendus, contrairement à un tirage aléatoire).
  final Color? color;

  /// Une ou deux lettres tirées du nom.
  String get initials {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

/// Avatars superposés avec compteur de dépassement (« +3 »).
///
/// Utilisé sur `GroupCard` et `EventCard` pour montrer les participants sans
/// prendre plus de place qu'une ligne de texte.
class AvatarStack extends StatelessWidget {
  const AvatarStack({
    super.key,
    required this.avatars,
    this.size = 32,
    this.maxVisible = 4,
    this.extraCount = 0,
    this.overlap = 0.32,
  });

  final List<AvatarData> avatars;

  /// Diamètre d'un avatar, bordure blanche comprise.
  final double size;

  /// Nombre d'avatars affichés avant de basculer sur « +N ».
  final int maxVisible;

  /// Personnes à compter dans le « +N » **au-delà** de [avatars].
  ///
  /// La liste des groupes ne reçoit qu'un aperçu de quatre membres : sans
  /// cela, un groupe de huit afficherait quatre visages et aucun reste.
  final int extraCount;

  /// Part du diamètre recouverte par l'avatar suivant (0 = pas de chevauchement).
  final double overlap;

  static const List<Color> _palette = <Color>[
    AppColors.primary,
    AppColors.primaryDark,
    AppColors.success,
    AppColors.warning,
    AppColors.danger,
    AppColors.midnight,
  ];

  @override
  Widget build(BuildContext context) {
    if (avatars.isEmpty) return const SizedBox.shrink();

    final List<AvatarData> visible = avatars.take(maxVisible).toList();
    final int overflow = avatars.length - visible.length + extraCount;
    final double step = size * (1 - overlap);
    final int slots = visible.length + (overflow > 0 ? 1 : 0);
    final double width = step * (slots - 1) + size;

    return Semantics(
      label: '${avatars.length} participants',
      child: SizedBox(
        height: size,
        width: width,
        child: Stack(
          children: <Widget>[
            for (int i = 0; i < visible.length; i++)
              Positioned(
                left: i * step,
                child: _Avatar(data: visible[i], size: size, index: i),
              ),
            if (overflow > 0)
              Positioned(
                left: visible.length * step,
                child: _OverflowBadge(count: overflow, size: size),
              ),
          ],
        ),
      ),
    );
  }

  static Color colorFor(AvatarData data, int index) =>
      data.color ?? _palette[(data.name.hashCode + index) % _palette.length];
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.data, required this.size, required this.index});

  final AvatarData data;
  final double size;
  final int index;

  @override
  Widget build(BuildContext context) => AvatarImage(
    data: data,
    size: size,
    index: index,
    border: Border.all(color: AppColors.surface, width: 2),
  );
}

/// Un avatar rond : image prédéfinie, photo, ou initiales — dans cet ordre.
///
/// **Le seul endroit qui sait rendre un avatar.** Chaque écran qui en affiche
/// un passe par ici, si bien qu'une nouvelle forme d'avatar ne demande qu'une
/// modification.
class AvatarImage extends StatelessWidget {
  const AvatarImage({
    super.key,
    required this.data,
    required this.size,
    this.index = 0,
    this.border,
  });

  final AvatarData data;
  final double size;
  final int index;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final String? asset = AvatarData.assetPourAvatar(data.imageUrl);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AvatarStack.colorFor(data, index),
        shape: BoxShape.circle,
        border: border,
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: switch ((asset, data.imageUrl)) {
        (final String chemin, _) => Image.asset(
          chemin,
          fit: BoxFit.cover,
          width: size,
          height: size,
          errorBuilder: (_, _, _) => Center(child: _initiales),
        ),
        (null, final String url) => Image.network(
          url,
          fit: BoxFit.cover,
          width: size,
          height: size,
          errorBuilder: (_, _, _) => Center(child: _initiales),
        ),
        _ => _initiales,
      },
    );
  }

  Widget get _initiales => Text(
    data.initials,
    style: AppTypography.caption.copyWith(
      color: Colors.white,
      fontWeight: AppTypography.semiBold,
      fontSize: size * 0.36,
      height: 1,
    ),
  );
}

class _OverflowBadge extends StatelessWidget {
  const _OverflowBadge({required this.count, required this.size});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.background,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surface, width: 2),
      ),
      child: Text(
        '+$count',
        style: AppTypography.caption.copyWith(
          color: AppColors.textSecondary,
          fontWeight: AppTypography.semiBold,
          fontSize: size * 0.32,
          height: 1,
        ),
      ),
    );
  }
}
