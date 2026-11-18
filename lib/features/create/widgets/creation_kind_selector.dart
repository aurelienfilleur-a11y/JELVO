import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../models/creation_kind.dart';

/// Sélecteur du type d'élément à créer, sous forme de trois cartes empilées.
class CreationKindSelector extends StatelessWidget {
  const CreationKindSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final CreationKind selected;
  final ValueChanged<CreationKind> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (final CreationKind kind in CreationKind.values) ...<Widget>[
          _KindCard(
            kind: kind,
            selected: kind == selected,
            onTap: () => onSelected(kind),
          ),
          if (kind != CreationKind.values.last) AppSpacing.gapMd,
        ],
      ],
    );
  }
}

class _KindCard extends StatelessWidget {
  const _KindCard({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final CreationKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      // Le contour prend la couleur du type sélectionné ; l'ombre est retirée
      // sur les cartes inactives pour que la sélection ressorte.
      borderColor: selected
          ? kind.color(context.couleurs)
          : context.couleurs.border,
      shadows: selected ? context.ombres.raised : const <BoxShadow>[],
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: kind.color(context.couleurs).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.md),
            ),
            child: Icon(
              kind.icon,
              color: kind.color(context.couleurs),
              size: 22,
            ),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(kind.label, style: context.typo.h3),
                const SizedBox(height: 2),
                Text(
                  kind.description,
                  style: context.typo.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          AppSpacing.hGapSm,
          _RadioMark(selected: selected, color: kind.color(context.couleurs)),
        ],
      ),
    );
  }
}

class _RadioMark extends StatelessWidget {
  const _RadioMark({required this.selected, required this.color});

  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? color : Colors.transparent,
        border: Border.all(
          color: selected ? color : context.couleurs.border,
          width: 1.5,
        ),
      ),
      child: selected
          ? Icon(
              Icons.check_rounded,
              size: 14,
              color: context.couleurs.onAccent,
            )
          : null,
    );
  }
}
