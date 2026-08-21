import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/diagnostic_mode.dart';

/// Échec d'authentification traduit en message affichable.
///
/// Toute la couche d'accès lève cette exception : les écrans n'ont jamais à
/// interpréter un `AuthException`, un code PostgREST ou une `SocketException`,
/// et aucun message technique brut ne peut donc atteindre l'utilisateur.
///
/// Exception à cette règle : `DiagnosticMode.isActive`, qui accole l'erreur
/// brute au message français. Il sert à identifier une erreur serveur qu'on ne
/// peut pas reproduire depuis un poste de développement, n'est jamais actif par
/// défaut, et s'allume par l'URL — `?diag=1` — sans nouvelle livraison.
class AuthFailure implements Exception {
  const AuthFailure(
    this._message, {
    this.kind = AuthFailureKind.unknown,
    this.technical,
  });

  final String _message;

  /// Erreur brute — code et texte du serveur —, conservée en toutes
  /// circonstances mais affichée seulement en mode diagnostic.
  final String? technical;

  final AuthFailureKind kind;

  /// Message en français, destiné à être affiché tel quel.
  String get message {
    final String? raw = technical;
    if (!DiagnosticMode.isActive || raw == null) return _message;
    return '$_message\n\n[diagnostic] $raw';
  }

  /// Traduit une erreur quelconque remontée par Supabase ou par le réseau.
  factory AuthFailure.from(Object error) {
    if (error is AuthFailure) return error;

    if (DiagnosticMode.isActive) {
      debugPrint('[jelvo:diagnostic] ${error.runtimeType} — $error');
    }

    if (_isNetworkError(error)) {
      return AuthFailure(
        'Connexion indisponible. Vérifiez votre accès à Internet, puis '
        'réessayez.',
        kind: AuthFailureKind.network,
        technical: _describe(error),
      );
    }

    if (error is AuthException) {
      return _fromAuthException(error)._withTechnical(
        'AuthException code=${error.code} '
        'statusCode=${error.statusCode} — ${error.message}',
      );
    }
    if (error is PostgrestException) return _fromPostgrest(error);
    if (error is StorageException) {
      return AuthFailure(
        "L'envoi de la photo a échoué. Réessayez dans un instant.",
        kind: AuthFailureKind.storage,
        technical: 'StorageException ${error.statusCode} — ${error.message}',
      );
    }

    return AuthFailure(
      'Une erreur est survenue. Réessayez dans un instant.',
      technical: _describe(error),
    );
  }

  static String _describe(Object error) => '${error.runtimeType} — $error';

  AuthFailure _withTechnical(String value) =>
      AuthFailure(_message, kind: kind, technical: value);

  static bool _isNetworkError(Object error) {
    // `AuthRetryableFetchException` est levée par gotrue quand la requête n'a
    // pas abouti ; les autres cas viennent de `dart:io` ou du client HTTP, dont
    // les types ne sont pas exportés ici — on se rabat sur le nom.
    if (error is SocketException || error is TimeoutException) return true;
    if (error is AuthRetryableFetchException) return true;
    final String name = error.runtimeType.toString();
    return name == 'ClientException' || name == 'HttpException';
  }

