import '../../../l10n/app_localizations.dart';

/// Règles de validation des identifiants, partagées par l'inscription et la
/// réinitialisation du mot de passe.
///
/// Elles vivent dans le domaine plutôt que dans les écrans pour rester
/// testables sans widget, et pour que les mêmes contraintes s'appliquent
/// partout où un mot de passe est saisi.
///
/// **Les conditions sont pures, les mots ne le sont pas**, et les deux sont
/// désormais séparés. Une règle de validation ne connaît pas la langue de
/// l'appareil : elle dit *ce qui ne va pas* — un [PseudoProbleme], un
/// [MotDePasseProbleme] —, et c'est l'écran qui le met en phrase. C'est la
/// même règle que pour les couleurs, et elle a un bénéfice immédiat :
/// `test/credentials_rules_test.dart` éprouve les conditions **sans aucun
/// `AppTexts`**, là où un message en dur l'aurait obligé à en fabriquer un.
abstract final class CredentialsRules {
  static const int pseudoMinLength = 3;
  static const int pseudoMaxLength = 20;
  static const int passwordMinLength = 8;

  /// Minuscules, chiffres et points, entre 3 et 20 caractères.
  static final RegExp _pseudoPattern = RegExp(r'^[a-z0-9.]{3,20}$');

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s]+$');

  /// Ce qui ne va pas avec le pseudo, ou `null` s'il est valide.
  static PseudoProbleme? pseudoProbleme(String value) {
    final String pseudo = value.trim();
    if (pseudo.isEmpty) return PseudoProbleme.vide;
    if (pseudo.length < pseudoMinLength) return PseudoProbleme.tropCourt;
    if (pseudo.length > pseudoMaxLength) return PseudoProbleme.tropLong;
    if (!_pseudoPattern.hasMatch(pseudo)) {
      return PseudoProbleme.caracteresInterdits;
    }
    return null;
  }

  /// Message d'erreur du pseudo, ou `null` s'il est valide.
  static String? pseudoError(String value, AppTexts t) =>
      switch (pseudoProbleme(value)) {
        null => null,
        PseudoProbleme.vide => t.authChoisissezPseudo,
        PseudoProbleme.tropCourt => t.authPseudoDoitContenirMoins(
          pseudoMinLength,
        ),
        PseudoProbleme.tropLong => t.authPseudoDoitDepasserPseudoMaxLength(
          pseudoMaxLength,
        ),
        PseudoProbleme.caracteresInterdits =>
          t.authUniquementMinusculesChiffresPoints,
      };

  static bool isPseudoValid(String value) => pseudoProbleme(value) == null;

  /// Ce qui ne va pas avec l'adresse, ou `null` si elle est valide.
  static EmailProbleme? emailProbleme(String value) {
    final String email = value.trim();
    if (email.isEmpty) return EmailProbleme.vide;
    if (!_emailPattern.hasMatch(email)) return EmailProbleme.malFormee;
    return null;
  }

  static String? emailError(String value, AppTexts t) =>
      switch (emailProbleme(value)) {
        null => null,
        EmailProbleme.vide => t.authRenseignezAdresseEMail,
        EmailProbleme.malFormee => t.authAdresseEMailSemble,
      };

  static bool isEmailValid(String value) => emailProbleme(value) == null;

  // Les trois contraintes du mot de passe sont exposées séparément : l'écran
  // d'inscription les affiche sous forme de liste cochée au fil de la saisie.
  static bool hasMinLength(String value) => value.length >= passwordMinLength;

  static bool hasUppercase(String value) => RegExp('[A-Z]').hasMatch(value);

  static bool hasDigit(String value) => RegExp('[0-9]').hasMatch(value);

  /// Ce qui manque au mot de passe, ou `null` s'il est valide.
  static MotDePasseProbleme? motDePasseProbleme(String value) {
    if (value.isEmpty) return MotDePasseProbleme.vide;
    if (!hasMinLength(value)) return MotDePasseProbleme.tropCourt;
    if (!hasUppercase(value)) return MotDePasseProbleme.sansMajuscule;
    if (!hasDigit(value)) return MotDePasseProbleme.sansChiffre;
    return null;
  }

  static String? passwordError(String value, AppTexts t) =>
      switch (motDePasseProbleme(value)) {
        null => null,
        MotDePasseProbleme.vide => t.authChoisissezMotPasse,
        MotDePasseProbleme.tropCourt =>
          t.authMoinsPasswordMinLengthCaracteresNecessaires(passwordMinLength),
        MotDePasseProbleme.sansMajuscule => t.authAjoutezMoinsMajuscule,
        MotDePasseProbleme.sansChiffre => t.authAjoutezMoinsChiffre,
      };

  static bool isPasswordValid(String value) =>
      motDePasseProbleme(value) == null;

  /// Vrai si le code de vérification a la forme attendue (six chiffres).
  static bool isCodeComplete(String value) =>
      RegExp(r'^[0-9]{6}$').hasMatch(value);
}

enum PseudoProbleme { vide, tropCourt, tropLong, caracteresInterdits }

enum EmailProbleme { vide, malFormee }

enum MotDePasseProbleme { vide, tropCourt, sansMajuscule, sansChiffre }
