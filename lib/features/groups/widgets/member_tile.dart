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

  bool get _showMenu => canManage && !isMe;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          AvatarStack(
            avatars: <AvatarData>[
              AvatarData(name: member.displayName, imageUrl: member.avatarUrl),
            ],
            size: 40,
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                EmojiText(
                  isMe ? '${member.displayName} (vous)' : member.displayName,
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
                          'Jusqu’au ${AppDates.shortDate(member.expiresAt!)}',
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
          if (member.isAdmin) ...<Widget>[
            AppSpacing.hGapSm,
            const StatusDot(
              tone: StatusTone.info,
              label: 'Admin',
              filled: true,
            ),
          ],
          if (_showMenu)
            PopupMenuButton<_MemberAction>(
              tooltip: 'Gérer ce membre',
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
                      const PopupMenuItem<_MemberAction>(
                        value: _MemberAction.demote,
                        child: Text('Retirer le rôle d’administrateur'),
                      )
                    else
                      const PopupMenuItem<_MemberAction>(
                        value: _MemberAction.promote,
                        child: Text('Nommer administrateur'),
                      ),
                    // Une seule entrée pour prolonger, écourter et rendre
                    // permanent : c'est la même écriture, et la feuille
                    // montre l'état actuel avant de le changer.
                    PopupMenuItem<_MemberAction>(
                      value: _MemberAction.term,
                      child: Text(
                        member.isTemporary
                            ? 'Modifier la durée de l’adhésion'
                            : 'Rendre l’adhésion temporaire',
                      ),
                    ),
                    const PopupMenuItem<_MemberAction>(
                      value: _MemberAction.remove,
                      child: Text('Retirer du groupe'),
                    ),
                  ],
            ),
        ],
      ),
    );
  }
}

enum _MemberAction { promote, demote, term, remove }
