import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../models/credentials_rules.dart';

/// Champ mot de passe avec bascule d'affichage.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;

  /// `null` → « Mot de passe ». La valeur par défaut ne peut pas vivre
  /// dans la liste de paramètres : le contexte n'y existe pas, et c'est
  /// lui qui porte la langue. Même arbitrage que pour les couleurs.
  final String? label;
  final String? hint;
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
    final AppTexts t = AppTexts.of(context);
    return AppTextField(
      label: widget.label ?? t.authMotPasse,
      hint: widget.hint ?? t.authMotPasse2,
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
            ? AppTexts.of(context).authAfficherMotPasse
            : AppTexts.of(context).authMasquerMotPasse,
        icon: Icon(
          _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 20,
          color: context.couleurs.textSecondary,
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
    final AppTexts t = AppTexts.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Rule(
          satisfied: CredentialsRules.hasMinLength(password),
          label: t.authMoinsCaracteres(CredentialsRules.passwordMinLength),
        ),
        AppSpacing.gapXs,
        _Rule(
          satisfied: CredentialsRules.hasUppercase(password),
          label: t.authMajuscule,
        ),
        AppSpacing.gapXs,
        _Rule(
          satisfied: CredentialsRules.hasDigit(password),
          label: t.authChiffre,
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
    final Color color = satisfied
        ? context.couleurs.success
        : context.couleurs.textSecondary;

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
            style: context.typo.caption.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
