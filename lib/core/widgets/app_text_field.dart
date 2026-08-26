import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Champ de saisie Jelvo : libellé au-dessus, champ blanc à rayon 12.
///
/// Le libellé est rendu comme un `Text` séparé plutôt qu'en `labelText`, pour
/// qu'il garde la taille `caption` et ne se transforme pas en libellé flottant.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.showCounter = false,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.focusNode,
    this.inputFormatters,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
  });

  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final String? helperText;
  final String? errorText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool enabled;

  /// Champ non éditable mais toujours cliquable — utile pour ouvrir un
  /// sélecteur de date ou d'heure via [onTap].
  final bool readOnly;

  final bool autofocus;
  final int maxLines;
  final int? minLines;
  final int? maxLength;

  /// Affiche « 42/120 » sous le champ.
  ///
  /// Éteint par défaut : un compteur n'a d'intérêt que là où la limite est
  /// basse et se rencontre pour de bon — une description de groupe, celle d'un
  /// événement. Sur un mot de passe, il ne ferait qu'ajouter du bruit.
  final bool showCounter;

  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final FocusNode? focusNode;

  /// Filtres de saisie, p. ex. pour restreindre un pseudo aux minuscules.
  final List<TextInputFormatter>? inputFormatters;

  /// Indices de remplissage automatique (gestionnaires de mots de passe).
  final Iterable<String>? autofillHints;

  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final bool hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (label != null) ...<Widget>[
          Text(
            label!,
            style: AppTypography.caption.copyWith(
              fontWeight: AppTypography.medium,
              color: AppColors.midnight,
            ),
          ),
          AppSpacing.gapSm,
        ],
        TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          readOnly: readOnly,
          autofocus: autofocus,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          maxLines: obscureText ? 1 : maxLines,
          minLines: minLines,
          maxLength: maxLength,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          onTap: onTap,
          inputFormatters: inputFormatters,
          autofillHints: autofillHints,
          textCapitalization: textCapitalization,
          cursorColor: AppColors.primary,
          style: AppTypography.body.copyWith(
            color: enabled ? AppColors.midnight : AppColors.textSecondary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            fillColor: enabled ? AppColors.surface : AppColors.background,
            prefixIcon: prefixIcon == null
                ? null
                : Icon(prefixIcon, size: 20, color: AppColors.textSecondary),
            suffixIcon: suffixIcon,
            // Le message d'erreur est rendu sous le champ (voir plus bas) pour
            // rester sur la grille d'espacement ; ici on ne reprend que le
            // contour rouge, en écrasant les bordures issues du thème.
            enabledBorder: hasError ? _errorBorder() : null,
            focusedBorder: hasError ? _errorBorder(width: 1.5) : null,
          ),
        ),
        if (hasError) ...<Widget>[
          AppSpacing.gapXs,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(
                Icons.error_outline_rounded,
                size: 14,
                color: AppColors.danger,
              ),
              AppSpacing.hGapXs,
              Expanded(
                child: Text(
                  errorText!,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
        ] else if (helperText != null) ...<Widget>[
          AppSpacing.gapXs,
          Text(helperText!, style: AppTypography.caption),
        ],
        if (showCounter && maxLength != null && controller != null) ...<Widget>[
          AppSpacing.gapXs,
          _Counter(controller: controller!, maxLength: maxLength!),
        ],
      ],
    );
  }

  static OutlineInputBorder _errorBorder({double width = 1}) {
    return OutlineInputBorder(
      borderRadius: AppRadii.fieldRadius,
      borderSide: BorderSide(color: AppColors.danger, width: width),
    );
  }
}

/// « 42/120 », aligné à droite sous le champ.
///
/// Il écoute le contrôleur plutôt que d'imposer un `StatefulWidget` au champ
/// entier : seul ce texte se reconstruit à chaque frappe.
class _Counter extends StatelessWidget {
  const _Counter({required this.controller, required this.maxLength});

  final TextEditingController controller;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (BuildContext context, TextEditingValue value, _) {
        final int longueur = value.text.characters.length;
        return Align(
          alignment: Alignment.centerRight,
          child: Text(
            '$longueur/$maxLength',
            style: AppTypography.caption.copyWith(
              // La limite atteinte se signale : la frappe suivante ne
              // s'inscrira pas, et rien d'autre ne le dirait.
              color: longueur >= maxLength
                  ? AppColors.warning
                  : AppColors.textSecondary,
            ),
          ),
        );
      },
    );
  }
}
