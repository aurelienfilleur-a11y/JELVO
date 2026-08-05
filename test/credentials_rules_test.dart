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

    test('renvoie un message en français', () {
      expect(CredentialsRules.pseudoError('ab'), contains('au moins 3'));
      expect(CredentialsRules.pseudoError('Camille'), contains('minuscules'));
      expect(CredentialsRules.pseudoError('camille'), isNull);
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
      expect(CredentialsRules.passwordError('court'), contains('8 caractères'));
      expect(
        CredentialsRules.passwordError('motdepasse1'),
        contains('majuscule'),
      );
      expect(CredentialsRules.passwordError('Motdepasse'), contains('chiffre'));
      expect(CredentialsRules.passwordError('Motdepasse1'), isNull);
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
