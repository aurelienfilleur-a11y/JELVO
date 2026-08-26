import 'package:flutter/material.dart';

import '../../../core/core.dart';

/// L'index alphabétique posé le long du bord droit.
///
/// Il ne montre **que les lettres présentes** : une cible qui ne mène nulle
/// part est pire qu'une lettre absente. Un glissement du doigt le long du rail
/// saute de lettre en lettre, comme un toucher.
class AlphabetIndex extends StatelessWidget {
  const AlphabetIndex({
    super.key,
    required this.lettres,
    required this.onLettre,
  });

  final List<String> lettres;
  final ValueChanged<String> onLettre;

  @override
  Widget build(BuildContext context) {
    if (lettres.length < 2) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints contraintes) {
        void viser(Offset position) {
          final double pas = contraintes.maxHeight / lettres.length;
          final int index = (position.dy / pas).floor().clamp(
            0,
            lettres.length - 1,
          );
          onLettre(lettres[index]);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (TapDownDetails d) => viser(d.localPosition),
          onVerticalDragUpdate: (DragUpdateDetails d) => viser(d.localPosition),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              for (final String lettre in lettres)
                Expanded(
                  child: Center(
                    child: Text(
                      lettre,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: AppTypography.semiBold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
