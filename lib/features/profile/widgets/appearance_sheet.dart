import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../../data/data_providers.dart';

/// Les trois apparences, dans l'ordre où on les propose.
///
/// « Automatique » est en tête parce que c'est le défaut, et parce que c'est
/// le seul choix qui n'en est pas vraiment un : il délègue au téléphone.
enum Apparence {
  automatique(
    ThemeMode.system,
    'Automatique',
    'Suit le réglage de votre téléphone',
    Icons.brightness_auto_rounded,
  ),
  clair(
    ThemeMode.light,
    'Clair',
    'Fond blanc, texte sombre',
    Icons.light_mode_rounded,
  ),
  sombre(
    ThemeMode.dark,
    'Sombre',
    'Fond sombre, texte clair',
    Icons.dark_mode_rounded,
  );

  const Apparence(this.mode, this.libelle, this.aide, this.icone);

  final ThemeMode mode;
  final String libelle;
  final String aide;
  final IconData icone;

  static Apparence depuis(ThemeMode mode) =>
      Apparence.values.firstWhere((Apparence a) => a.mode == mode);
}

/// Feuille du réglage « Apparence ».
///
/// **Le choix s'applique sur place, sans bouton de validation.** Une
/// apparence se juge en la voyant : la feuille reste ouverte, l'écran change
/// derrière, et l'on referme quand on est content. Un « Enregistrer »
/// obligerait à valider à l'aveugle.
class AppearanceSheet extends ConsumerWidget {
  const AppearanceSheet({super.key});

  static Future<void> ouvrir(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => const AppearanceSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode courant = ref.watch(themeModeProvider);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Text('Apparence', style: context.typo.h2),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Text(
              // Le réglage est celui de cet appareil : le dire évite de
              // chercher pourquoi le téléphone est sombre et l'ordinateur
              // clair.
              'Ce choix ne vaut que sur cet appareil.',
              style: context.typo.caption,
            ),
          ),
          for (final Apparence apparence in Apparence.values)
            _Ligne(
              apparence: apparence,
              choisie: apparence.mode == courant,
              onTap: () =>
                  ref.read(themeModeProvider.notifier).choisir(apparence.mode),
            ),
          AppSpacing.gapMd,
        ],
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({
    required this.apparence,
    required this.choisie,
    required this.onTap,
  });

  final Apparence apparence;
  final bool choisie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: choisie
              ? context.couleurs.primarySoft
              : context.couleurs.background,
          borderRadius: AppRadii.fieldRadius,
        ),
        alignment: Alignment.center,
        child: Icon(
          apparence.icone,
          size: 20,
          color: choisie
              ? context.couleurs.primaryInk
              : context.couleurs.textSecondary,
        ),
      ),
      title: Text(
        apparence.libelle,
        style: context.typo.body.copyWith(fontWeight: AppTypography.medium),
      ),
      subtitle: Text(apparence.aide, style: context.typo.caption),
      trailing: choisie
          ? Icon(Icons.check_rounded, color: context.couleurs.primaryInk)
          : null,
      onTap: onTap,
    );
  }
}
