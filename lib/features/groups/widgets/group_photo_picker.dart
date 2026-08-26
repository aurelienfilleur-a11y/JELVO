import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/core.dart';

/// Sélecteur de photo de groupe : bandeau large, à l'image de l'en-tête de
/// l'écran de groupe.
///
/// Volontairement distinct d'`AvatarPicker` : une photo de groupe se regarde en
/// paysage, une photo de profil en rond.
class GroupPhotoPicker extends StatefulWidget {
  const GroupPhotoPicker({
    super.key,
    required this.bytes,
    required this.onPicked,
    required this.onRemoved,
    this.imageUrl,
    this.accentColor = AppColors.primary,
  });

  /// Photo choisie mais pas encore envoyée.
  final Uint8List? bytes;

  /// Photo déjà enregistrée, affichée à défaut de [bytes].
  final String? imageUrl;

  final void Function(Uint8List bytes, String extension) onPicked;
  final VoidCallback onRemoved;
  final Color accentColor;

  @override
  State<GroupPhotoPicker> createState() => _GroupPhotoPickerState();
}

class _GroupPhotoPickerState extends State<GroupPhotoPicker> {
  bool _picking = false;
  String? _error;

  bool get _hasImage => widget.bytes != null || widget.imageUrl != null;

  /// Diamètre du cercle. Assez large pour qu'une photo s'y reconnaisse, assez
  /// petit pour que le nom du groupe reste au-dessus de la ligne de flottaison.
  static const double _taille = 104;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Semantics(
          button: true,
          label: 'Choisir une photo de groupe',
          child: GestureDetector(
            onTap: _picking ? null : _pick,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Container(
                  height: _taille,
                  width: _taille,
                  decoration: BoxDecoration(
                    color: widget.accentColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.center,
                  child: _preview(),
                ),
                // La pastille « + » dit que le cercle se touche. Sans elle,
                // une zone violette vide passe pour une décoration.
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        AppSpacing.gapSm,
        TextButton(
          onPressed: _picking ? null : _pick,
          child: Text(
            _picking
                ? 'Ouverture de la galerie…'
                : (_hasImage ? 'Changer la photo' : 'Ajouter une photo'),
          ),
        ),
        if (_hasImage)
          TextButton(
            onPressed: widget.onRemoved,
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Retirer'),
          ),
        if (_error != null) ...<Widget>[
          AppSpacing.gapXs,
          Text(
            _error!,
            style: AppTypography.caption.copyWith(color: AppColors.danger),
          ),
        ],
      ],
    );
  }

  Widget _preview() {
    if (widget.bytes != null) {
      return Image.memory(
        widget.bytes!,
        width: _taille,
        height: _taille,
        fit: BoxFit.cover,
      );
    }
    if (widget.imageUrl != null) {
      return Image.network(
        widget.imageUrl!,
        width: _taille,
        height: _taille,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder,
      );
    }
    return _placeholder;
  }

  Widget get _placeholder =>
      Icon(Icons.photo_camera_outlined, size: 34, color: widget.accentColor);

  Future<void> _pick() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final XFile? file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (file == null) return;

      final Uint8List bytes = await file.readAsBytes();
      if (!mounted) return;
      widget.onPicked(bytes, _extensionOf(file.name));
    } catch (_) {
      if (mounted) {
        setState(() => _error = "La photo n'a pas pu être ouverte. Réessayez.");
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  static String _extensionOf(String fileName) {
    final int dot = fileName.lastIndexOf('.');
    if (dot == -1 || dot == fileName.length - 1) return 'jpg';
    return fileName.substring(dot + 1).toLowerCase();
  }
}
