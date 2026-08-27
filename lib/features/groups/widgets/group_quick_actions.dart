import 'package:flutter/material.dart';

import '../../../core/core.dart';

/// Rangée d'accès rapides, sous les compteurs.
///
/// **Trois pictogrammes, et non six.** La maquette en proposait aussi
/// « Listes », « Dépenses » et « Notes » : aucune des trois n'existe dans
/// Jelvo, ni en base ni à l'écran. Les poser en gris ou les laisser ouvrir un
/// écran vide serait promettre une fonctionnalité qui n'arrive pas — la même
/// règle que le chevron absent de l'e-mail sur le profil.
///
/// Les trois qui restent mènent chacune quelque part de réel : la conversation
/// du groupe, ses tâches, et le calendrier filtré sur lui.
class GroupQuickActions extends StatelessWidget {
  const GroupQuickActions({super.key, required this.actions});

  final List<GroupQuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          for (final GroupQuickAction action in actions)
            Expanded(child: _Bouton(action: action)),
        ],
      ),
    );
  }
}

@immutable
class GroupQuickAction {
  const GroupQuickAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  /// Compteur rouge posé sur l'icône, masqué à zéro par `NavBadge`.
  final int badge;
}

class _Bouton extends StatelessWidget {
  const _Bouton({required this.action});

  final GroupQuickAction action;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: action.label,
      child: InkWell(
        onTap: action.onPressed,
        borderRadius: AppRadii.cardRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: AppRadii.cardRadius,
                ),
                alignment: Alignment.center,
                child: NavBadge(
                  count: action.badge,
                  child: Icon(action.icon, color: AppColors.primary),
                ),
              ),
              AppSpacing.gapSm,
              Text(
                action.label,
                style: AppTypography.caption.copyWith(
                  color: AppColors.midnight,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
