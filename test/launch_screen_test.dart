import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelvo/core/core.dart';
import 'package:jelvo/data/theme_storage.dart';

/// L'écran de lancement et la couleur du bandeau vivent dans
/// `web/index.html`, et il n'y a pas d'autre endroit où ils puissent vivre :
/// ils doivent être justes **avant** que Flutter démarre.
///
/// La contrepartie est que la page recopie trois choses que le Dart connaît
/// aussi — la clé de stockage, les trois mots d'apparence, et deux teintes de
/// la palette. Aucune de ces recopies ne proteste quand elle devient fausse :
/// le démarrage retomberait simplement sur « suivre le téléphone », et le
/// clignotement reviendrait sans que rien ne le dise. D'où ce fichier.
void main() {
  late String page;

  setUpAll(() {
    page = File('web/index.html').readAsStringSync();
  });

  /// `#RRGGBB` en majuscules, comme l'écrit la page.
  String hexa(Color couleur) =>
      '#${(couleur.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  group("Le contrat entre la page et l'application", () {
    test('la page lit la clé de stockage de ThemeStorage', () {
      expect(ThemeStorage.cle, 'jelvo-apparence');
      expect(
        page,
        contains("localStorage.getItem('${ThemeStorage.cle}')"),
        reason:
            'la page doit lire la clé que ThemeStorage écrit, sans quoi le '
            'réglage est ignoré au démarrage',
      );
    });

    test('la page connaît les trois mots que ThemeStorage écrit', () {
      // Partir de `ThemeMode` plutôt que d'une liste recopiée : une valeur
      // ajoutée à l'énumération doit faire échouer ce test, pas passer
      // inaperçue.
      for (final ThemeMode mode in ThemeMode.values) {
        expect(
          page,
          contains("'${ThemeStorage.jeton(mode)}'"),
          reason:
              'la page doit savoir quoi faire du mot ${ThemeStorage.jeton(mode)}',
        );
      }
    });

    test('les deux fonds de la page sont ceux de la palette', () {
      expect(page, contains(hexa(JelvoColors.clair.background)));
      expect(page, contains(hexa(JelvoColors.sombre.background)));
    });

    test("le violet de la marque n'est plus la couleur du bandeau", () {
      // Le bandeau continue l'écran : il prend `background`, pas `primary`.
      // Le violet y figurait, et c'est ce qui le rendait faux dans les deux
      // apparences.
      expect(page, isNot(contains(hexa(JelvoColors.clair.primary))));
    });
  });

  group("L'écran de lancement", () {
    test('la page porte le voile et le logo fourni', () {
      expect(page, contains('id="jelvo-amorce"'));
      expect(page, contains('icons/Icon-192.png'));
      expect(
        File('web/icons/Icon-192.png').existsSync(),
        isTrue,
        reason: 'le logo de l’écran de lancement doit exister au dépôt',
      );
    });

    test(
      "il s'efface sur la première image de Flutter, et non sur une minuterie",
      () {
        expect(
          page,
          contains("addEventListener('flutter-first-frame'"),
          reason:
              'le relais se fait sur le signal, la minuterie n’est qu’un filet',
        );
      },
    );

    test('il est retiré de la page, pas seulement rendu transparent', () {
      // Laissé en place, un voile transparent avalerait les touches.
      expect(page, contains('removeChild(amorce)'));
    });
  });

  group('Le bandeau de la barre d’état', () {
    test('il suit le téléphone par requête de média, sans script', () {
      expect(
        page,
        contains('media="(prefers-color-scheme: dark)"'),
        reason:
            'le mode Automatique doit suivre le réglage du téléphone même '
            'après le démarrage, ce qu’une couleur figée ne fait pas',
      );
    });

    test('iOS installé a sa propre déclaration, réglable', () {
      // `theme-color` n'est pas lu par l'application ajoutée à l'écran
      // d'accueil : sans cette ligne, le bandeau y reste blanc.
      expect(page, contains('apple-mobile-web-app-status-bar-style'));
      expect(page, contains('id="jelvo-bandeau-ios"'));
      expect(page, contains("'black'"));
    });
  });
}
