import 'package:flutter_test/flutter_test.dart';
import 'package:jelvo/data/diagnostic_mode.dart';

/// Le mode diagnostic doit pouvoir s'allumer **sans nouvelle livraison** :
/// c'est un paramètre d'URL, pas un drapeau de compilation. Ces tests fixent
/// les deux formes d'URL acceptées, parce que la stratégie de Flutter web
/// place les routes après le `#` et qu'une seule des deux survit à la
/// navigation.
void main() {
  setUp(() => DiagnosticMode.definirPourTest(actif: false));
  tearDown(() => DiagnosticMode.definirPourTest(actif: false));

  test('le paramètre placé avant le # active le mode', () {
    DiagnosticMode.lireDepuisUrl(
      Uri.parse('https://exemple.test/JELVO/?diag=1#/groupes/g1'),
    );

    expect(DiagnosticMode.isActive, isTrue);
  });

  test('le paramètre collé à la route l’active aussi', () {
    DiagnosticMode.lireDepuisUrl(
      Uri.parse('https://exemple.test/JELVO/#/groupes/g1?diag=1'),
    );

    expect(DiagnosticMode.isActive, isTrue);
  });

  test('« ?diag » nu suffit', () {
    DiagnosticMode.lireDepuisUrl(Uri.parse('https://exemple.test/JELVO/?diag'));

    expect(DiagnosticMode.isActive, isTrue);
  });

  test('une valeur explicitement fausse éteint le mode', () {
    DiagnosticMode.definirPourTest(actif: true);

    DiagnosticMode.lireDepuisUrl(
      Uri.parse('https://exemple.test/JELVO/?diag=0#/'),
    );

    expect(DiagnosticMode.isActive, isFalse);
  });

  test('sans paramètre, la valeur de compilation est conservée', () {
    // Absent n'est pas faux : sans cette distinction, une URL ordinaire
    // écraserait un `--dart-define=JELVO_DIAGNOSTIC=true` volontaire.
    DiagnosticMode.definirPourTest(actif: true);

    DiagnosticMode.lireDepuisUrl(
      Uri.parse('https://exemple.test/JELVO/#/calendrier'),
    );

    expect(DiagnosticMode.isActive, isTrue);
  });

  test('une URL de fichier — mobile — ne change rien', () {
    DiagnosticMode.lireDepuisUrl(Uri.parse('file:///data/user/0/com.jelvo/'));

    expect(DiagnosticMode.isActive, isFalse);
  });
}
