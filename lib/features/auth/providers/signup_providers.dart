import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Saisie d'inscription en cours, partagée entre les étapes.
///
/// L'état vit dans un provider plutôt que dans le `State` des écrans : les
/// étapes sont des routes distinctes, et un retour arrière ne doit pas perdre
/// ce qui a déjà été renseigné.
@immutable
class SignUpDraft {
  const SignUpDraft({
    this.pseudo = '',
    this.email = '',
    this.password = '',
    this.firstName = '',
    this.lastName = '',
    this.avatarBytes,
    this.avatarExtension,
  });

  final String pseudo;
  final String email;
  final String password;
  final String firstName;
  final String lastName;

  /// Photo choisie mais pas encore téléversée : l'envoi n'a lieu qu'une fois
  /// l'adresse vérifiée, quand une session existe pour satisfaire les
  /// politiques du bucket.
  final Uint8List? avatarBytes;
  final String? avatarExtension;

  bool get hasAvatar => avatarBytes != null;

  SignUpDraft copyWith({
    String? pseudo,
    String? email,
    String? password,
    String? firstName,
    String? lastName,
    Uint8List? avatarBytes,
    String? avatarExtension,
    bool clearAvatar = false,
  }) {
    return SignUpDraft(
      pseudo: pseudo ?? this.pseudo,
      email: email ?? this.email,
      password: password ?? this.password,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      avatarBytes: clearAvatar ? null : (avatarBytes ?? this.avatarBytes),
      avatarExtension: clearAvatar
          ? null
          : (avatarExtension ?? this.avatarExtension),
    );
  }
}

final NotifierProvider<SignUpDraftNotifier, SignUpDraft> signUpDraftProvider =
    NotifierProvider<SignUpDraftNotifier, SignUpDraft>(SignUpDraftNotifier.new);

class SignUpDraftNotifier extends Notifier<SignUpDraft> {
  @override
  SignUpDraft build() => const SignUpDraft();

  void setCredentials({
    required String pseudo,
    required String email,
    required String password,
  }) {
    state = state.copyWith(
      pseudo: pseudo.trim().toLowerCase(),
      email: email.trim(),
      password: password,
    );
  }

  void setIdentity({required String firstName, required String lastName}) {
    state = state.copyWith(
      firstName: firstName.trim(),
      lastName: lastName.trim(),
    );
  }

  void setAvatar(Uint8List bytes, String extension) {
    state = state.copyWith(avatarBytes: bytes, avatarExtension: extension);
  }

  void removeAvatar() => state = state.copyWith(clearAvatar: true);

  void reset() => state = const SignUpDraft();
}
