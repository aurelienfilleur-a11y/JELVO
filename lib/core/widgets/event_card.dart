import 'package:flutter/material.dart';

import '../theme/jelvo_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'emoji_text.dart';
import 'app_card.dart';
import 'avatar_stack.dart';
import 'status_dot.dart';

/// Carte d'événement : barre d'accent verticale, horaire, titre, lieu,
/// participants et statut.
class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.title,
    required this.timeLabel,
    this.dateLabel,
    this.location,
    this.groupName,
    this.accentColor,
    this.participants = const <AvatarData>[],
    this.statusTone,
    this.statusLabel,
    this.onTap,
  });

  final String title;

  /// Plage horaire déjà formatée, p. ex. « 14:00 – 15:30 ».
  final String timeLabel;

  /// Date déjà formatée, p. ex. « Jeu. 6 août ». Omise pour les vues « du jour ».
  final String? dateLabel;

  final String? location;

  /// Groupe organisateur, `null` pour un événement personnel.
  final String? groupName;

  /// `null` : le violet du thème, résolu au `build`.
  final Color? accentColor;
  final List<AvatarData> participants;
  final StatusTone? statusTone;
  final String? statusLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Barre d'accent : rappelle la couleur du groupe organisateur.
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: accentColor ?? context.couleurs.primary,
                borderRadius: BorderRadius.circular(AppSpacing.xs),
              ),
            ),
            AppSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: context.couleurs.textSecondary,
                      ),
                      AppSpacing.hGapXs,
                      Flexible(
                        child: Text(
                          dateLabel == null
                              ? timeLabel
                              : '$dateLabel · $timeLabel',
                          style: context.typo.caption.copyWith(
                            fontWeight: AppTypography.medium,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (statusTone != null) ...<Widget>[
                        AppSpacing.hGapSm,
                        StatusDot(tone: statusTone!, label: statusLabel),
                      ],
                    ],
                  ),
                  AppSpacing.gapXs,
                  EmojiText(
                    title,
                    style: context.typo.body.copyWith(
                      fontWeight: AppTypography.semiBold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (location != null || groupName != null) ...<Widget>[
                    AppSpacing.gapXs,
                    Row(
                      children: <Widget>[
                        Icon(
                          location != null
                              ? Icons.place_outlined
                              : Icons.groups_rounded,
                          size: 14,
                          color: context.couleurs.textSecondary,
                        ),
                        AppSpacing.hGapXs,
                        Flexible(
                          child: EmojiText(
                            <String?>[
                              groupName,
                              location,
                            ].whereType<String>().join(' · '),
                            style: context.typo.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (participants.isNotEmpty) ...<Widget>[
                    AppSpacing.gapMd,
                    AvatarStack(avatars: participants, size: 26, maxVisible: 4),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
