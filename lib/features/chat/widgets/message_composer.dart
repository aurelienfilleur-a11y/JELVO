import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/core.dart';

/// Barre de saisie du chat.
///
/// Elle porte la limite de 2000 caractères de `messages_content_check` : mieux
/// vaut empêcher la saisie que rendre un `23514` traduit après coup. Le
/// compteur n'apparaît qu'aux abords de la limite — l'afficher en permanence
/// mettrait un décompte sous les yeux de gens qui écrivent trois mots.
class MessageComposer extends StatefulWidget {
  const MessageComposer({
    super.key,
    required this.onSend,
    required this.onTypingChanged,
    this.onAttach,
    this.enabled = true,
  });

  final ValueChanged<String> onSend;

  /// Appelé quand on commence à écrire, et quand on s'arrête.
  final ValueChanged<bool> onTypingChanged;

  /// Ajout d'un média. Absent tant que la tranche 5b n'est pas livrée.
  final VoidCallback? onAttach;

  final bool enabled;

  static const int maxCaracteres = 2000;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final TextEditingController _controleur = TextEditingController();
  final FocusNode _focus = FocusNode();

  Timer? _finDeFrappe;
  bool _annonceEnCours = false;

  @override
  void dispose() {
    _finDeFrappe?.cancel();
    _controleur.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Annonce « j'écris » une seule fois, puis « j'ai fini » après deux
  /// secondes de silence. Émettre à chaque touche inonderait le canal.
  void _surSaisie(String valeur) {
    setState(() {});

    if (!_annonceEnCours && valeur.isNotEmpty) {
      _annonceEnCours = true;
      widget.onTypingChanged(true);
    }

    _finDeFrappe?.cancel();
    _finDeFrappe = Timer(const Duration(seconds: 2), _arreterFrappe);
  }

  void _arreterFrappe() {
    _finDeFrappe?.cancel();
    if (!_annonceEnCours) return;
    _annonceEnCours = false;
    widget.onTypingChanged(false);
  }

  void _envoyer() {
    final String texte = _controleur.text.trim();
    if (texte.isEmpty) return;
    _controleur.clear();
    _arreterFrappe();
    setState(() {});
    widget.onSend(texte);
  }

  @override
  Widget build(BuildContext context) {
    final int restants =
        MessageComposer.maxCaracteres - _controleur.text.characters.length;
    final bool peutEnvoyer =
        widget.enabled && _controleur.text.trim().isNotEmpty && restants >= 0;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (restants <= 100)
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$restants',
                    style: AppTypography.caption.copyWith(
                      color: restants < 0
                          ? AppColors.danger
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  if (widget.onAttach != null)
                    IconButton(
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      tooltip: 'Joindre une photo ou une vidéo',
                      color: AppColors.textSecondary,
                      onPressed: widget.enabled ? widget.onAttach : null,
                    ),
                  Expanded(
                    child: TextField(
                      controller: _controleur,
                      focusNode: _focus,
                      enabled: widget.enabled,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: MessageComposer.maxCaracteres,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.newline,
                      onChanged: _surSaisie,
                      style: AppTypography.body,
                      decoration: InputDecoration(
                        hintText: 'Votre message',
                        hintStyle: AppTypography.bodyMuted,
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  AppSpacing.hGapSm,
                  IconButton.filled(
                    icon: const Icon(Icons.send_rounded, size: 20),
                    tooltip: 'Envoyer',
                    onPressed: peutEnvoyer ? _envoyer : null,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.border,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// « Léa est en train d'écrire… »
///
/// La hauteur est réservée en permanence : sans cela, l'apparition du texte
/// pousserait toute la conversation d'un cran à chaque frappe.
class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key, required this.names});

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      child: names.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenMargin,
              ),
              child: Text(
                _libelle(),
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
    );
  }

  String _libelle() => switch (names.length) {
    1 => '${names.first} est en train d’écrire…',
    2 => '${names[0]} et ${names[1]} sont en train d’écrire…',
    _ => 'Plusieurs personnes sont en train d’écrire…',
  };
}
