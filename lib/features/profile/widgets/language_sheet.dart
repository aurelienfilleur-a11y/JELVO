import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../../data/data_providers.dart';
import '../../../data/language_storage.dart';

/// Feuille du réglage « Langue ».
///
/// **Le choix s'applique sur place**, comme celui de l'apparence : une langue
/// se juge en la voyant, et la feuille reste ouverte pendant que l'écran
/// change derrière. Un bouton « Enregistrer » obligerait à valider à l'aveugle
/// un réglage dont on ne verrait l'effet qu'après.
class LanguageSheet extends ConsumerWidget {
  const LanguageSheet({super.key});

  static Future<void> ouvrir(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => const LanguageSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTexts t = AppTexts.of(context);
    final Locale? choix = ref.watch(localeProvider);

    return SafeArea(
      child: SingleChildScrollView(
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
              child: Text(t.profileLangue, style: context.typo.h2),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Text(
                // Le réglage est celui de cet appareil, comme l'apparence : le
                // dire évite de chercher pourquoi le téléphone est en espagnol
                // et l'ordinateur en français.
                t.profileChoixVautCetAppareil,
                style: context.typo.caption,
              ),
            ),
            // « Celle du téléphone » en tête : c'est le défaut, et c'est le
            // seul choix qui n'en est pas vraiment un — il délègue.
            _Ligne(
              titre: t.profileLangueDuTelephone,
              aide: t.profileLangueDuTelephoneAide,
              choisie: choix == null,
              onTap: () => ref.read(localeProvider.notifier).choisir(null),
            ),
            for (final Locale langue in LanguageStorage.languesPrisesEnCharge)
              _Ligne(
                // **Chaque langue est nommée dans sa propre langue.** « German »
                // ne sert à rien à quelqu'un qui cherche l'allemand sans parler
                // anglais, et traduire les noms de langues ferait chercher
                // « Allemand » à la lettre A dans une liste en espagnol.
                titre: nomNatif(langue),
                aide: _nomTraduit(langue, t),
                choisie: choix?.languageCode == langue.languageCode,
                onTap: () => ref.read(localeProvider.notifier).choisir(langue),
              ),
            AppSpacing.gapMd,
          ],
        ),
      ),
    );
  }

  /// Le nom de la langue **dans cette langue**, et il ne passe donc pas par
  /// l'ARB : traduit, il changerait de mot selon la langue courante, ce qui
  /// est exactement ce qu'on ne veut pas ici.
  static String nomNatif(Locale langue) => switch (langue.languageCode) {
    // texte-en-dur-autorise: le nom d'une langue dans sa propre langue ne se
    // traduit pas — c'est tout l'objet de cette liste.
    'fr' => 'Français',
    'de' => 'Deutsch',
    'en' => 'English',
    'es' => 'Español',
    _ => langue.languageCode,
  };

  /// Le même nom dans la langue courante, en aide : « Deutsch · Allemand ».
  /// Sans lui, quelqu'un qui ne reconnaît pas l'alphabet d'une langue ne
  /// saurait pas laquelle il touche.
  static String _nomTraduit(Locale langue, AppTexts t) =>
      switch (langue.languageCode) {
        'fr' => t.profileLangueFrancais,
        'de' => t.profileLangueAllemand,
        'en' => t.profileLangueAnglais,
        'es' => t.profileLangueEspagnol,
        _ => langue.languageCode,
      };
}

class _Ligne extends StatelessWidget {
  const _Ligne({
    required this.titre,
    required this.aide,
    required this.choisie,
    required this.onTap,
  });

  final String titre;
  final String aide;
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
          Icons.translate_rounded,
          size: 20,
          color: choisie
              ? context.couleurs.primaryInk
              : context.couleurs.textSecondary,
        ),
      ),
      title: Text(
        titre,
        style: context.typo.body.copyWith(fontWeight: AppTypography.medium),
      ),
      subtitle: Text(aide, style: context.typo.caption),
      trailing: choisie
          ? Icon(Icons.check_rounded, color: context.couleurs.primaryInk)
          : null,
      onTap: onTap,
    );
  }
}
