import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_radii.dart';
import 'app_spacing.dart';
import 'app_typography.dart';
import 'jelvo_colors.dart';

/// Thèmes Material 3 de Jelvo : clair et sombre.
///
/// Les deux sont bâtis par la **même** fonction, à partir de la palette
/// correspondante : une seconde construction aurait fini par diverger, et la
/// divergence se serait vue sur l'écran qu'on regarde le moins.
///
/// `JelvoColors` est posée en `ThemeExtension` : c'est elle que lit
/// `context.couleurs`, et c'est sa présence dans le thème qui fait que
/// changer d'apparence reconstruit les écrans.
abstract final class AppTheme {
  static ThemeData get light =>
      _construire(JelvoColors.clair, Brightness.light);

  static ThemeData get dark => _construire(JelvoColors.sombre, Brightness.dark);

  static ColorScheme colorScheme(JelvoColors c, Brightness brightness) =>
      ColorScheme(
        brightness: brightness,
        primary: c.primary,
        onPrimary: c.onAccent,
        primaryContainer: c.primarySoft,
        onPrimaryContainer: c.primaryInk,
        secondary: c.primaryDark,
        onSecondary: c.onAccent,
        surface: c.surface,
        onSurface: c.encre,
        onSurfaceVariant: c.textSecondary,
        surfaceContainerLowest: c.surface,
        surfaceContainerLow: c.background,
        surfaceContainer: c.background,
        error: c.danger,
        onError: c.onAccent,
        errorContainer: c.dangerSoft,
        onErrorContainer: c.dangerInk,
        outline: c.border,
        outlineVariant: c.border,
      );

  static ThemeData _construire(JelvoColors c, Brightness brightness) {
    final bool sombre = brightness == Brightness.dark;
    final ColorScheme scheme = colorScheme(c, brightness);
    final AppTypography typo = AppTypography(c);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: <ThemeExtension<dynamic>>[c],
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      textTheme: typo.textTheme,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.encre,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: typo.h3,
        // La barre système suit le thème : des icônes sombres sur un fond
        // sombre disparaîtraient, et c'est le seul endroit où l'application
        // parle au système d'exploitation.
        systemOverlayStyle: sombre
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),

      // Les cartes de l'app utilisent `GroupCard`/`EventCard`, mais on aligne
      // quand même le `CardTheme` pour tout `Card` utilisé ponctuellement.
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
      ),

      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),

      iconTheme: IconThemeData(color: c.encre, size: 22),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        iconColor: c.textSecondary,
        textColor: c.encre,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: c.border,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetRadius),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
        titleTextStyle: typo.h3,
        contentTextStyle: typo.bodyMuted,
      ),

      snackBarTheme: SnackBarThemeData(
        // En sombre, la barre reprend la carte plutôt que l'encre : un pavé
        // presque blanc surgissant sur un écran sombre éblouit.
        backgroundColor: sombre ? c.bubbleOther : c.encre,
        contentTextStyle: typo.body.copyWith(
          color: sombre ? c.encre : c.surface,
        ),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadii.buttonRadius,
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: c.background,
        selectedColor: c.primarySoft,
        side: BorderSide(color: c.border),
        labelStyle: typo.caption,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.pillRadius),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        hintStyle: typo.body.copyWith(color: c.textSecondary),
        labelStyle: typo.caption,
        errorStyle: typo.caption.copyWith(color: c.dangerInk),
        border: _fieldBorder(c.border),
        enabledBorder: _fieldBorder(c.border),
        focusedBorder: _fieldBorder(c.primary, width: 1.5),
        errorBorder: _fieldBorder(c.danger),
        focusedErrorBorder: _fieldBorder(c.danger, width: 1.5),
        disabledBorder: _fieldBorder(c.border),
      ),

      // Les boutons applicatifs passent par `PrimaryButton` / `SecondaryButton`.
      // Ces thèmes servent de garde-fou pour les boutons Material bruts.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onAccent,
          disabledBackgroundColor: c.border,
          disabledForegroundColor: c.textSecondary,
          minimumSize: const Size.fromHeight(52),
          textStyle: typo.button,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadii.buttonRadius,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.primaryInk,
          side: BorderSide(color: c.border),
          minimumSize: const Size.fromHeight(52),
          textStyle: typo.button,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadii.buttonRadius,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primaryInk,
          textStyle: typo.button,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadii.buttonRadius,
          ),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.border,
        circularTrackColor: c.border,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) =>
              states.contains(WidgetState.selected) ? c.onAccent : c.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) =>
              states.contains(WidgetState.selected) ? c.primary : c.border,
        ),
      ),
    );
  }

  static OutlineInputBorder _fieldBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: AppRadii.fieldRadius,
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
