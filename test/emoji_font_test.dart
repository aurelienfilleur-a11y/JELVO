import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelvo/core/core.dart';

/// La police d'emojis et son câblage.
///
/// **Un repli de police ne casse rien quand il manque** : le texte s'affiche,
/// en noir et blanc ou en carré vide. Rien ne ferait donc échouer la CI, et le
/// défaut ne se constaterait qu'à l'écran — c'est la raison d'être de ce
/// fichier.
///
/// Ce qui n'est **pas** éprouvé ici : que le rendu soit effectivement en
/// couleur. Cela demande une capture de pixels que le harnais de test ne peint
/// pas de façon fiable — `toImageSync` sur une `RepaintBoundary` rend une image
/// blanche. La vérification a été faite à la main, par capture golden : le cœur
/// ressort en `#FF2F2F`, et le détail est consigné dans
/// `assets/fonts/README.md`.
void main() {
  testWidgets('la police est au dépôt, et c’est bien la variante COLRv1', (
    WidgetTester tester,
  ) async {
    final ByteData octets = await rootBundle.load(
      'assets/fonts/NotoColorEmoji.ttf',
    );

    final ByteData entete = octets.buffer.asByteData();
    expect(entete.getUint32(0), 0x00010000, reason: 'en-tête TrueType');

    // `COLR` dit la variante vectorielle. La variante bitmap (`CBDT`) pèse
    // 9,4 Mio compressés contre 2,7 : un échange silencieux de l'une pour
    // l'autre quadruplerait le poids du bundle sans rien changer à l'écran.
    final String premiereTable = String.fromCharCodes(
      octets.buffer.asUint8List(12, 4),
    );
    expect(premiereTable, 'COLR');
  });

  test('tous les styles de l’échelle portent le repli', () {
    // Le repli est posé une fois pour toutes dans `AppTypography` plutôt que
    // site par site : un écran ajouté demain l'a par construction, là où une
    // liste de sites finirait par en oublier un.
    const AppTypography typo = AppTypography(JelvoColors.clair);
    for (final TextStyle style in <TextStyle>[
      typo.h1,
      typo.h2,
      typo.h3,
      typo.body,
      typo.bodyMuted,
      typo.caption,
      typo.button,
    ]) {
      expect(style.fontFamilyFallback, contains('NotoColorEmoji'));
    }
  });

  test('le thème complet le porte aussi', () {
    // `textTheme` est ce que lisent les widgets Material qui ne passent pas
    // par `AppTypography` directement.
    final TextTheme theme = const AppTypography(JelvoColors.clair).textTheme;
    for (final TextStyle? style in <TextStyle?>[
      theme.headlineLarge,
      theme.titleMedium,
      theme.bodyMedium,
      theme.bodySmall,
      theme.labelLarge,
    ]) {
      expect(style?.fontFamilyFallback, contains('NotoColorEmoji'));
    }
  });

  group('Le découpage des suites', () {
    // Ces trois cas sont ceux qu'on a demandé d'éprouver : un cœur du clavier,
    // un emoji composé, un drapeau.
    test('le cœur du clavier porte son sélecteur, et devient un emoji', () {
      // U+2764 U+FE0F — ce que produit le clavier d'un iPhone. Sans le
      // sélecteur, Unicode dit « présentation texte », et le cœur noir
      // d'Inter est alors le rendu juste : les deux cas se distinguent.
      expect(grappeEstEmoji('❤️'), isTrue);
      expect(grappeEstEmoji('❤'), isFalse);
    });

    test('un emoji composé reste d’un seul tenant', () {
      // Famille, ton de peau, séquence ZWJ : découper la grappe empêcherait
      // la ligature `GSUB` de se former, et sortirait les composants un à un.
      for (final String compose in <String>[
        '\u{1F468}‍\u{1F469}‍\u{1F467}',
        '\u{1F44D}\u{1F3FD}',
        '\u{1F469}‍⚕️',
      ]) {
        final List<EmojiRun> suites = decouperEmojis(compose);
        expect(suites, hasLength(1), reason: compose);
        expect(suites.single.isEmoji, isTrue, reason: compose);
        expect(suites.single.text, compose);
      }
    });

    test('un drapeau est une grappe, pas deux lettres', () {
      final List<EmojiRun> suites = decouperEmojis('\u{1F1EB}\u{1F1F7}');
      expect(suites, hasLength(1));
      expect(suites.single.isEmoji, isTrue);
    });

    test('le texte et les emojis se séparent dans l’ordre', () {
      expect(decouperEmojis('Bravo ❤️ merci'), <EmojiRun>[
        const EmojiRun('Bravo ', isEmoji: false),
        const EmojiRun('❤️', isEmoji: true),
        const EmojiRun(' merci', isEmoji: false),
      ]);
    });

    test('ce qui n’est pas un emoji le reste', () {
      // `©` et `1` sont couverts par la police d'emojis, mais ce sont du
      // texte : les y envoyer changerait le rendu d'un copyright et d'un
      // chiffre. Seule l'enceinte des touches fait de `1` un emoji.
      expect(grappeEstEmoji('©'), isFalse);
      expect(grappeEstEmoji('1'), isFalse);
      expect(grappeEstEmoji('1️⃣'), isTrue);
      expect(decouperEmojis('Jelvo © 2026'), hasLength(1));
    });

    test('un carré blanc est un emoji sans porter de sélecteur', () {
      // `U+2B1C` a `Emoji_Presentation=Yes` **et** figure dans Inter : c'est
      // le seul cas où la règle du sélecteur ne suffirait pas.
      expect(grappeEstEmoji('⬜'), isTrue);
    });
  });

  group('EmojiText', () {
    Future<void> poser(WidgetTester tester, Widget enfant) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: enfant)),
      ),
    );

    testWidgets('un texte sans emoji reste un Text ordinaire', (
      WidgetTester tester,
    ) async {
      await poser(tester, const EmojiText('On se retrouve à midi'));

      // Pas de `Text.rich` : `find.text` continue de fonctionner, et l'arbre
      // de sémantique ne change pas.
      final Text rendu = tester.widget<Text>(find.byType(Text));
      expect(rendu.data, 'On se retrouve à midi');
      expect(rendu.style?.fontFamily, isNot(AppTypography.emojiFamily));
    });

    testWidgets('un cœur du clavier reçoit la police d’emojis', (
      WidgetTester tester,
    ) async {
      await poser(
        tester,
        EmojiText(
          'Bravo ❤️',
          style: const AppTypography(JelvoColors.clair).body,
        ),
      );

      final List<TextSpan> suites = _feuilles(tester);

      expect(suites[0].text, 'Bravo ');
      expect(suites[0].style?.fontFamily, isNot(AppTypography.emojiFamily));

      expect(suites[1].text, '❤️');
      expect(suites[1].style?.fontFamily, AppTypography.emojiFamily);
      // Le repli d'Inter est vidé : le laisser rouvrirait la porte qu'on
      // ferme, puisque c'est précisément Inter qui capturait le cœur.
    });

    testWidgets('un emoji seul garde un Text, avec la bonne police', (
      WidgetTester tester,
    ) async {
      await poser(tester, const EmojiText('👍'));

      final Text rendu = tester.widget<Text>(find.byType(Text));
      expect(rendu.data, '👍');
      expect(rendu.style?.fontFamily, AppTypography.emojiFamily);
    });

    testWidgets('le champ de saisie colore aussi ce qu’on tape', (
      WidgetTester tester,
    ) async {
      // Sans le contrôleur, l'emoji serait noir dans le champ puis coloré
      // dans la bulle — les deux étant à l'écran en même temps.
      final EmojiTextEditingController controleur = EmojiTextEditingController(
        text: 'Merci ❤️',
      );
      addTearDown(controleur.dispose);

      await poser(tester, TextField(controller: controleur));

      final TextSpan span = controleur.buildTextSpan(
        context: tester.element(find.byType(TextField)),
        withComposing: false,
      );
      final List<TextSpan> suites = <TextSpan>[];
      _aplatir(span, suites);

      expect(suites.last.text, '❤️');
      expect(suites.last.style?.fontFamily, AppTypography.emojiFamily);
    });
  });
}

/// Les `TextSpan` qui portent réellement du texte, dans l'ordre.
///
/// `Text.rich` emboîte le span reçu sous celui du style effectif : lire
/// `children` au premier niveau ne rend donc que l'emballage.
List<TextSpan> _feuilles(WidgetTester tester) {
  final RichText rendu = tester.widget<RichText>(
    find.descendant(
      of: find.byType(EmojiText),
      matching: find.byType(RichText),
    ),
  );
  final List<TextSpan> feuilles = <TextSpan>[];
  _aplatir(rendu.text as TextSpan, feuilles);
  return feuilles;
}

void _aplatir(TextSpan span, List<TextSpan> sortie) {
  if (span.text != null) sortie.add(span);
  for (final InlineSpan enfant in span.children ?? const <InlineSpan>[]) {
    if (enfant is TextSpan) _aplatir(enfant, sortie);
  }
}
