import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/app_config.dart';
import '../models/auth_failure.dart';
import '../models/credentials_rules.dart';

/// Disponibilité d'un pseudo, telle qu'affichée pendant la saisie.
enum PseudoAvailability { available, taken, unknown }

/// Ce que l'inscription a réellement produit côté serveur.
///
/// La confirmation d'adresse e-mail est un réglage du projet Supabase, pas du
/// code : lorsqu'elle est désactivée, `signUp` ouvre immédiatement une session
/// et n'envoie aucun code. Le parcours se règle donc sur la réponse du serveur
/// plutôt que sur une constante de compilation — réactiver la confirmation dans
/// Supabase suffit à faire réapparaître l'écran de saisie du code, sans
/// toucher à l'application.
enum SignUpOutcome {
  /// Une session est ouverte : l'inscription peut se terminer tout de suite.
  sessionOpened,

  /// Un code à six chiffres a été envoyé : il reste à le vérifier.
  codeSent,
}

/// Accès à l'authentification et au compte.
///
/// L'interface est séparée de l'implémentation Supabase pour que les tests de
/// widget puissent surcharger `authRepositoryProvider` sans réseau ni appel à
/// `Supabase.initialize`.
abstract interface class AuthRepository {
  /// Vrai si une session est ouverte.
  ///
  /// Exposé comme un booléen plutôt qu'une `Session` : c'est tout ce dont la
  /// garde de navigation a besoin, et cela rend le dépôt simple à simuler.
  bool get isSignedIn;

  /// Identifiant de l'utilisateur connecté, ou `null`.
  String? get currentUserId;

  /// Adresse e-mail de l'utilisateur connecté, ou `null`.
  String? get currentEmail;

  /// Flux des changements d'état d'authentification (connexion, déconnexion,
  /// rafraîchissement du jeton, restauration de session au démarrage).
  Stream<bool> watchSignedIn();

  /// Connexion par pseudo **ou** adresse e-mail.
  Future<void> signIn({required String identifier, required String password});

