import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Sémantique d'un [StatusDot], indépendante de la couleur brute.
enum StatusTone {
  /// Neutre / informatif (violet de marque).
  info,

  /// Confirmé, terminé, disponible.
  success,

  /// En attente, échéance proche.
  warning,

  /// Conflit, refus, retard.
  danger,

  /// Inactif, brouillon, archivé.
  neutral;

  Color get color => switch (this) {
    StatusTone.info => AppColors.primary,
    StatusTone.success => AppColors.success,
    StatusTone.warning => AppColors.warning,
    StatusTone.danger => AppColors.danger,
    StatusTone.neutral => AppColors.textSecondary,
  };

  Color get softColor => switch (this) {
    StatusTone.info => AppColors.primarySoft,
    StatusTone.success => AppColors.successSoft,
    StatusTone.warning => AppColors.warningSoft,
    StatusTone.danger => AppColors.dangerSoft,
    StatusTone.neutral => AppColors.background,
  };
}

/// Pastille de statut, avec libellé optionnel.
///
/// Sans [label] c'est un simple point de 8 px ; avec [label] la pastille et le
/// texte sont rendus ensemble, et [filled] les enveloppe dans une puce colorée.
class StatusDot extends StatelessWidget {
  const StatusDot({
    super.key,
    this.tone = StatusTone.info,
    this.label,
    this.size = 8,
    this.filled = false,
  });

  final StatusTone tone;
  final String? label;
  final double size;

  /// Affiche un fond teinté derrière la pastille et son libellé.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final Widget dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: tone.color, shape: BoxShape.circle),
    );

    if (label == null) {
      return Semantics(label: _semanticsLabel, child: dot);
    }

    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        dot,
        AppSpacing.hGapSm,
        Text(
          label!,
          style: AppTypography.caption.copyWith(
            color: filled ? tone.color : AppColors.textSecondary,
            fontWeight: AppTypography.medium,
          ),
        ),
      ],
    );

    if (!filled) {
      return content;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: tone.softColor,
        borderRadius: BorderRadius.circular(AppSpacing.md),
      ),
      child: content,
    );
  }

  String get _semanticsLabel => switch (tone) {
    StatusTone.info => 'Information',
    StatusTone.success => 'Confirmé',
    StatusTone.warning => 'En attente',
    StatusTone.danger => 'Conflit',
    StatusTone.neutral => 'Inactif',
  };
}
