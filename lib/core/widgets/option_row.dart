import 'package:flutter/material.dart';

import '../theme/jelvo_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_card.dart';

/// Ligne de réglage d'un formulaire : icône, libellé, aide en dessous, valeur à
/// droite en violet.
///
/// La valeur est le seul élément coloré de la ligne : c'est elle qui change,
/// et c'est donc elle que l'œil doit trouver en premier. L'icône, elle, sert à
/// retrouver une ligne connue sans la lire — une cloche pour le rappel, deux
/// flèches pour la répétition.
///
/// Le composant vit dans `core` et non dans une feature : il ne prend que des
/// `String`, une `IconData` et un rappel. Les formulaires de tâche et
/// d'événement le partagent, et une feature ne lit pas les widgets d'une autre.
class OptionRow extends StatelessWidget {
  const OptionRow({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.hint,
    this.icon,
  });

  final String label;
  final String value;
  final String? hint;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              OptionIcon(icon: icon!),
              AppSpacing.hGapMd,
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: context.typo.body.copyWith(
                      fontWeight: AppTypography.medium,
                    ),
                  ),
                  if (hint != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(hint!, style: context.typo.caption),
                  ],
                ],
              ),
            ),
            AppSpacing.hGapMd,
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.typo.body.copyWith(
                  color: context.couleurs.primary,
                  fontWeight: AppTypography.semiBold,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.couleurs.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// La pastille carrée qui porte l'icône d'une ligne de réglage.
class OptionIcon extends StatelessWidget {
  const OptionIcon({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: context.couleurs.primarySoft,
        borderRadius: AppRadii.fieldRadius,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 20, color: context.couleurs.primary),
    );
  }
}

/// Carte « Plus d'options » : un en-tête qui se replie sur son contenu.
///
/// Ce qui s'y range n'est pas accessoire, seulement rare — l'échéance d'une
/// tâche, sa priorité. Les laisser dépliés en permanence donnerait un
/// formulaire de dix champs pour une saisie qui en demande un.
class ExpandableOptions extends StatelessWidget {
  const ExpandableOptions({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.children,
    this.title = 'Plus d’options',
    this.hint,
    this.icon = Icons.tune_rounded,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;
  final String title;
  final String? hint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: <Widget>[
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                children: <Widget>[
                  OptionIcon(icon: icon),
                  AppSpacing.hGapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: context.typo.body.copyWith(
                            fontWeight: AppTypography.medium,
                          ),
                        ),
                        if (hint != null) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(hint!, style: context.typo.caption),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: context.couleurs.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...<Widget>[
            Divider(height: 1, color: context.couleurs.border),
            AppSpacing.gapMd,
            ...children,
            AppSpacing.gapMd,
          ],
        ],
      ),
    );
  }
}
