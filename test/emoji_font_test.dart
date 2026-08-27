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
    for (final TextStyle style in <TextStyle>[
      AppTypography.h1,
      AppTypography.h2,
      AppTypography.h3,
      AppTypography.body,
      AppTypography.bodyMuted,
      AppTypography.caption,
      AppTypography.button,
    ]) {
      expect(style.fontFamilyFallback, contains('NotoColorEmoji'));
    }
  });

  test('le thème complet le porte aussi', () {
    // `textTheme` est ce que lisent les widgets Material qui ne passent pas
    // par `AppTypography` directement.
    final TextTheme theme = AppTypography.textTheme;
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
}
