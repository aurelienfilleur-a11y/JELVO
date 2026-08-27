import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import '../theme/emoji_runs.dart';

/// Texte **saisi par quelqu'un**, dont les emojis sortent en couleur.
///
/// À employer partout où s'affiche du contenu qu'un utilisateur a tapé :
/// bulles de conversation, réactions, noms de groupes, titres et descriptions
/// de tâches et d'événements, lieux, bio du profil, libellés de listes. Le
/// texte de l'application, lui, reste un `Text` ordinaire — il n'y a pas
/// d'emoji dans les libellés de Jelvo, et c'est une règle.
///
/// **Pourquoi un widget plutôt qu'un repli de police.** `fontFamilyFallback`
/// n'est consulté que pour ce que la police principale ne couvre pas, et Inter
/// couvre `❤ ⚠ ☀ ⬆ © ‼ ⁉` : le cœur d'un clavier iPhone sortait donc en noir,
/// tandis que `😀`, absent d'Inter, sortait bien en couleur. Le détail du
/// mécanisme et des trois règles de reconnaissance vit dans
/// `core/theme/emoji_runs.dart`.
///
/// Le coût est nul sur un texte sans emoji : le découpage rend alors une seule
/// suite, et le widget se réduit à un `Text`.
class EmojiText extends StatelessWidget {
  const EmojiText(
    this.data, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.softWrap,
    this.semanticsLabel,
  });

  final String data;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool? softWrap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final List<EmojiRun> suites = decouperEmojis(data);

    // Une seule suite — le cas courant, texte pur, et le cas d'une réaction,
    // emoji pur — se rend par un `Text` ordinaire. Ce n'est pas qu'une
    // économie : `Text.rich` avec des enfants échappe à `find.text`, et
    // n'y recourir que pour les chaînes vraiment mixtes garde les tests, et
    // l'arbre de sémantique, tels qu'ils étaient.
    if (suites.length <= 1) {
      return Text(
        data,
        style: suites.isNotEmpty && suites.first.isEmoji
            // `inherit` reste vrai : le style ambiant — taille, couleur —
            // continue de s'appliquer, seule la police change.
            ? AppTypography.emoji(style ?? const TextStyle())
            : style,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
        softWrap: softWrap,
        semanticsLabel: semanticsLabel,
      );
    }

    return Text.rich(
      spanEmojis(data, style: style),
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      softWrap: softWrap,
      semanticsLabel: semanticsLabel,
    );
  }
}

/// Le même découpage, sous forme de `TextSpan`.
///
/// Utile là où un widget ne convient pas : un `TextEditingController`, un
/// `RichText` déjà composé, un `Tooltip`.
TextSpan spanEmojis(String texte, {TextStyle? style}) {
  final TextStyle base = style ?? const TextStyle();
  return TextSpan(
    style: style,
    children: <InlineSpan>[
      for (final EmojiRun suite in decouperEmojis(texte))
        TextSpan(
          text: suite.text,
          style: suite.isEmoji ? AppTypography.emoji(base) : null,
        ),
    ],
  );
}

/// Champ de saisie dont les emojis s'affichent en couleur **pendant la
/// frappe**.
///
/// `TextField` ne prend qu'un `style` unique : le découpage doit donc se faire
/// dans le contrôleur, seul endroit où Flutter laisse composer les suites d'un
/// champ. Sans lui, l'emoji tapé au clavier serait noir dans le champ puis
/// coloré dans la bulle une fois envoyé — l'incohérence la plus visible qui
/// soit, puisque les deux sont à l'écran en même temps.
class EmojiTextEditingController extends TextEditingController {
  EmojiTextEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    // La composition — le soulignement d'une saisie en cours, sur les claviers
    // qui en ont une — est laissée au comportement d'origine : la recomposer
    // ici demanderait de recouper les suites sur la plage de composition, pour
    // un gain nul sur un emoji, qui s'insère d'un coup.
    if (!value.isComposingRangeValid || !withComposing) {
      return spanEmojis(value.text, style: style);
    }
    return super.buildTextSpan(
      context: context,
      style: style,
      withComposing: withComposing,
    );
  }
}