  /// Crée le compte.
  ///
  /// Renvoie [SignUpOutcome.codeSent] si Supabase attend la vérification de
  /// l'adresse — aucune session n'est alors ouverte et la ligne `profiles` ne
  /// peut être créée qu'après [verifySignUpCode]. Renvoie
  /// [SignUpOutcome.sessionOpened] si la confirmation est désactivée sur le
  /// projet : la session existe déjà et [completeSignUp] peut suivre
  /// directement.
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    required String pseudo,
    required String firstName,
    required String lastName,
  });

  /// Vérifie le code à six chiffres reçu après une inscription.
  Future<void> verifySignUpCode({required String email, required String code});

  /// Renvoie un code de vérification d'inscription.
  Future<void> resendSignUpCode(String email);

  /// Envoie un code de réinitialisation de mot de passe.
  Future<void> sendPasswordResetCode(String email);

  /// Vérifie le code de réinitialisation et ouvre une session temporaire
  /// permettant de choisir un nouveau mot de passe.
  Future<void> verifyPasswordResetCode({
    required String email,
    required String code,
  });

  /// Remplace le mot de passe de l'utilisateur connecté.
  Future<void> updatePassword(String password);

  /// Vrai si le pseudo n'est pas déjà porté par un autre compte.
  Future<PseudoAvailability> checkPseudoAvailability(String pseudo);

  /// Crée la ligne `profiles` et téléverse la photo, une fois la session
  /// ouverte. Idempotent : rejouer l'appel met simplement le profil à jour.
  Future<void> completeSignUp({
    required String pseudo,
    required String firstName,
    required String lastName,
    Uint8List? avatarBytes,
    String? avatarFileExtension,
  });

  Future<void> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  @override
  bool get isSignedIn => _auth.currentSession != null;

  @override
  String? get currentUserId => _auth.currentUser?.id;

  @override
  String? get currentEmail => _auth.currentUser?.email;

  @override
  Stream<bool> watchSignedIn() =>
      _auth.onAuthStateChange.map((AuthState state) => state.session != null);

  @override
  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    final String trimmed = identifier.trim();
    final String email = CredentialsRules.isEmailValid(trimmed)
        ? trimmed
        : await _emailForPseudo(trimmed.toLowerCase());

    try {
      await _auth.signInWithPassword(email: email, password: password);
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  /// Résout un pseudo en adresse e-mail via la fonction SQL `email_pour_pseudo`.
  ///
  /// `profiles` ne contient pas l'adresse e-mail — elle vit dans `auth.users`,
  /// hors de portée du client. La résolution demande donc une fonction
  /// `security definer` côté base ; voir `supabase/email_pour_pseudo.sql`.
  Future<String> _emailForPseudo(String pseudo) async {
    try {
      final Object? result = await _client.rpc<Object?>(
        'email_pour_pseudo',
        params: <String, dynamic>{'pseudo_recherche': pseudo},
      );
      final String? email = result is String ? result : null;
      if (email == null || email.isEmpty) {
        throw const AuthFailure(
          'Identifiants incorrects. Vérifiez votre saisie, puis réessayez.',
          kind: AuthFailureKind.invalidCredentials,
        );
      }
      return email;
    } on PostgrestException catch (error) {
      // PGRST202 : la fonction n'est pas déployée sur ce projet.
      if (error.code == 'PGRST202' || error.code == '404') {
        throw const AuthFailure(
          'La connexion par pseudo n’est pas encore disponible. Utilisez '
          'votre adresse e-mail.',
          kind: AuthFailureKind.invalidCredentials,
        );
      }
      throw AuthFailure.from(error);
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    required String pseudo,
    required String firstName,
    required String lastName,
  }) async {
    try {
      final AuthResponse response = await _auth.signUp(
        email: email.trim(),
        password: password,
        // Ces métadonnées permettent à un éventuel trigger `handle_new_user`
        // de créer le profil ; `completeSignUp` reste la source de vérité.
        data: <String, dynamic>{
          'pseudo': pseudo,
          'first_name': firstName,
          'last_name': lastName,
        },
      );
      // Une session dans la réponse signifie que la confirmation d'e-mail est
      // désactivée sur le projet : il n'y a pas de code à attendre.
      return response.session == null
          ? SignUpOutcome.codeSent
          : SignUpOutcome.sessionOpened;
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<void> verifySignUpCode({
    required String email,
    required String code,
  }) async {
    try {
      await _auth.verifyOTP(
        email: email.trim(),
        token: code,
        type: OtpType.signup,
      );
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<void> resendSignUpCode(String email) async {
    try {
      await _auth.resend(type: OtpType.signup, email: email.trim());
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<void> sendPasswordResetCode(String email) async {
    try {
      await _auth.resetPasswordForEmail(email.trim());
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<void> verifyPasswordResetCode({
    required String email,
    required String code,
  }) async {
    try {
      await _auth.verifyOTP(
        email: email.trim(),
        token: code,
        type: OtpType.recovery,
      );
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<void> updatePassword(String password) async {
    try {
      await _auth.updateUser(UserAttributes(password: password));
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<PseudoAvailability> checkPseudoAvailability(String pseudo) async {
    try {
      final Map<String, dynamic>? row = await _client
          .from('profiles')
          .select('id')
          .eq('pseudo', pseudo.toLowerCase())
          .maybeSingle();
      return row == null
          ? PseudoAvailability.available
          : PseudoAvailability.taken;
    } catch (_) {
      // Un pseudo « indéterminé » n'empêche pas de continuer : la contrainte
      // d'unicité tranchera à l'insertion.
      return PseudoAvailability.unknown;
    }
  }

  @override
  Future<void> completeSignUp({
    required String pseudo,
    required String firstName,
    required String lastName,
    Uint8List? avatarBytes,
    String? avatarFileExtension,
  }) async {
    final String? userId = currentUserId;
    if (userId == null) {
      throw const AuthFailure(
        'Votre session a expiré. Reconnectez-vous.',
        kind: AuthFailureKind.sessionExpired,
      );
    }

    String? avatarUrl;
    if (avatarBytes != null) {
      avatarUrl = await uploadAvatar(
        userId: userId,
        bytes: avatarBytes,
        fileExtension: avatarFileExtension ?? 'jpg',
      );
    }

    try {
      await _client.from('profiles').upsert(<String, dynamic>{
        'id': userId,
        'pseudo': pseudo.toLowerCase(),
        'first_name': firstName,
        'last_name': lastName,
        'avatar_url': ?avatarUrl,
      });
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  /// Téléverse la photo dans le bucket `avatars` et renvoie son URL publique.
  ///
  /// Le chemin est préfixé par l'identifiant utilisateur : les politiques du
  /// bucket s'appuient habituellement sur ce premier segment.
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final String path =
        '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
    try {
      await _client.storage
          .from(AppConfig.avatarsBucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: _contentTypeFor(fileExtension),
            ),
          );
      return _client.storage.from(AppConfig.avatarsBucket).getPublicUrl(path);
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  static String _contentTypeFor(String extension) =>
      switch (extension.toLowerCase()) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        'heic' => 'image/heic',
        _ => 'image/jpeg',
      };

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }
}
