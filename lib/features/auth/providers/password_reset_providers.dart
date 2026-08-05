import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Adresse ciblée par la réinitialisation en cours.
///
/// Partagée entre l'écran « mot de passe oublié » et celui de saisie du
/// nouveau mot de passe, qui sont deux routes distinctes.
final NotifierProvider<PasswordResetEmail, String> passwordResetEmailProvider =
    NotifierProvider<PasswordResetEmail, String>(PasswordResetEmail.new);

class PasswordResetEmail extends Notifier<String> {
  @override
  String build() => '';

  void set(String email) => state = email.trim();

  void clear() => state = '';
}
