import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'jelvo_colors.dart';

/// Échelle typographique Jelvo, basée sur la police Inter.
///
/// H1 28 bold · H2 22 bold · H3 17 semibold · body 15 · caption 13 ·
/// bouton 16 semibold.
///
/// **Les styles portent leur couleur, et elle dépend du thème** : `caption`
/// est en `textSecondary`, les autres en `encre`. Ils se prennent donc au
/// contexte — `context.typo.caption` —, jamais en statique. La seule
/// exception est [textTheme], qui reçoit la palette explicitement puisqu'elle
/// est construite *avec* le thème et ne peut pas le lire.
class AppTypography {
  const AppTypography(this._couleurs);

  final JelvoColors _couleurs;

  /// Famille de la police d'emojis embarquée.
  static const String emojiFamily = 'NotoColorEmoji';

  /// Police de repli des emojis, appliquée à **tous** les styles.
  ///
  /// Le web ne garantit aucune police d'emojis : selon la machine, un emoji
  /// s'affichait en couleur, en noir et blanc, ou pas du tout. Inter n'ayant
  /// presque aucun glyphe d'emoji, le moteur descend ici pour eux — et pour
  /// eux seuls : le texte latin ne change pas d'un pixel.
  ///
  /// **Le repli ne suffit pas, et c'est le point à connaître.** Il n'est
  /// consulté que pour les caractères qu'Inter ne couvre **pas** — or Inter
  /// couvre `❤ ⚠ ☀ ⬆ © ‼ ⁉` et une trentaine d'autres, qui sortaient donc en
  /// noir. Le texte saisi par quelqu'un passe pour cette raison par
  /// `EmojiText`, qui donne la police d'emojis en police *principale* aux
  /// suites concernées. Voir `core/theme/emoji_runs.dart`.
  static const List<String> emojiFallback = <String>[emojiFamily];

  /// Style d'une suite d'emojis : la police d'emojis en **principale**.
  ///
  /// `fontFamilyFallback` est vidé volontairement — le repli d'Inter n'a rien
  /// à faire ici, et le laisser rouvrirait précisément la porte qu'on ferme.
  /// Le repli du système, lui, reste toujours en dernier recours : une grappe
  /// mal classée s'affiche donc, elle ne devient pas un carré vide.
  static TextStyle emoji(TextStyle base) => base.copyWith(
    fontFamily: emojiFamily,
    fontFamilyFallback: const <String>[],
  );

  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  TextStyle get h1 => _avecEmojis(
    GoogleFonts.inter(
      fontSize: 28,
      fontWeight: bold,
      height: 1.2,
      letterSpacing: -0.4,
      color: _couleurs.encre,
    ),
  );

  TextStyle get h2 => _avecEmojis(
    GoogleFonts.inter(
      fontSize: 22,
      fontWeight: bold,
      height: 1.25,
      letterSpacing: -0.3,
      color: _couleurs.encre,
    ),
  );

  TextStyle get h3 => _avecEmojis(
    GoogleFonts.inter(
      fontSize: 17,
      fontWeight: semiBold,
      height: 1.3,
      letterSpacing: -0.1,
      color: _couleurs.encre,
    ),
  );

  TextStyle get body => _avecEmojis(
    GoogleFonts.inter(
      fontSize: 15,
      fontWeight: regular,
      height: 1.45,
      color: _couleurs.encre,
    ),
  );

  /// Variante de [body] pour le texte de second plan.
  TextStyle get bodyMuted => body.copyWith(color: _couleurs.textSecondary);

  TextStyle get caption => _avecEmojis(
    GoogleFonts.inter(
      fontSize: 13,
      fontWeight: regular,
      height: 1.35,
      color: _couleurs.textSecondary,
    ),
  );

  TextStyle get button => _avecEmojis(
    GoogleFonts.inter(
      fontSize: 16,
      fontWeight: semiBold,
      height: 1.2,
      letterSpacing: 0,
    ),
  );

  /// Repose le repli d'emojis sur un style de l'échelle.
  ///
  /// `GoogleFonts.inter` ne prend pas `fontFamilyFallback` : il faut le poser
  /// après coup, sur le style qu'il rend.
  static TextStyle _avecEmojis(TextStyle style) =>
      style.copyWith(fontFamilyFallback: emojiFallback);

  /// [TextTheme] Material 3 câblé sur l'échelle ci-dessus.
  ///
  /// Correspondances retenues :
  /// `headlineLarge` → H1, `headlineMedium` → H2, `titleMedium` → H3,
  /// `bodyMedium` → body, `bodySmall` → caption, `labelLarge` → bouton.
  TextTheme get textTheme => TextTheme(
    headlineLarge: h1,
    headlineMedium: h2,
    headlineSmall: h2,
    titleLarge: h3,
    titleMedium: h3,
    titleSmall: body.copyWith(fontWeight: semiBold),
    bodyLarge: body,
    bodyMedium: body,
    bodySmall: caption,
    labelLarge: button,
    labelMedium: caption.copyWith(fontWeight: medium),
    labelSmall: caption,
  );
}

/// `context.typo.body` — l'accès unique à l'échelle typographique.
extension TypographieDuContexte on BuildContext {
  AppTypography get typo => AppTypography(couleurs);
}
