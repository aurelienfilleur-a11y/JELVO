import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../models/group_member.dart';

/// Ligne de membre : avatar, nom, rôle et menu d'administration.
///
/// Le menu n'apparaît que pour un admin regardant quelqu'un d'autre : on ne se
/// retire pas soi-même par ce chemin, c'est le rôle de « Quitter le groupe ».
class MemberTile extends StatelessWidget {
  const MemberTile({
    super.key,
    required this.member,
    this.isMe = false,
    this.canManage = false,
    this.onPromote,
    this.onDemote,
    this.onRemove,
    this.onEditTerm,
    this.onTapPerson,
  });

  final GroupMember member;
  final bool isMe;
  final bool canManage;
  final VoidCallback? onPromote;

  /// Retirer le rôle d'administrateur. Sans ce geste, une promotion faite par
  /// erreur resterait définitive.
  final VoidCallback? onDemote;

  final VoidCallback? onRemove;

  /// Régler la durée de l'adhésion : la poser, la déplacer, ou l'effacer.
  final VoidCallback? onEditTerm;

  /// Ouvre le profil du membre. **L'avatar et le nom seulement** : le reste de
  /// la ligne porte le menu d'administration, qui agit sur l'adhésion et non
  /// sur la personne.
  final VoidCallback? onTapPerson;

  bool get _showMenu => canManage && !isMe;

  @override
  Widget build(BuildContext context) {
    final AppTexts t = AppTexts.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          GestureDetector(
            onTap: onTapPerson,
            child: AvatarStack(
              avatars: <AvatarData>[
                AvatarData(
                  name: member.displayName(t),
                  imageUrl: member.avatarUrl,
                ),
              ],
              size: 40,
            ),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: GestureDetector(
              onTap: onTapPerson,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  EmojiText(
                    isMe
                        ? t.coreVous(member.displayName(t))
                        : member.displayName(t),
                    style: context.typo.body.copyWith(
                      fontWeight: AppTypography.semiBold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (member.pseudo != null) ...<Widget>[
                    const SizedBox(height: 2),
                    EmojiText(
                      '@${member.pseudo}',
                      style: context.typo.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  // La date, pas seulement la pastille : « temporaire » sans
                  // terme n'apprend rien à qui décide de prolonger ou non.
                  if (member.isTemporary) ...<Widget>[
                    const SizedBox(height: 2),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: context.couleurs.warning,
                        ),
                        AppSpacing.hGapXs,
                        Flexible(
                          child: Text(
                            t.groupsJusquAu(
                              AppDates.shortDate(member.expiresAt!, t),
                            ),
                            style: context.typo.caption.copyWith(
                              color: context.couleurs.warning,
                              fontWeight: AppTypography.semiBold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (member.isAdmin) ...<Widget>[
            AppSpacing.hGapSm,
            StatusDot(
              tone: StatusTone.info,
              label: AppTexts.of(context).coreAdmin,
              filled: true,
            ),
          ],
          if (_showMenu)
            PopupMenuButton<_MemberAction>(
              tooltip: AppTexts.of(context).groupsGererMembre,
              // Le trois-points vertical, et non horizontal : c'est celui que
              // Material emploie partout ailleurs pour « d'autres actions »,
              // et l'ancien passait pour un ornement.
              icon: Icon(
                Icons.more_vert_rounded,
                color: context.couleurs.textSecondary,
              ),
              onSelected: (_MemberAction action) => switch (action) {
                _MemberAction.promote => onPromote?.call(),
                _MemberAction.demote => onDemote?.call(),
                _MemberAction.remove => onRemove?.call(),
                _MemberAction.term => onEditTerm?.call(),
              },
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<_MemberAction>>[
                    if (member.isAdmin)
                      PopupMenuItem<_MemberAction>(
                        value: _MemberAction.demote,
                        child: Text(
                          AppTexts.of(context).groupsRetirerRoleAdministrateur,
                        ),
                      )
                    else
                      PopupMenuItem<_MemberAction>(
                        value: _MemberAction.promote,
                        child: Text(
                          AppTexts.of(context).groupsNommerAdministrateur,
                        ),
                      ),
                    // Une seule entrée pour prolonger, écourter et rendre
                    // permanent : c'est la même écriture, et la feuille
                    // montre l'état actuel avant de le changer.
                    PopupMenuItem<_MemberAction>(
                      value: _MemberAction.term,
                      child: Text(
                        member.isTemporary
                            ? AppTexts.of(context).groupsModifierDureeAdhesion
                            : AppTexts.of(
                                context,
                              ).groupsRendreAdhesionTemporaire,
                      ),
                    ),
                    PopupMenuItem<_MemberAction>(
                      value: _MemberAction.remove,
                      child: Text(AppTexts.of(context).groupsRetirerGroupe),
                    ),
                  ],
            ),
        ],
      ),
    );
  }
}

enum _MemberAction { promote, demote, term, remove }
