/// Règles de validation des identifiants, partagées par l'inscription et la
/// réinitialisation du mot de passe.
///
/// Elles vivent dans le domaine plutôt que dans les écrans pour rester
/// testables sans widget, et pour que les mêmes contraintes s'appliquent
/// partout où un mot de passe est saisi.
abstract final class CredentialsRules {
  static const int pseudoMinLength = 3;
  static const int pseudoMaxLength = 20;
  static const int passwordMinLength = 8;

  /// Minuscules, chiffres et points, entre 3 et 20 caractères.
  static final RegExp _pseudoPattern = RegExp(r'^[a-z0-9.]{3,20}$');

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s]+$');

  /// Message d'erreur du pseudo, ou `null` s'il est valide.
  static String? pseudoError(String value) {
    final String pseudo = value.trim();
    if (pseudo.isEmpty) return 'Choisissez un pseudo.';
    if (pseudo.length < pseudoMinLength) {
      return 'Le pseudo doit contenir au moins $pseudoMinLength caractères.';
    }
    if (pseudo.length > pseudoMaxLength) {
      return 'Le pseudo ne doit pas dépasser $pseudoMaxLength caractères.';
    }
    if (!_pseudoPattern.hasMatch(pseudo)) {
      return 'Uniquement des minuscules, des chiffres et des points.';
    }
    return null;
  }

  static bool isPseudoValid(String value) => pseudoError(value) == null;

  static String? emailError(String value) {
    final String email = value.trim();
    if (email.isEmpty) return 'Renseignez votre adresse e-mail.';
    if (!_emailPattern.hasMatch(email)) {
      return 'Cette adresse e-mail semble incomplète.';
    }
    return null;
  }

  static bool isEmailValid(String value) => emailError(value) == null;

  // Les trois contraintes du mot de passe sont exposées séparément : l'écran
  // d'inscription les affiche sous forme de liste cochée au fil de la saisie.
  static bool hasMinLength(String value) => value.length >= passwordMinLength;

  static bool hasUppercase(String value) => RegExp('[A-Z]').hasMatch(value);

  static bool hasDigit(String value) => RegExp('[0-9]').hasMatch(value);

  static String? passwordError(String value) {
    if (value.isEmpty) return 'Choisissez un mot de passe.';
    if (!hasMinLength(value)) {
      return 'Au moins $passwordMinLength caractères sont nécessaires.';
    }
    if (!hasUppercase(value)) return 'Ajoutez au moins une majuscule.';
    if (!hasDigit(value)) return 'Ajoutez au moins un chiffre.';
    return null;
  }

  static bool isPasswordValid(String value) => passwordError(value) == null;

  /// Vrai si le code de vérification a la forme attendue (six chiffres).
  static bool isCodeComplete(String value) =>
      RegExp(r'^[0-9]{6}$').hasMatch(value);
}
