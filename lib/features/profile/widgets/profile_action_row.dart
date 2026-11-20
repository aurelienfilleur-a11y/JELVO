import 'package:flutter/material.dart';

import '../../../core/core.dart';

/// Une action de la rangée sous l'identité, dans une carte de profil.
@immutable
class ProfileAction {
  const ProfileAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accented = false,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Fond violet clair : l'action pour laquelle on ouvre la carte.
  final bool accented;

  /// Rouge. Retirer quelqu'un de son carnet se défait d'une demande, mais
  /// l'annoncer en gris le mettrait au même rang que « Épingler ».
  final bool destructive;
}

/// La rangée d'actions d'une carte de profil — le sien, ou celui d'un autre.
///
/// Elle vit à part parce que **les deux cartes la portent, avec des actions
/// différentes** : QR code, modifier, partager sur son propre profil ; ajouter,
/// retirer, épingler sur celui de quelqu'un d'autre. L'allure doit rester la
/// même — c'est elle qui fait reconnaître l'écran — et deux copies auraient
/// fini par diverger d'un rayon ou d'une graisse.
class ProfileActionRow extends StatelessWidget {
  const ProfileActionRow({super.key, required this.actions});

  final List<ProfileAction> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    final List<Widget> enfants = <Widget>[];
    for (int i = 0; i < actions.length; i++) {
      if (i > 0) enfants.add(const _Trait());
      enfants.add(Expanded(child: _Action(action: actions[i])));
    }

    return Column(
      children: <Widget>[
        AppSpacing.gapLg,
        Divider(height: 1, color: context.couleurs.border),
        AppSpacing.gapSm,
        Row(children: enfants),
      ],
    );
  }
}

class _Trait extends StatelessWidget {
  const _Trait();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: VerticalDivider(
      width: 1,
      thickness: 1,
      color: context.couleurs.border,
    ),
  );
}

class _Action extends StatelessWidget {
  const _Action({required this.action});

  final ProfileAction action;

  @override
  Widget build(BuildContext context) {
    final Color encre = action.destructive
        ? context.couleurs.danger
        : action.accented
        ? context.couleurs.primary
        : context.couleurs.encre;
    final Color fond = action.destructive
        ? context.couleurs.dangerSoft
        : action.accented
        ? context.couleurs.primarySoft
        : context.couleurs.background;

    return InkWell(
      onTap: action.onTap,
      borderRadius: AppRadii.fieldRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: fond,
                borderRadius: AppRadii.fieldRadius,
              ),
              child: Icon(action.icon, size: 21, color: encre),
            ),
            AppSpacing.gapSm,
            Text(
              action.label,
              style: context.typo.caption.copyWith(
                color: action.destructive
                    ? context.couleurs.dangerInk
                    : context.couleurs.encre,
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
