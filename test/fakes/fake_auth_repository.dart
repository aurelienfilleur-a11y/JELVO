import 'dart:async';
import 'dart:typed_data';

import 'package:jelvo/features/auth/models/auth_failure.dart';
import 'package:jelvo/features/auth/repository/auth_repository.dart';
import 'package:jelvo/features/profile/models/profile.dart';
import 'package:jelvo/features/profile/repository/profile_repository.dart';

/// Dépôt d'authentification en mémoire, pour les tests de widget.
///
/// Évite d'appeler `Supabase.initialize` et de toucher au réseau : les écrans
/// et la garde de navigation sont exercés tels quels.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this._signedIn = false,
    this.pseudosTaken = const <String>{},
    this.signUpOutcome = SignUpOutcome.codeSent,
  });

  /// Réglage de confirmation d'e-mail simulé côté projet Supabase.
  final SignUpOutcome signUpOutcome;

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  bool _signedIn;

  /// Pseudos considérés comme déjà pris.
  final Set<String> pseudosTaken;

  /// Dernier appel reçu, pour les assertions.
  String? lastSignInIdentifier;
  String? lastSignUpEmail;
  String? lastVerifiedCode;
  int resendCount = 0;
  bool completeSignUpCalled = false;

  /// Erreur à lever au prochain appel de [signIn].
  AuthFailure? signInFailure;

  @override
  bool get isSignedIn => _signedIn;

  @override
  String? get currentUserId => _signedIn ? 'utilisateur-test' : null;

  @override
  String? get currentEmail => _signedIn ? 'camille@example.com' : null;

  @override
  Stream<bool> watchSignedIn() => _controller.stream;

  void setSignedIn(bool value) {
    _signedIn = value;
    _controller.add(value);
  }

  @override
  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    lastSignInIdentifier = identifier;
    final AuthFailure? failure = signInFailure;
    if (failure != null) throw failure;
    setSignedIn(true);
  }

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    required String pseudo,
    required String firstName,
    required String lastName,
  }) async {
    lastSignUpEmail = email;
    if (signUpOutcome == SignUpOutcome.sessionOpened) setSignedIn(true);
    return signUpOutcome;
  }

  @override
  Future<void> verifySignUpCode({
    required String email,
    required String code,
  }) async {
    lastVerifiedCode = code;
    if (code != '123456') {
      throw const AuthFailure(
        'Code incorrect. Vérifiez les six chiffres reçus par e-mail.',
        kind: AuthFailureKind.codeInvalid,
      );
    }
    setSignedIn(true);
  }

  @override
  Future<void> resendSignUpCode(String email) async => resendCount++;

  @override
  Future<void> sendPasswordResetCode(String email) async {}

  @override
  Future<void> verifyPasswordResetCode({
    required String email,
    required String code,
  }) async => setSignedIn(true);

  @override
  Future<void> updatePassword(String password) async {}

  @override
  Future<PseudoAvailability> checkPseudoAvailability(String pseudo) async {
    return pseudosTaken.contains(pseudo)
        ? PseudoAvailability.taken
        : PseudoAvailability.available;
  }

  @override
  Future<void> completeSignUp({
    required String pseudo,
    required String firstName,
    required String lastName,
    Uint8List? avatarBytes,
    String? avatarFileExtension,
  }) async => completeSignUpCalled = true;

  @override
  Future<void> signOut() async => setSignedIn(false);

  void dispose() => _controller.close();
}

/// Dépôt de profil en mémoire.
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({Profile? profile})
    : _profile =
          profile ??
          const Profile(
            id: 'utilisateur-test',
            pseudo: 'camille.rousseau',
            firstName: 'Camille',
            lastName: 'Rousseau',
            bio: 'Toujours partante pour une rando.',
          );

  Profile _profile;

  @override
  Future<Profile?> fetchProfile(String userId) async => _profile;

  @override
  Future<Profile> updateProfile({
    required String userId,
    required String firstName,
    required String lastName,
    required String bio,
  }) async {
    _profile = _profile.copyWith(
      firstName: firstName,
      lastName: lastName,
      bio: bio,
    );
    return _profile;
  }

  /// Dernier avatar prédéfini demandé, pour les assertions.
  String? lastChosenAvatar;

  @override
  Future<Profile> updateAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    // Une photo efface l'avatar prédéfini, comme en base : le faux dépôt
    // doit tenir la même règle, sans quoi un test passerait là où la
    // production afficherait encore l'ancien avatar.
    _profile = _remplacerAvatar(
      url: 'https://example.test/avatar.jpg',
      preset: null,
    );
    return _profile;
  }

  @override
  Future<Profile> choisirAvatarPredefini({
    required String userId,
    required String avatarId,
  }) async {
    lastChosenAvatar = avatarId;
    _profile = _remplacerAvatar(url: null, preset: avatarId);
    return _profile;
  }

  @override
  Future<Profile> effacerAvatar(String userId) async {
    _profile = _remplacerAvatar(url: null, preset: null);
    return _profile;
  }

  /// `copyWith` ne sait pas remettre un champ à `null` : on reconstruit.
  Profile _remplacerAvatar({required String? url, required String? preset}) =>
      Profile(
        id: _profile.id,
        pseudo: _profile.pseudo,
        firstName: _profile.firstName,
        lastName: _profile.lastName,
        avatarUrl: url,
        avatarPreset: preset,
        bio: _profile.bio,
        timezone: _profile.timezone,
        createdAt: _profile.createdAt,
        lastSeenAt: _profile.lastSeenAt,
      );
}
