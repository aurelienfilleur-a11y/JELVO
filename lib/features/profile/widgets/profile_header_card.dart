import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../models/profile.dart';
import 'profile_action_row.dart';

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
                    message: AppTexts.of(context).profileChangerPhoto,
                    child: InkWell(
                      onTap: onChangeAvatar,
                      customBorder: const CircleBorder(),
                      child: Semantics(
                        button: true,
                        label: AppTexts.of(context).profileChangerPhotoProfil,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: context.couleurs.surface,
                            shape: BoxShape.circle,
                            boxShadow: context.ombres.card,
                          ),
                          child: Icon(
                            Icons.photo_camera_rounded,
                            size: 19,
                            color: context.couleurs.primary,
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
          EmojiText(
            profile.displayName,
            style: context.typo.h2,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          EmojiText(
            profile.pseudoHandle,
            style: context.typo.body.copyWith(color: context.couleurs.primary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          // Le fond violet clair va au QR code et à lui seul : c'est ce pour
          // quoi on ouvre cette carte quand on est en face de quelqu'un.
          ProfileActionRow(
            actions: <ProfileAction>[
              ProfileAction(
                icon: Icons.qr_code_2_rounded,
                label: AppTexts.of(context).profileQRCode,
                accented: true,
                onTap: onQrCode,
              ),
              ProfileAction(
                icon: Icons.edit_outlined,
                label: AppTexts.of(context).coreModifier,
                onTap: onEdit,
              ),
              ProfileAction(
                icon: Icons.ios_share_rounded,
                label: AppTexts.of(context).profilePartagerProfil,
                onTap: onShare,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
