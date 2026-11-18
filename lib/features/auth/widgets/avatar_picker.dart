import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/core.dart';

/// Sélecteur de photo de profil : aperçu rond, choix depuis la galerie,
/// suppression possible.
class AvatarPicker extends StatefulWidget {
  const AvatarPicker({
    super.key,
    required this.bytes,
    required this.onPicked,
    required this.onRemoved,
    this.initials = '',
    this.imageUrl,
  });

  /// Photo choisie mais pas encore envoyée.
  final Uint8List? bytes;

  /// Photo déjà enregistrée, affichée à défaut de [bytes].
  final String? imageUrl;

  final void Function(Uint8List bytes, String extension) onPicked;
  final VoidCallback onRemoved;
  final String initials;

  /// Ouvre la galerie de photos et renvoie l'image choisie, ou `null`.
  ///
  /// Exposée pour que l'écran de profil ouvre exactement la **même** sélection
  /// que l'inscription — mêmes bornes de taille, même compression. Deux appels
  /// à `ImagePicker` auraient fini par diverger, et c'est le poids envoyé au
  /// bucket qui en aurait pâti.
  static Future<({Uint8List bytes, String extension})?> choisirPhoto() async {
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      // Une photo de profil n'a pas besoin d'être en pleine résolution ; cela
      // réduit aussi le temps de téléversement.
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (file == null) return null;
    return (
      bytes: await file.readAsBytes(),
      extension: _extensionOf(file.name),
    );
  }

  static String _extensionOf(String fileName) {
    final int dot = fileName.lastIndexOf('.');
    if (dot == -1 || dot == fileName.length - 1) return 'jpg';
    return fileName.substring(dot + 1).toLowerCase();
  }

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  bool _picking = false;
  String? _error;

  bool get _hasImage => widget.bytes != null || widget.imageUrl != null;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Semantics(
          button: true,
          label: 'Choisir une photo de profil',
          child: GestureDetector(
            onTap: _picking ? null : _pick,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: <Widget>[
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    color: context.couleurs.primarySoft,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.couleurs.border,
                      width: 2,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.center,
                  child: _preview(),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: context.couleurs.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.couleurs.surface,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    _hasImage ? Icons.edit_rounded : Icons.photo_camera_rounded,
                    size: 16,
                    color: context.couleurs.onAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
        AppSpacing.gapMd,
        if (_picking)
          Text('Ouverture de la galerie…', style: context.typo.caption)
        else if (_hasImage)
          TextButton(
            onPressed: widget.onRemoved,
            style: TextButton.styleFrom(
              foregroundColor: context.couleurs.danger,
            ),
            child: Text(
              AvatarData.assetPourAvatar(widget.imageUrl) != null
                  ? 'Retirer l’avatar'
                  : 'Retirer la photo',
            ),
          )
        else
          Text('Ajouter une photo (facultatif)', style: context.typo.caption),
        if (_error != null) ...<Widget>[
          AppSpacing.gapXs,
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: context.typo.caption.copyWith(
              color: context.couleurs.danger,
            ),
          ),
        ],
      ],
    );
  }

  Widget _preview() {
    if (widget.bytes != null) {
      return Image.memory(
        widget.bytes!,
        width: 104,
        height: 104,
        fit: BoxFit.cover,
      );
    }
    // La valeur reçue peut désigner un avatar prédéfini embarqué plutôt
    // qu'une photo — voir `AvatarData.assetPourAvatar`.
    final String? asset = AvatarData.assetPourAvatar(widget.imageUrl);
    if (asset != null) {
      return Image.asset(
        asset,
        width: 104,
        height: 104,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _initialsLabel,
      );
    }
    if (widget.imageUrl != null) {
      return Image.network(
        widget.imageUrl!,
        width: 104,
        height: 104,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _initialsLabel,
      );
    }
    return _initialsLabel;
  }

  Widget get _initialsLabel => Text(
    widget.initials.isEmpty ? '?' : widget.initials,
    style: context.typo.h2.copyWith(color: context.couleurs.primary),
  );

  Future<void> _pick() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final ({Uint8List bytes, String extension})? choix =
          await AvatarPicker.choisirPhoto();
      if (choix == null || !mounted) return;
      widget.onPicked(choix.bytes, choix.extension);
    } catch (_) {
      if (mounted) {
        setState(() => _error = "La photo n'a pas pu être ouverte. Réessayez.");
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }
}
