import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../models/credentials_rules.dart';

/// Champ mot de passe avec bascule d'affichage.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Mot de passe',
    this.hint = 'Votre mot de passe',
    this.errorText,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String? errorText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: widget.label,
      hint: widget.hint,
      controller: widget.controller,
      obscureText: _obscured,
      errorText: widget.errorText,
      prefixIcon: Icons.lock_outline_rounded,
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      suffixIcon: IconButton(
        onPressed: () => setState(() => _obscured = !_obscured),
        tooltip: _obscured
            ? 'Afficher le mot de passe'
            : 'Masquer le mot de passe',
        icon: Icon(
          _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 20,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// Liste des contraintes du mot de passe, cochées au fil de la saisie.
///
/// Affichée en permanence plutôt qu'en message d'erreur : l'utilisateur voit
/// ce qui est attendu avant de se tromper.
class PasswordRulesChecklist extends StatelessWidget {
  const PasswordRulesChecklist({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Rule(
          satisfied: CredentialsRules.hasMinLength(password),
          label: 'Au moins ${CredentialsRules.passwordMinLength} caractères',
        ),
        AppSpacing.gapXs,
        _Rule(
          satisfied: CredentialsRules.hasUppercase(password),
          label: 'Une majuscule',
        ),
        AppSpacing.gapXs,
        _Rule(
          satisfied: CredentialsRules.hasDigit(password),
          label: 'Un chiffre',
        ),
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.satisfied, required this.label});

  final bool satisfied;
  final String label;

  @override
  Widget build(BuildContext context) {
    final Color color = satisfied ? AppColors.success : AppColors.textSecondary;

    return Row(
      children: <Widget>[
        Icon(
          satisfied
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          size: 16,
          color: color,
        ),
        AppSpacing.hGapSm,
        Expanded(
          child: Text(
            label,
            style: AppTypography.caption.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
