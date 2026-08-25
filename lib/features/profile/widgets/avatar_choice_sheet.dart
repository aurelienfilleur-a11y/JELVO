import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../router/app_routes.dart';
import '../../auth/models/auth_failure.dart';
import '../../auth/widgets/avatar_picker.dart';
import '../providers/profile_providers.dart';

/// Les trois façons de changer d'avatar, au même endroit.
///
/// Le bouton d'appareil photo posé sur la photo de profil ouvre cette feuille
/// plutôt que d'aller droit à la galerie du téléphone : les avatars prédéfinis
/// sont un choix de même rang, et les cacher derrière un second bouton
/// reviendrait à en faire une option de repli.
class AvatarChoiceSheet extends ConsumerStatefulWidget {
  const AvatarChoiceSheet({super.key, required this.aUnAvatar});

  /// Le retrait n'est proposé que s'il y a quelque chose à retirer.
  final bool aUnAvatar;

  static Future<void> ouvrir(BuildContext context, {required bool aUnAvatar}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AvatarChoiceSheet(aUnAvatar: aUnAvatar),
    );
  }

  @override
  ConsumerState<AvatarChoiceSheet> createState() => _AvatarChoiceSheetState();
}

class _AvatarChoiceSheetState extends ConsumerState<AvatarChoiceSheet> {
  bool _travail = false;
  String? _erreur;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Photo de profil', style: AppTypography.h2),

          if (_erreur != null) ...<Widget>[
            AppSpacing.gapLg,
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.dangerSoft,
                borderRadius: AppRadii.fieldRadius,
              ),
              child: Text(
                _erreur!,
                style: AppTypography.caption.copyWith(color: AppColors.danger),
              ),
            ),
          ],

          AppSpacing.gapLg,
          _Choix(
            icon: Icons.photo_library_outlined,
            label: 'Choisir une photo',
            detail: 'Depuis les photos de votre appareil',
            onTap: _travail ? null : _choisirPhoto,
          ),
          _Choix(
            icon: Icons.face_retouching_natural_rounded,
            label: 'Choisir un avatar Jelvo',
            detail: 'Quatre-vingt-treize illustrations au choix',
            onTap: _travail
                ? null
                : () {
                    Navigator.of(context).pop();
                    context.pushNamed(AppRoutes.avatarGallery);
                  },
          ),
          if (widget.aUnAvatar)
            _Choix(
              icon: Icons.delete_outline_rounded,
              label: 'Retirer',
              detail: 'Vos initiales prendront la place',
              destructive: true,
              onTap: _travail ? null : _retirer,
            ),

          if (_travail) ...<Widget>[
            AppSpacing.gapLg,
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  Future<void> _choisirPhoto() async {
    final NavigatorState navigateur = Navigator.of(context);
    setState(() {
      _travail = true;
      _erreur = null;
    });
    try {
      final ({Uint8List bytes, String extension})? choix =
          await AvatarPicker.choisirPhoto();
      if (choix == null) {
        if (mounted) setState(() => _travail = false);
        return;
      }
      await ref
          .read(profileActionsProvider)
          .changeAvatar(choix.bytes, choix.extension);
      navigateur.maybePop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _travail = false;
        _erreur = AuthFailure.from(error).message;
      });
    }
  }

  Future<void> _retirer() async {
    final NavigatorState navigateur = Navigator.of(context);
    setState(() {
      _travail = true;
      _erreur = null;
    });
    try {
      await ref.read(profileActionsProvider).effacerAvatar();
      navigateur.maybePop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _travail = false;
        _erreur = AuthFailure.from(error).message;
      });
    }
  }
}

class _Choix extends StatelessWidget {
  const _Choix({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final Color couleur = destructive ? AppColors.danger : AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.fieldRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: couleur.withValues(alpha: 0.12),
                borderRadius: AppRadii.fieldRadius,
              ),
              child: Icon(icon, size: 20, color: couleur),
            ),
            AppSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: AppTypography.body.copyWith(
                      fontWeight: AppTypography.semiBold,
                      color: destructive ? AppColors.danger : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: AppTypography.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
