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
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  static TextStyle get h1 => GoogleFonts.inter(
    fontSize: 28,
    fontWeight: bold,
    height: 1.2,
    letterSpacing: -0.4,
    color: AppColors.midnight,
  );

  static TextStyle get h2 => GoogleFonts.inter(
    fontSize: 22,
    fontWeight: bold,
    height: 1.25,
    letterSpacing: -0.3,
    color: AppColors.midnight,
  );

  static TextStyle get h3 => GoogleFonts.inter(
    fontSize: 17,
    fontWeight: semiBold,
    height: 1.3,
    letterSpacing: -0.1,
    color: AppColors.midnight,
  );

  static TextStyle get body => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: regular,
    height: 1.45,
    color: AppColors.midnight,
  );

  /// Variante de [body] pour le texte de second plan.
  static TextStyle get bodyMuted =>
      body.copyWith(color: AppColors.textSecondary);

  static TextStyle get caption => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: regular,
    height: 1.35,
    color: AppColors.textSecondary,
  );

  static TextStyle get button => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: semiBold,
    height: 1.2,
    letterSpacing: 0,
  );

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
