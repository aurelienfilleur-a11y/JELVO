import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../../../data/app_config.dart';
import '../services/voice_recorder.dart';
import 'chat_actions_sheet.dart';
import 'emoji_picker.dart';

/// Barre de saisie du chat.
///
/// Elle porte la limite de 2000 caractères de `messages_content_check` : mieux
/// vaut empêcher la saisie que rendre un `23514` traduit après coup. Le
/// compteur n'apparaît qu'aux abords de la limite — l'afficher en permanence
/// mettrait un décompte sous les yeux de gens qui écrivent trois mots.
///
/// **Le « + » a remplacé le trombone.** Il n'ouvrait que le choix d'un média ;
/// il ouvre désormais les trois choses qu'on peut ajouter à une conversation —
/// une tâche, un événement, un média —, ce qui met au même endroit ce que la
/// maquette y range.
class MessageComposer extends StatefulWidget {
  const MessageComposer({
    super.key,
    required this.onSend,
    required this.onTypingChanged,
    required this.recorder,
    this.onAction,
    this.onVoice,
    this.enabled = true,
  });

  final ValueChanged<String> onSend;

  /// Appelé quand on commence à écrire, et quand on s'arrête.
  final ValueChanged<bool> onTypingChanged;

  /// Ce que propose le « + ». Absent, le bouton disparaît.
  final ValueChanged<ChatAction>? onAction;

  /// Un message vocal terminé. Absent, le micro disparaît.
  final ValueChanged<VoiceRecording>? onVoice;

  /// L'enregistreur, injecté pour que les tests puissent le remplacer : un
  /// micro n'existe pas dans un test de widget.
  final VoiceRecorder recorder;

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

  bool _emojisOuverts = false;

  /// Enregistrement en cours, et depuis combien de temps.
  bool _enregistre = false;
  Duration _ecoule = Duration.zero;
  Timer? _minuterie;

  @override
  void dispose() {
    _finDeFrappe?.cancel();
    _minuterie?.cancel();
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
    setState(() => _emojisOuverts = false);
    widget.onSend(texte);
  }

  /// Insère l'emoji **là où est le curseur**, et non à la fin : on en pose
  /// souvent un au milieu d'une phrase déjà écrite.
  void _insererEmoji(String emoji) {
    final TextEditingValue valeur = _controleur.value;
    final TextSelection selection = valeur.selection;
    final int debut = selection.isValid ? selection.start : valeur.text.length;
    final int fin = selection.isValid ? selection.end : valeur.text.length;

    final String texte = valeur.text.replaceRange(debut, fin, emoji);
    _controleur.value = TextEditingValue(
      text: texte,
      selection: TextSelection.collapsed(offset: debut + emoji.length),
    );
    _surSaisie(texte);
  }

  Future<void> _ouvrirActions() async {
    final ValueChanged<ChatAction>? rappel = widget.onAction;
    if (rappel == null) return;
    setState(() => _emojisOuverts = false);
    final ChatAction? choix = await ChatActionsSheet.ouvrir(context);
    if (choix != null) rappel(choix);
  }

  // --- Messages vocaux ------------------------------------------------------

