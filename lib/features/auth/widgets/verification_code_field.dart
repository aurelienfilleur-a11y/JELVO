import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/core.dart';

/// Saisie du code à six chiffres.
///
/// Un unique `TextField` transparent reçoit la frappe et six cases le
/// reflètent : six champs séparés compliquent le collage du code et la gestion
/// du retour arrière, sans rien apporter.
class VerificationCodeField extends StatefulWidget {
  const VerificationCodeField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onCompleted,
    this.hasError = false,
    this.enabled = true,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onCompleted;
  final bool hasError;
  final bool enabled;

  static const int length = 6;

  @override
  State<VerificationCodeField> createState() => _VerificationCodeFieldState();
}

class _VerificationCodeFieldState extends State<VerificationCodeField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _onFocusChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final String value = widget.controller.text;

    return Semantics(
      label: 'Code de vérification à six chiffres',
      textField: true,
      child: Stack(
        children: <Widget>[
          Row(
            children: <Widget>[
              for (
                int i = 0;
                i < VerificationCodeField.length;
                i++
              ) ...<Widget>[
                Expanded(
                  child: _CodeBox(
                    character: i < value.length ? value[i] : null,
                    focused: _focusNode.hasFocus && i == value.length,
                    hasError: widget.hasError,
                  ),
                ),
                if (i < VerificationCodeField.length - 1) AppSpacing.hGapSm,
              ],
            ],
          ),
          // Champ réel, invisible mais bien présent : il porte le curseur
          // système, le clavier et le collage.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: VerificationCodeField.length,
                showCursor: false,
                enableInteractiveSelection: false,
                style: context.typo.h2,
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                ),
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onChanged: (String text) {
                  setState(() {});
                  widget.onChanged(text);
                  if (text.length == VerificationCodeField.length) {
                    widget.onCompleted?.call(text);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({
    required this.character,
    required this.focused,
    required this.hasError,
  });

  final String? character;
  final bool focused;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = hasError
        ? context.couleurs.danger
        : (focused ? context.couleurs.primary : context.couleurs.border);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.couleurs.surface,
        borderRadius: AppRadii.fieldRadius,
        border: Border.all(color: borderColor, width: focused ? 1.5 : 1),
      ),
      child: Text(
        character ?? '',
        style: context.typo.h2.copyWith(
          color: hasError ? context.couleurs.danger : context.couleurs.encre,
        ),
      ),
    );
  }
}
