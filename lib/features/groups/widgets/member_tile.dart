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
    this.onRemove,
  });

  final GroupMember member;
  final bool isMe;
  final bool canManage;
  final VoidCallback? onPromote;
  final VoidCallback? onRemove;

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
                Text(
                  isMe ? '${member.displayName} (vous)' : member.displayName,
                  style: AppTypography.body.copyWith(
                    fontWeight: AppTypography.semiBold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (member.pseudo != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    '@${member.pseudo}',
                    style: AppTypography.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
              icon: const Icon(
                Icons.more_horiz_rounded,
                color: AppColors.textSecondary,
              ),
              onSelected: (_MemberAction action) => switch (action) {
                _MemberAction.promote => onPromote?.call(),
                _MemberAction.remove => onRemove?.call(),
              },
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<_MemberAction>>[
                    if (!member.isAdmin)
                      const PopupMenuItem<_MemberAction>(
                        value: _MemberAction.promote,
                        child: Text('Nommer administrateur'),
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

enum _MemberAction { promote, remove }
