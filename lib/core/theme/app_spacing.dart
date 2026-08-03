import 'package:flutter/widgets.dart';

/// Échelle d'espacement Jelvo : 4 / 8 / 12 / 16 / 24 / 32.
///
/// Toute marge ou tout padding doit provenir de cette échelle.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Marge horizontale standard d'un écran.
  static const double screenMargin = lg;

  /// Padding horizontal prêt à l'emploi pour le contenu d'un écran.
  static const EdgeInsets screenHorizontal = EdgeInsets.symmetric(
    horizontal: screenMargin,
  );

  /// Padding complet d'un écran défilant.
  static const EdgeInsets screenAll = EdgeInsets.all(screenMargin);

  // Séparateurs verticaux réutilisables, pour éviter les `SizedBox` magiques.
  static const Widget gapXs = SizedBox(height: xs);
  static const Widget gapSm = SizedBox(height: sm);
  static const Widget gapMd = SizedBox(height: md);
  static const Widget gapLg = SizedBox(height: lg);
  static const Widget gapXl = SizedBox(height: xl);
  static const Widget gapXxl = SizedBox(height: xxl);

  // Séparateurs horizontaux.
  static const Widget hGapXs = SizedBox(width: xs);
  static const Widget hGapSm = SizedBox(width: sm);
  static const Widget hGapMd = SizedBox(width: md);
  static const Widget hGapLg = SizedBox(width: lg);
}
