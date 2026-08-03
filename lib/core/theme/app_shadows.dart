import 'package:flutter/widgets.dart';

/// Ombres Jelvo : très douces, opacité toujours ≤ 0,06.
///
/// L'élévation Material n'est pas utilisée directement ; on préfère des
/// `BoxShadow` explicites pour garder la même douceur sur web et mobile.
abstract final class AppShadows {
  /// Ombre des cartes au repos.
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(
      color: Color(0x0A12122B), // midnight @ 4 %
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  /// Ombre légèrement plus marquée pour un élément survolé ou pressé.
  static const List<BoxShadow> raised = <BoxShadow>[
    BoxShadow(
      color: Color(0x0F12122B), // midnight @ 6 %
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  /// Ombre de la barre de navigation et des bottom sheets (portée vers le haut).
  static const List<BoxShadow> overlay = <BoxShadow>[
    BoxShadow(
      color: Color(0x0F12122B), // midnight @ 6 %
      blurRadius: 20,
      offset: Offset(0, -4),
    ),
  ];

  /// Halo coloré sous le bouton d'action central.
  static const List<BoxShadow> accent = <BoxShadow>[
    BoxShadow(
      color: Color(0x0F5B2EFF), // primary @ 6 %
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
  ];
}
