import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jelvo/data/app_config.dart';

/// `AppConfig.version` est recopiée de `pubspec.yaml` à la main : lire le
/// pubspec à l'exécution demanderait `package_info_plus`, une dépendance de
/// plus pour une chaîne.
///
/// Ce test est la contrepartie de ce choix. Sans lui, l'écran « À propos »
/// finirait par annoncer une version qui n'est plus la bonne — et une version
/// fausse est pire qu'une version absente.
void main() {
  test('la version affichée est celle du pubspec', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    final RegExpMatch? ligne = RegExp(
      r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(ligne, isNotNull, reason: 'pubspec.yaml doit porter une version');
    expect(AppConfig.version, ligne!.group(1));
  });
}
