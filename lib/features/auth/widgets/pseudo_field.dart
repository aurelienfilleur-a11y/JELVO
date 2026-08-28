import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../models/credentials_rules.dart';
import '../providers/auth_providers.dart';
import '../repository/auth_repository.dart';

/// Champ pseudo avec vérification de disponibilité en direct.
///
/// La saisie est forcée en minuscules et restreinte aux caractères autorisés :
/// mieux vaut empêcher la frappe invalide que la signaler après coup.
class PseudoField extends ConsumerWidget {
  const PseudoField({
    super.key,
    required this.controller,
    required this.pseudo,
    required this.onChanged,
    this.showAvailability = true,
  });

  final TextEditingController controller;

  /// Valeur courante, remontée par l'écran parent pour piloter la requête.
  final String pseudo;

  final ValueChanged<String> onChanged;
  final bool showAvailability;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? formatError = pseudo.isEmpty
        ? null
        : CredentialsRules.pseudoError(pseudo);

    final bool canCheck =
        showAvailability && CredentialsRules.isPseudoValid(pseudo);
    final AsyncValue<PseudoAvailability>? availability = canCheck
        ? ref.watch(pseudoAvailabilityProvider(pseudo))
        : null;

    final bool isTaken = availability?.value == PseudoAvailability.taken;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppTextField(
          label: 'Pseudo',
          hint: 'camille.rousseau',
          controller: controller,
          onChanged: onChanged,
          prefixIcon: Icons.alternate_email_rounded,
          textInputAction: TextInputAction.next,
          maxLength: CredentialsRules.pseudoMaxLength,
          errorText:
              formatError ?? (isTaken ? 'Ce pseudo est déjà pris.' : null),
          helperText: formatError == null && !isTaken
              ? 'Minuscules, chiffres et points, de '
                    '${CredentialsRules.pseudoMinLength} à '
                    '${CredentialsRules.pseudoMaxLength} caractères.'
              : null,
          suffixIcon: availability == null
              ? null
              : _AvailabilityIndicator(state: availability),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9.]')),
            _LowerCaseFormatter(),
          ],
        ),
        if (availability?.value == PseudoAvailability.available) ...<Widget>[
          AppSpacing.gapXs,
          Row(
            children: <Widget>[
              Icon(
                Icons.check_circle_rounded,
                size: 14,
                color: context.couleurs.success,
              ),
              AppSpacing.hGapXs,
              Text(
                'Ce pseudo est disponible.',
                style: context.typo.caption.copyWith(
                  color: context.couleurs.success,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _AvailabilityIndicator extends StatelessWidget {
  const _AvailabilityIndicator({required this.state});

  final AsyncValue<PseudoAvailability> state;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return switch (state.value) {
      PseudoAvailability.available => Icon(
        Icons.check_circle_rounded,
        size: 20,
        color: context.couleurs.success,
      ),
      PseudoAvailability.taken => Icon(
        Icons.cancel_rounded,
        size: 20,
        color: context.couleurs.danger,
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

/// Force la saisie en minuscules sans déplacer le curseur.
class _LowerCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toLowerCase());
  }
}
