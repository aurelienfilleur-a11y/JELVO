import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Échelle typographique Jelvo, basée sur la police Inter.
///
/// H1 28 bold · H2 22 bold · H3 17 semibold · body 15 · caption 13 ·
/// bouton 16 semibold.
///
/// Ces styles sont branchés sur le [TextTheme] Material 3 dans
/// `AppTheme.light`, ce qui permet d'écrire `context.textStyles.h1` ou
/// `Theme.of(context).textTheme.headlineLarge` de façon interchangeable.
abstract final class AppTypography {
  /// Police de repli des emojis, appliquée à **tous** les styles.
  ///
  /// Le web ne garantit aucune police d'emojis : selon la machine, un cœur
  /// tapé au clavier s'affichait en rouge, en noir et blanc, ou pas du tout.
  /// Inter n'ayant aucun glyphe d'emoji, le moteur descend ici pour eux — et
  /// pour eux seuls : le texte latin ne change pas d'un pixel.
  ///
  /// **Le repli est global et non posé site par site.** L'énumérer — bulles,
  /// réactions, noms de groupes, titres de tâches, bio… — laisserait le
  /// prochain écran l'oublier, et l'oubli se voit à l'écran sans faire échouer
  /// la CI. Ici, un style de l'échelle Jelvo le porte par construction.
  static const List<String> emojiFallback = <String>['NotoColorEmoji'];

  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  static TextStyle get h1 => _avecEmojis(
    GoogleFonts.inter(
      fontSize: 28,
      fontWeight: bold,
      height: 1.2,
      letterSpacing: -0.4,
      color: AppColors.midnight,
    ),
  );

  static TextStyle get h2 => _avecEmojis(
    GoogleFonts.inter(
      fontSize: 22,
      fontWeight: bold,
      height: 1.25,
      letterSpacing: -0.3,
      color: AppColors.midnight,
    ),
  );

  static TextStyle get h3 => _avecEmojis(
    GoogleFonts.inter(
      fontSize: 17,
      fontWeight: semiBold,
      height: 1.3,
      letterSpacing: -0.1,
      color: AppColors.midnight,
    ),
  );

  static TextStyle get body => _avecEmojis(
    GoogleFonts.inter(
      fontSize: 15,
      fontWeight: regular,
      height: 1.45,
      color: AppColors.midnight,
    ),
  );

  /// Variante de [body] pour le texte de second plan.
  static TextStyle get bodyMuted =>
      body.copyWith(color: AppColors.textSecondary);

  static TextStyle get caption => _avecEmojis(
    GoogleFonts.inter(
      fontSize: 13,
      fontWeight: regular,
      height: 1.35,
      color: AppColors.textSecondary,
    ),
  );

  static TextStyle get button => _avecEmojis(
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
  static TextTheme get textTheme => TextTheme(
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
