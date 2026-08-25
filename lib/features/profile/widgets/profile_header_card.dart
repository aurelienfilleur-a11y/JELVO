import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../models/profile.dart';

/// Carte d'en-tête du profil : avatar, identité, et les trois actions.
///
/// L'avatar porte une pastille d'appareil photo, comme partout ailleurs sur
/// les applications de ce genre — c'est le geste que les gens cherchent, et le
/// reléguer dans un menu le rendrait introuvable.
class ProfileHeaderCard extends StatelessWidget {
  const ProfileHeaderCard({
    super.key,
    required this.profile,
    required this.onChangeAvatar,
    required this.onQrCode,
    required this.onEdit,
    required this.onShare,
  });

  final Profile profile;
  final VoidCallback onChangeAvatar;
  final VoidCallback onQrCode;
  final VoidCallback onEdit;
  final VoidCallback onShare;

  static const double _tailleAvatar = 116;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        children: <Widget>[
          SizedBox(
            width: _tailleAvatar,
            height: _tailleAvatar,
            child: Stack(
              children: <Widget>[
                // `avatarAAfficher` et non `avatarUrl` : un avatar prédéfini
                // doit apparaître ici comme il apparaît partout ailleurs.
                AvatarImage(
                  data: AvatarData(
                    name: profile.displayName,
                    imageUrl: profile.avatarAAfficher,
                  ),
                  size: _tailleAvatar,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Tooltip(
                    message: 'Changer de photo',
                    child: InkWell(
                      onTap: onChangeAvatar,
                      customBorder: const CircleBorder(),
                      child: Semantics(
                        button: true,
                        label: 'Changer de photo de profil',
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                            boxShadow: AppShadows.card,
                          ),
                          child: const Icon(
                            Icons.photo_camera_rounded,
                            size: 19,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          AppSpacing.gapMd,
          Text(
            profile.displayName,
            style: AppTypography.h2,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            profile.pseudoHandle,
            style: AppTypography.body.copyWith(color: AppColors.primary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          AppSpacing.gapLg,
          const Divider(height: 1, color: AppColors.border),
          AppSpacing.gapSm,
          Row(
            children: <Widget>[
              Expanded(
                child: _Action(
                  icon: Icons.qr_code_2_rounded,
                  label: 'QR Code',
                  accented: true,
                  onTap: onQrCode,
                ),
              ),
              const _Trait(),
              Expanded(
                child: _Action(
                  icon: Icons.edit_outlined,
                  label: 'Modifier',
                  onTap: onEdit,
                ),
              ),
              const _Trait(),
              Expanded(
                child: _Action(
                  icon: Icons.ios_share_rounded,
                  label: 'Partager profil',
                  onTap: onShare,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Trait extends StatelessWidget {
  const _Trait();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 56,
    child: VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
  );
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accented = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Fond violet clair sur la première action seulement : le QR code est ce
  /// pour quoi on ouvre cette carte quand on est en face de quelqu'un.
  final bool accented;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.fieldRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accented ? AppColors.primarySoft : AppColors.background,
                borderRadius: AppRadii.fieldRadius,
              ),
              child: Icon(
                icon,
                size: 21,
                color: accented ? AppColors.primary : AppColors.midnight,
              ),
            ),
            AppSpacing.gapSm,
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: AppColors.midnight,
                fontWeight: AppTypography.semiBold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