  static AuthFailure _fromAuthException(AuthException error) {
    final String code = error.code ?? '';
    final String message = error.message.toLowerCase();

    if (code == 'invalid_credentials' ||
        message.contains('invalid login credentials')) {
      return const AuthFailure(
        'Identifiants incorrects. Vérifiez votre saisie, puis réessayez.',
        kind: AuthFailureKind.invalidCredentials,
      );
    }
    if (code == 'email_not_confirmed' ||
        message.contains('email not confirmed')) {
      return const AuthFailure(
        'Votre adresse e-mail n’est pas encore vérifiée.',
        kind: AuthFailureKind.emailNotConfirmed,
      );
    }
    if (code == 'user_already_exists' ||
        code == 'email_exists' ||
        message.contains('already registered') ||
        message.contains('already been registered')) {
      return const AuthFailure(
        'Cette adresse e-mail est déjà utilisée. Connectez-vous ou choisissez '
        'une autre adresse.',
        kind: AuthFailureKind.emailTaken,
      );
    }
    if (code == 'otp_expired' || message.contains('expired')) {
      return const AuthFailure(
        'Ce code a expiré. Demandez-en un nouveau.',
        kind: AuthFailureKind.codeExpired,
      );
    }
    if (code == 'otp_disabled' ||
        message.contains('invalid token') ||
        message.contains('token has invalid')) {
      return const AuthFailure(
        'Code incorrect. Vérifiez les six chiffres reçus par e-mail.',
        kind: AuthFailureKind.codeInvalid,
      );
    }
    if (code == 'over_email_send_rate_limit' ||
        code == 'over_request_rate_limit' ||
        message.contains('rate limit') ||
        message.contains('for security purposes')) {
      return const AuthFailure(
        'Trop de tentatives. Patientez une minute avant de réessayer.',
        kind: AuthFailureKind.rateLimited,
      );
    }
    if (code == 'weak_password' || message.contains('password should be')) {
      return const AuthFailure(
        'Ce mot de passe est trop faible. Choisissez-en un plus robuste.',
        kind: AuthFailureKind.weakPassword,
      );
    }
    if (code == 'same_password' ||
        message.contains('should be different from the old password')) {
      return const AuthFailure(
        'Le nouveau mot de passe doit différer de l’ancien.',
        kind: AuthFailureKind.weakPassword,
      );
    }
    if (code == 'user_not_found' || message.contains('user not found')) {
      return const AuthFailure(
        'Aucun compte ne correspond à ces informations.',
        kind: AuthFailureKind.userNotFound,
      );
    }
    if (code == 'session_expired' || message.contains('session')) {
      return const AuthFailure(
        'Votre session a expiré. Reconnectez-vous.',
        kind: AuthFailureKind.sessionExpired,
      );
    }

    return const AuthFailure(
      'La connexion a échoué. Réessayez dans un instant.',
    );
  }

  static AuthFailure _fromPostgrest(PostgrestException error) {
    // Le détail complet renvoyé par PostgREST : c'est lui qui nomme la
    // contrainte, la colonne ou la politique en cause.
    final String technical =
        'PostgrestException code=${error.code} '
        'message=${error.message} '
        'details=${error.details} '
        'hint=${error.hint}';

    // 23505 = violation de contrainte d'unicité. Sur `profiles`, seul le
    // pseudo est unique : deux inscriptions simultanées peuvent viser le même,
    // et la vérification de disponibilité en direct ne suffit donc pas.
    if (error.code == '23505') {
      return AuthFailure(
        'Ce pseudo vient d’être pris. Choisissez-en un autre.',
        kind: AuthFailureKind.pseudoTaken,
        technical: technical,
      );
    }
    if (error.code == '42501' ||
        error.message.toLowerCase().contains('row-level security')) {
      return AuthFailure(
        'Vous n’avez pas les droits nécessaires pour cette action.',
        kind: AuthFailureKind.forbidden,
        technical: technical,
      );
    }
    // Colonne inconnue : l'application demande un champ que la base n'a pas.
    //
    // **Ce n'est pas une panne passagère**, et « réessayez dans un instant »
    // envoie chercher le défaut du mauvais côté — c'est arrivé sur
    // `profiles.avatar_preset`, dont la migration n'était jamais passée parce
    // que le job s'était arrêté à la connexion. PostgREST répond `PGRST204`
    // quand son cache de schéma ignore la colonne, PostgreSQL `42703` quand
    // elle n'existe pas du tout.
    if (error.code == 'PGRST204' ||
        error.code == '42703' ||
        error.message.toLowerCase().contains('schema cache')) {
      return AuthFailure(
        'Cette fonctionnalité attend une mise à jour de la base. '
        'Réessayez plus tard, ou signalez-le si cela persiste.',
        kind: AuthFailureKind.schemaOutdated,
        technical: technical,
      );
    }

    return AuthFailure(
      'Les données n’ont pas pu être enregistrées. Réessayez dans un instant.',
      technical: technical,
    );
  }

  @override
  String toString() => 'AuthFailure($kind): $message';
}

enum AuthFailureKind {
  invalidCredentials,
  emailTaken,
  pseudoTaken,
  emailNotConfirmed,
  codeInvalid,
  codeExpired,
  rateLimited,
  weakPassword,
  userNotFound,
  sessionExpired,
  network,
  storage,
  forbidden,

  /// L'application demande une colonne que la base n'a pas encore : une
  /// migration n'est pas passée. Distinct de `unknown`, dont le message
  /// invite à réessayer — ce qui ne servirait à rien ici.
  schemaOutdated,

  unknown,
}
