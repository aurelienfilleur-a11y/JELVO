import 'package:flutter/material.dart';

import 'jelvo_colors.dart';

/// Ombres Jelvo : très douces, opacité toujours ≤ 0,06.
///
/// L'élévation Material n'est pas utilisée directement ; on préfère des
/// `BoxShadow` explicites pour garder la même douceur sur web et mobile.
///
///
/// EN SOMBRE, L'OMBRE NE SÉPARE PLUS RIEN
///
/// Une ombre noire à 4 % sur un fond presque noir est **invisible** : elle ne
/// fait pas décoller la carte, elle ne fait rien du tout. C'est l'écart de
/// clarté entre `surface` et `background` qui porte alors seul la séparation,
/// et c'est pour cela que la carte sombre est plus claire que son fond.
///
/// Les ombres ne sont pas supprimées pour autant — leur opacité est doublée,
/// ce qui creuse très légèrement le pourtour sans dessiner un halo. La seule
/// qui garde tout son sens est [accent], colorée : un halo violet sous le
/// bouton central se voit sur n'importe quel fond.
class AppShadows {
  const AppShadows(this._couleurs, {required this.sombre});

  final JelvoColors _couleurs;
  final bool sombre;

  /// Ombre des cartes au repos.
  List<BoxShadow> get card => <BoxShadow>[
    BoxShadow(
      color: _couleurs.shadow.withValues(alpha: sombre ? 0.08 : 0.04),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  /// Ombre légèrement plus marquée pour un élément survolé ou pressé.
  List<BoxShadow> get raised => <BoxShadow>[
    BoxShadow(
      color: _couleurs.shadow.withValues(alpha: sombre ? 0.12 : 0.06),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  /// Ombre de la barre de navigation et des bottom sheets (portée vers le
  /// haut).
  List<BoxShadow> get overlay => <BoxShadow>[
    BoxShadow(
      color: _couleurs.shadow.withValues(alpha: sombre ? 0.12 : 0.06),
      blurRadius: 20,
      offset: const Offset(0, -4),
    ),
  ];

  /// Halo coloré sous le bouton d'action central.
  List<BoxShadow> get accent => <BoxShadow>[
    BoxShadow(
      color: _couleurs.primary.withValues(alpha: sombre ? 0.22 : 0.06),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];
}

/// `context.ombres.card` — l'accès unique aux ombres.
extension OmbresDuContexte on BuildContext {
  AppShadows get ombres => AppShadows(
    couleurs,
    sombre: Theme.of(this).brightness == Brightness.dark,
  );
}
