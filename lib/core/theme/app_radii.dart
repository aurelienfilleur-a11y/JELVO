import 'package:flutter/widgets.dart';

/// Rayons d'arrondi Jelvo.
///
/// Cartes 16 · boutons 14 · champs 12 · bottom sheets 24 (coins hauts).
abstract final class AppRadii {
  static const double card = 16;
  static const double button = 14;
  static const double field = 12;
  static const double sheet = 24;

  /// Rayon des pastilles / puces / avatars carrés.
  static const double pill = 999;

  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(card),
  );
  static const BorderRadius buttonRadius = BorderRadius.all(
    Radius.circular(button),
  );
  static const BorderRadius fieldRadius = BorderRadius.all(
    Radius.circular(field),
  );
  static const BorderRadius pillRadius = BorderRadius.all(
    Radius.circular(pill),
  );

  /// Coins hauts arrondis des bottom sheets.
  static const BorderRadius sheetRadius = BorderRadius.only(
    topLeft: Radius.circular(sheet),
    topRight: Radius.circular(sheet),
  );
}