  Future<void> _demarrerEnregistrement() async {
    final ScaffoldMessengerState messager = ScaffoldMessenger.of(context);
    final bool parti = await widget.recorder.demarrer();

    if (!parti) {
      // Un refus du micro est **définitif** côté application : l'API ne permet
      // pas de redemander. Renvoyer aux réglages du navigateur vaut mieux
      // qu'un bouton qui ne ferait plus rien.
      messager.showSnackBar(
        const SnackBar(
          content: Text(
            'Le microphone n’est pas accessible. Autorisez-le dans les '
            'réglages de votre navigateur, puis rouvrez la conversation.',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _enregistre = true;
      _ecoule = Duration.zero;
      _emojisOuverts = false;
    });

    _minuterie = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _ecoule += const Duration(seconds: 1));
      // La borne est tenue, pas seulement annoncée : arrêter tout seul vaut
      // mieux qu'un envoi refusé une fois la parole dite.
      if (_ecoule >= AppConfig.chatVoiceMaxDuration) _terminerEnregistrement();
    });
  }

  Future<void> _terminerEnregistrement() async {
    _minuterie?.cancel();
    final VoiceRecording? capture = await widget.recorder.arreter();
    if (!mounted) return;
    setState(() => _enregistre = false);

    // Une seconde de son est un doigt qui a glissé, pas un message.
    if (capture == null || capture.duration.inMilliseconds < 700) return;
    widget.onVoice?.call(capture);
  }

  Future<void> _annulerEnregistrement() async {
    _minuterie?.cancel();
    await widget.recorder.annuler();
    if (!mounted) return;
    setState(() => _enregistre = false);
  }

  @override
  Widget build(BuildContext context) {
    final int restants =
        MessageComposer.maxCaracteres - _controleur.text.characters.length;
    final bool aDuTexte = _controleur.text.trim().isNotEmpty;
    final bool peutEnvoyer = widget.enabled && aDuTexte && restants >= 0;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (restants <= 100 && !_enregistre)
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
                  _enregistre
                      ? _barreEnregistrement()
                      : _barreSaisie(
                          peutEnvoyer: peutEnvoyer,
                          aDuTexte: aDuTexte,
                        ),
                ],
              ),
            ),
            if (_emojisOuverts) EmojiPicker(onSelected: _insererEmoji),
          ],
        ),
      ),
    );
  }

  Widget _barreSaisie({required bool peutEnvoyer, required bool aDuTexte}) {
    // Micro ou avion en papier, jamais les deux : le bouton de droite fait ce
    // que la barre permet à cet instant. Deux boutons côte à côte
    // demanderaient de choisir entre envoyer et enregistrer alors qu'on n'a
    // qu'une seule chose à faire.
    final bool micro = !aDuTexte && widget.onVoice != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        if (widget.onAction != null)
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Ajouter à la conversation',
            color: AppColors.textSecondary,
            onPressed: widget.enabled ? _ouvrirActions : null,
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
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _emojisOuverts
                      ? Icons.keyboard_alt_outlined
                      : Icons.emoji_emotions_outlined,
                ),
                tooltip: _emojisOuverts ? 'Fermer les emojis' : 'Emojis',
                color: AppColors.textSecondary,
                onPressed: widget.enabled
                    ? () {
                        // Refermer le clavier système : les deux panneaux
                        // occupent le même bas d'écran, et se disputeraient la
                        // place l'un de l'autre.
                        if (!_emojisOuverts) _focus.unfocus();
                        setState(() => _emojisOuverts = !_emojisOuverts);
                      }
                    : null,
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
          icon: Icon(micro ? Icons.mic_rounded : Icons.send_rounded, size: 20),
          tooltip: micro ? 'Enregistrer un message vocal' : 'Envoyer',
          onPressed: micro
              ? (widget.enabled ? _demarrerEnregistrement : null)
              : (peutEnvoyer ? _envoyer : null),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.border,
          ),
        ),
      ],
    );
  }

  /// Ce que la barre devient pendant l'enregistrement : annuler à gauche, le
  /// temps qui court au milieu, envoyer à droite.
  Widget _barreEnregistrement() {
    return Row(
      children: <Widget>[
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded),
          tooltip: 'Annuler l’enregistrement',
          color: AppColors.danger,
          onPressed: _annulerEnregistrement,
        ),
        Expanded(
          child: Row(
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
              ),
              AppSpacing.hGapSm,
              Text(
                _minutage(_ecoule),
                style: AppTypography.body.copyWith(
                  fontWeight: AppTypography.semiBold,
                ),
              ),
              AppSpacing.hGapSm,
              Expanded(
                child: Text(
                  'Enregistrement…',
                  style: AppTypography.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        IconButton.filled(
          icon: const Icon(Icons.send_rounded, size: 20),
          tooltip: 'Envoyer le message vocal',
          onPressed: _terminerEnregistrement,
          style: IconButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  static String _minutage(Duration duree) {
    final int secondes = duree.inSeconds;
    return '${secondes ~/ 60}:${(secondes % 60).toString().padLeft(2, '0')}';
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
