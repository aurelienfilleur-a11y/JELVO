import 'package:flutter/material.dart';

import '../theme/jelvo_colors.dart';
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

  /// La pastille : un aplat de 8 px, donc un objet graphique.
  Color color(JelvoColors c) => switch (this) {
    StatusTone.info => c.primary,
    StatusTone.success => c.success,
    StatusTone.warning => c.warning,
    StatusTone.danger => c.danger,
    StatusTone.neutral => c.textSecondary,
  };

  /// La même teinte **en texte**, sur le fond teinté de la puce pleine.
  ///
  /// `warning` sur `warningSoft` ne donnait que 1,81:1 : c'est la variante
  /// assombrie qui porte le libellé, jamais la teinte vive.
  Color ink(JelvoColors c) => switch (this) {
    StatusTone.info => c.primaryInk,
    StatusTone.success => c.successInk,
    StatusTone.warning => c.warningInk,
    StatusTone.danger => c.dangerInk,
    StatusTone.neutral => c.textSecondary,
  };

  Color softColor(JelvoColors c) => switch (this) {
    StatusTone.info => c.primarySoft,
    StatusTone.success => c.successSoft,
    StatusTone.warning => c.warningSoft,
    StatusTone.danger => c.dangerSoft,
    StatusTone.neutral => c.background,
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
      decoration: BoxDecoration(
        color: tone.color(context.couleurs),
        shape: BoxShape.circle,
      ),
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
          style: context.typo.caption.copyWith(
            color: filled
                ? tone.ink(context.couleurs)
                : context.couleurs.textSecondary,
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
        color: tone.softColor(context.couleurs),
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
