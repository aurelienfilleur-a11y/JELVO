import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'emoji_text.dart';
import '../utils/date_formatting.dart';
import 'avatar_stack.dart';
import 'primary_button.dart';
import 'secondary_button.dart';

/// L'en-tête commun aux trois écrans d'invitation : qui, quoi, quand.
///
/// Les trois écrans — rejoindre un groupe, venir à un événement, prendre une
/// tâche — répondent à la même question avant toute autre : **qui me
/// demande ?** Le nom, le visage et l'ancienneté de la demande passent donc
/// avant le détail de ce à quoi on est convié.
///
/// Comme tout composant de `core/widgets`, il ne connaît pas le domaine : il
/// prend un [AvatarData] et deux chaînes, jamais un `GroupInvitation` ni un
/// `CalendarEvent`. La phrase d'action est écrite par l'écran, seul à savoir
/// s'il s'agit d'inviter, de convier ou de confier.
class InvitationHeader extends StatelessWidget {
  const InvitationHeader({
    super.key,
    required this.author,
    required this.action,
    this.since,
    this.now,
  });

  /// L'auteur de la demande. Sans photo ni avatar prédéfini, les initiales
  /// prennent le relais — pas de pastille de présence : `last_seen_at` n'est
  /// écrit nulle part, et un point vert permanent serait un mensonge.
  final AvatarData author;

  /// Ce qu'il fait, à la troisième personne et sans son nom :
  /// « vous invite à rejoindre un groupe ».
  final String action;

  /// Quand la demande a été faite. Omise si la base ne la connaît pas.
  final DateTime? since;

  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AvatarImage(data: author, size: 52),
        AppSpacing.hGapMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              EmojiText(
                author.name,
                style: AppTypography.h3,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              EmojiText(
                action,
                style: AppTypography.bodyMuted,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (since != null) ...<Widget>[
                AppSpacing.gapXs,
                Text(
                  AppDates.timeAgo(since!, now: now),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Une ligne de la carte centrale : icône, libellé, valeur.
///
/// Les trois écrans en alignent trois ou quatre — date, lieu, groupe,
/// échéance, priorité. Une seule implémentation pour que la colonne des
/// icônes tombe au même endroit d'un écran à l'autre.
class InvitationDetailRow extends StatelessWidget {
  const InvitationDetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.dernier = false,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Le dernier de la carte ne porte pas de trait sous lui.
  final bool dernier;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppSpacing.md),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    EmojiText(
                      value,
                      style: AppTypography.body.copyWith(
                        fontWeight: AppTypography.semiBold,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!dernier)
          const Divider(height: 1, indent: 52, color: AppColors.border),
      ],
    );
  }
}

/// Les deux boutons du bas : refus à gauche en contour, acceptation à droite
/// en plein.
///
/// L'ordre n'est pas décoratif — c'est celui de la maquette, et il tient le
/// même raisonnement partout : le geste qui engage est le plus à droite, sous
/// le pouce, et il est le seul à porter du plein.
class InvitationActions extends StatelessWidget {
  const InvitationActions({
    super.key,
    required this.refuser,
    required this.accepter,
    required this.onRefuser,
    required this.onAccepter,
    this.enCours = false,
  });

  final String refuser;
  final String accepter;
  final VoidCallback? onRefuser;
  final VoidCallback? onAccepter;
  final bool enCours;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: SecondaryButton(
            label: refuser,
            isDestructive: true,
            onPressed: enCours ? null : onRefuser,
          ),
        ),
        AppSpacing.hGapMd,
        Expanded(
          child: PrimaryButton(
            label: accepter,
            isLoading: enCours,
            onPressed: onAccepter,
          ),
        ),
      ],
    );
  }
}
