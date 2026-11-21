import 'package:flutter_test/flutter_test.dart';
import 'package:jelvo/features/auth/models/credentials_rules.dart';

void main() {
  group('pseudo', () {
    test('accepte minuscules, chiffres et points', () {
      expect(CredentialsRules.isPseudoValid('camille.rousseau'), isTrue);
      expect(CredentialsRules.isPseudoValid('yanis2'), isTrue);
      expect(CredentialsRules.isPseudoValid('abc'), isTrue);
    });

    test('refuse les majuscules et les caractères interdits', () {
      expect(CredentialsRules.isPseudoValid('Camille'), isFalse);
      expect(CredentialsRules.isPseudoValid('camille rousseau'), isFalse);
      expect(CredentialsRules.isPseudoValid('camille_rousseau'), isFalse);
      expect(CredentialsRules.isPseudoValid('camille@'), isFalse);
    });

    test('impose une longueur de 3 à 20 caractères', () {
      expect(CredentialsRules.isPseudoValid('ab'), isFalse);
      expect(CredentialsRules.isPseudoValid('a' * 21), isFalse);
      expect(CredentialsRules.isPseudoValid('a' * 20), isTrue);
    });

    // **Le problème, pas la phrase.** Affirmer `contains('au moins 3')`
    // reviendrait à figer le français dans un test qui doit survivre aux
    // quatre langues ; la mise en mots est éprouvée là où elle se fait, dans
    // les écrans.
    test('nomme ce qui ne va pas', () {
      expect(CredentialsRules.pseudoProbleme('ab'), PseudoProbleme.tropCourt);
      expect(
        CredentialsRules.pseudoProbleme('Camille'),
        PseudoProbleme.caracteresInterdits,
      );
      expect(CredentialsRules.pseudoProbleme(''), PseudoProbleme.vide);
      expect(
        CredentialsRules.pseudoProbleme('a' * 21),
        PseudoProbleme.tropLong,
      );
      expect(CredentialsRules.pseudoProbleme('camille'), isNull);
    });
  });

  group('mot de passe', () {
    test('exige 8 caractères, une majuscule et un chiffre', () {
      expect(CredentialsRules.isPasswordValid('Motdepasse1'), isTrue);
      expect(CredentialsRules.isPasswordValid('Court1'), isFalse);
      expect(CredentialsRules.isPasswordValid('motdepasse1'), isFalse);
      expect(CredentialsRules.isPasswordValid('Motdepasse'), isFalse);
    });

    test('signale la contrainte manquante', () {
      expect(
        CredentialsRules.motDePasseProbleme('court'),
        MotDePasseProbleme.tropCourt,
      );
      expect(
        CredentialsRules.motDePasseProbleme('motdepasse1'),
        MotDePasseProbleme.sansMajuscule,
      );
      expect(
        CredentialsRules.motDePasseProbleme('Motdepasse'),
        MotDePasseProbleme.sansChiffre,
      );
      expect(CredentialsRules.motDePasseProbleme(''), MotDePasseProbleme.vide);
      expect(CredentialsRules.motDePasseProbleme('Motdepasse1'), isNull);
    });
  });

  group('email', () {
    test('accepte une adresse plausible et refuse le reste', () {
      expect(CredentialsRules.isEmailValid('camille@example.com'), isTrue);
      expect(CredentialsRules.isEmailValid('camille@example'), isFalse);
      expect(CredentialsRules.isEmailValid('camille'), isFalse);
      expect(CredentialsRules.isEmailValid('cam ille@example.com'), isFalse);
    });
  });

  group('code de vérification', () {
    test('exige exactement six chiffres', () {
      expect(CredentialsRules.isCodeComplete('123456'), isTrue);
      expect(CredentialsRules.isCodeComplete('12345'), isFalse);
      expect(CredentialsRules.isCodeComplete('1234567'), isFalse);
      expect(CredentialsRules.isCodeComplete('12345a'), isFalse);
    });
  });
}
