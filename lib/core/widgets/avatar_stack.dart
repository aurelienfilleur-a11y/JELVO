import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Une personne représentée dans un [AvatarStack].
class AvatarData {
  const AvatarData({required this.name, this.imageUrl, this.color});

  final String name;

  /// URL optionnelle ; si nulle ou en échec de chargement, on retombe sur les
  /// initiales.
  final String? imageUrl;

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
    this.overlap = 0.32,
  });

  final List<AvatarData> avatars;

  /// Diamètre d'un avatar, bordure blanche comprise.
  final double size;

  /// Nombre d'avatars affichés avant de basculer sur « +N ».
  final int maxVisible;

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
    final int overflow = avatars.length - visible.length;
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
  Widget build(BuildContext context) {
    final Color background = AvatarStack.colorFor(data, index);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surface, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: data.imageUrl == null
          ? _initials
          : Image.network(
              data.imageUrl!,
              fit: BoxFit.cover,
              width: size,
              height: size,
              errorBuilder: (_, _, _) => Center(child: _initials),
            ),
    );
  }

  Widget get _initials => Text(
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
