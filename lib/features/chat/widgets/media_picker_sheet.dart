import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/core.dart';
import '../../../data/app_config.dart';
import '../models/media_selection.dart';
import '../models/message.dart';

/// Choix d'une photo ou d'une vidéo, appareil photo ou galerie.
///
/// Les photos sont **compressées à la source** par `image_picker`
/// (`imageQuality`, `maxWidth`), comme les avatars et les photos de groupe :
/// une photo d'iPhone brute pèse plusieurs mégaoctets pour un affichage qui
/// n'en demande pas le dixième.
///
/// Les vidéos, elles, ne sont **pas ré-encodées** — aucun paquet de
/// compression vidéo n'est dans les dépendances. La seule borne disponible est
/// donc le poids, contrôlé ici, à la sélection : échouer après trente secondes
/// de téléversement serait bien pire que refuser tout de suite.
Future<MediaSelection?> choisirMedia(BuildContext context) {
  return showModalBottomSheet<MediaSelection>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext sheetContext) => const _MediaPickerSheet(),
  );
}

class _MediaPickerSheet extends StatefulWidget {
  const _MediaPickerSheet();

  @override
  State<_MediaPickerSheet> createState() => _MediaPickerSheetState();
}

class _MediaPickerSheetState extends State<_MediaPickerSheet> {
  final ImagePicker _selecteur = ImagePicker();

  bool _chargement = false;
  String? _erreur;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text('Joindre', style: AppTypography.h2),
          ),
          AppSpacing.gapMd,

          if (_erreur != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.dangerSoft,
                  borderRadius: AppRadii.fieldRadius,
                ),
                child: Text(
                  _erreur!,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.danger,
                  ),
                ),
              ),
            ),

          if (_chargement)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...<Widget>[
            _Choix(
              icone: Icons.photo_library_outlined,
              titre: 'Photo de la galerie',
              onTap: () => _prendre(MediaKind.image, ImageSource.gallery),
            ),
            _Choix(
              icone: Icons.photo_camera_outlined,
              titre: 'Prendre une photo',
              onTap: () => _prendre(MediaKind.image, ImageSource.camera),
            ),
            _Choix(
              icone: Icons.video_library_outlined,
              titre: 'Vidéo de la galerie',
              sousTitre:
                  'Jusqu’à ${MediaSelection.maxVideoLabel}, environ une minute',
              onTap: () => _prendre(MediaKind.video, ImageSource.gallery),
            ),
            _Choix(
              icone: Icons.videocam_outlined,
              titre: 'Filmer',
              onTap: () => _prendre(MediaKind.video, ImageSource.camera),
            ),
          ],
          AppSpacing.gapMd,
        ],
      ),
    );
  }

  Future<void> _prendre(MediaKind kind, ImageSource source) async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });

    try {
      final XFile? fichier = kind == MediaKind.image
          ? await _selecteur.pickImage(
              source: source,
              maxWidth: 1600,
              imageQuality: 80,
            )
          : await _selecteur.pickVideo(
              source: source,
              maxDuration: AppConfig.chatMediaMaxVideoDuration,
            );

      if (fichier == null) {
        if (mounted) setState(() => _chargement = false);
        return;
      }

      final MediaSelection choix = MediaSelection(
        bytes: await fichier.readAsBytes(),
        extension: MediaSelection.extensionOf(fichier.name, kind),
        kind: kind,
      );

      if (!mounted) return;

      if (choix.isTooHeavy) {
        setState(() {
          _chargement = false;
          _erreur =
              'Cette vidéo pèse ${choix.sizeLabel}, au-delà des '
              '${MediaSelection.maxVideoLabel} acceptés. Filmez plus court, '
              'ou envoyez-la autrement.';
        });
        return;
      }

      Navigator.of(context).pop(choix);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = 'Ce média n’a pas pu être lu. Réessayez.';
      });
    }
  }
}

class _Choix extends StatelessWidget {
  const _Choix({
    required this.icone,
    required this.titre,
    required this.onTap,
    this.sousTitre,
  });

  final IconData icone;
  final String titre;
  final String? sousTitre;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icone, color: AppColors.primary),
      title: Text(titre, style: AppTypography.body),
      subtitle: sousTitre == null
          ? null
          : Text(
              sousTitre!,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
      onTap: onTap,
    );
  }
}
