import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/diagnostic_mode.dart';
import '../../../l10n/app_localizations.dart';

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
  const AuthFailure(this.kind, {this.technical});

  /// Repli nommé, pour un appelant qui n'a rien de plus précis à dire.
  const AuthFailure.inconnue({this.technical}) : kind = AuthFailureKind.unknown;

  /// Erreur brute — code et texte du serveur —, conservée en toutes
  /// circonstances mais affichée seulement en mode diagnostic.
  final String? technical;

  final AuthFailureKind kind;

  /// Le message, dans la langue de l'appareil.
  ///
  /// **Il n'est plus stocké, il se déduit du [kind].** Le porter en clair
  /// obligeait à choisir les mots au moment où l'erreur est *fabriquée* —
  /// dans un `catch`, loin de tout `BuildContext` et donc de toute langue.
  /// Le `kind` disait déjà la même chose ; trois valeurs lui ont été ajoutées
  /// pour qu'il la dise entièrement, et l'exhaustivité du `switch` ci-dessous
  /// est ce qui force un message pour toute valeur à venir.
  String message(AppTexts t) {
    final String libelle = switch (kind) {
      AuthFailureKind.invalidCredentials =>
        t.authIdentifiantsIncorrectsVerifiezSaisie,
      AuthFailureKind.emailTaken => t.authAdresseEMailDeja,
      AuthFailureKind.pseudoTaken => t.authPseudoVientEtrePris,
      AuthFailureKind.emailNotConfirmed => t.authAdresseEMailEncore,
      AuthFailureKind.codeInvalid => t.authCodeIncorrectVerifiezSix,
      AuthFailureKind.codeExpired => t.authCodeExpireDemandezNouveau,
      AuthFailureKind.rateLimited => t.authTropTentativesPatientezMinute,
      AuthFailureKind.weakPassword => t.authMotPasseTropFaible,
      AuthFailureKind.samePassword => t.authNouveauMotPasseDoit,
      AuthFailureKind.userNotFound => t.authAucunCompteCorrespondInformations,
      AuthFailureKind.sessionExpired => t.authSessionExpireReconnectez,
      AuthFailureKind.authFailed => t.authConnexionEchoueReessayezInstant,
      AuthFailureKind.network => t.errorNetwork,
      AuthFailureKind.storage => t.authEnvoiPhotoEchoueReessayez,
      AuthFailureKind.forbidden => t.errorForbidden,
      AuthFailureKind.schemaOutdated => t.authFonctionnaliteAttendMiseJour,
      AuthFailureKind.notSaved => t.errorNotSaved,
      AuthFailureKind.pseudoInconnu => t.authConnexionPseudoEncoreDisponible,
      AuthFailureKind.creneauNonEnregistre =>
        t.availabilityCreneauPuEtreEnregistre,
      AuthFailureKind.evenementNonCree => t.calendarEvenementPuEtreCree,
      AuthFailureKind.evenementNonModifie => t.calendarEvenementPuEtreModifie,
      AuthFailureKind.messageNonEnvoye => t.chatMessagePuEtreEnvoye,
      AuthFailureKind.groupeNonCree => t.groupsGroupePuEtreCree,
      AuthFailureKind.tacheNonCreee => t.tasksTachePuEtreCreee,
      AuthFailureKind.tacheNonModifiee => t.tasksTachePuEtreModifiee,
      AuthFailureKind.unknown => t.errorGeneric,
    };
    final String? raw = technical;
    if (!DiagnosticMode.isActive || raw == null) return libelle;
    return t.authMessageDiagnosticRaw(libelle, raw);
  }

  /// Traduit une erreur quelconque remontée par Supabase ou par le réseau.
  factory AuthFailure.from(Object error) {
    if (error is AuthFailure) return error;

    if (DiagnosticMode.isActive) {
      // texte-en-dur-autorise: console de développement, jamais à l'écran.
      debugPrint('[jelvo:diagnostic] ${error.runtimeType} — $error');
    }

    if (_isNetworkError(error)) {
      return AuthFailure(AuthFailureKind.network, technical: _describe(error));
    }

    if (error is AuthException) {
      return _fromAuthException(error)._withTechnical(
        // texte-en-dur-autorise: détail technique, affiché seulement en mode
        // diagnostic et nommant le défaut côté serveur.
        'AuthException code=${error.code} '
        'statusCode=${error.statusCode} — ${error.message}',
      );
    }
    if (error is PostgrestException) return _fromPostgrest(error);
    if (error is StorageException) {
      return AuthFailure(
        AuthFailureKind.storage,
        // texte-en-dur-autorise: détail technique, mode diagnostic.
        technical: 'StorageException ${error.statusCode} — ${error.message}',
      );
    }

    return AuthFailure.inconnue(technical: _describe(error));
  }

  // texte-en-dur-autorise: détail technique, mode diagnostic.
  static String _describe(Object error) => '${error.runtimeType} — $error';

  AuthFailure _withTechnical(String value) =>
      AuthFailure(kind, technical: value);

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
      return AuthFailure(AuthFailureKind.invalidCredentials);
    }
    if (code == 'email_not_confirmed' ||
        message.contains('email not confirmed')) {
      return AuthFailure(AuthFailureKind.emailNotConfirmed);
    }
    if (code == 'user_already_exists' ||
        code == 'email_exists' ||
        message.contains('already registered') ||
        message.contains('already been registered')) {
      return AuthFailure(AuthFailureKind.emailTaken);
    }
    if (code == 'otp_expired' || message.contains('expired')) {
      return AuthFailure(AuthFailureKind.codeExpired);
    }
    if (code == 'otp_disabled' ||
        message.contains('invalid token') ||
        message.contains('token has invalid')) {
      return AuthFailure(AuthFailureKind.codeInvalid);
    }
    if (code == 'over_email_send_rate_limit' ||
        code == 'over_request_rate_limit' ||
        message.contains('rate limit') ||
        message.contains('for security purposes')) {
      return AuthFailure(AuthFailureKind.rateLimited);
    }
    if (code == 'weak_password' || message.contains('password should be')) {
      return AuthFailure(AuthFailureKind.weakPassword);
    }
    if (code == 'same_password' ||
        message.contains('should be different from the old password')) {
      return AuthFailure(AuthFailureKind.samePassword);
    }
    if (code == 'user_not_found' || message.contains('user not found')) {
      return AuthFailure(AuthFailureKind.userNotFound);
    }
    if (code == 'session_expired' || message.contains('session')) {
      return AuthFailure(AuthFailureKind.sessionExpired);
    }

    return const AuthFailure(AuthFailureKind.authFailed);
  }

  static AuthFailure _fromPostgrest(PostgrestException error) {
    // Le détail complet renvoyé par PostgREST : c'est lui qui nomme la
    // contrainte, la colonne ou la politique en cause.
    // texte-en-dur-autorise: détail technique, mode diagnostic.
    final String technical =
        'PostgrestException code=${error.code} '
        'message=${error.message} '
        'details=${error.details} '
        'hint=${error.hint}';

    // 23505 = violation de contrainte d'unicité. Sur `profiles`, seul le
    // pseudo est unique : deux inscriptions simultanées peuvent viser le même,
    // et la vérification de disponibilité en direct ne suffit donc pas.
    if (error.code == '23505') {
      return AuthFailure(AuthFailureKind.pseudoTaken, technical: technical);
    }
    if (error.code == '42501' ||
        error.message.toLowerCase().contains('row-level security')) {
      return AuthFailure(AuthFailureKind.forbidden, technical: technical);
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
      return AuthFailure(AuthFailureKind.schemaOutdated, technical: technical);
    }

    return AuthFailure(AuthFailureKind.notSaved, technical: technical);
  }

  @override
  // texte-en-dur-autorise: représentation de débogage, jamais affichée. Le
  // message n'y entre pas : il a besoin d'une langue, que `toString` n'a pas.
  String toString() => 'AuthFailure($kind): $technical';
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

  /// Le nouveau mot de passe est le même que l'ancien. Distinct de
  /// [weakPassword] : celui-ci n'est pas faible, il est inchangé, et le
  /// message doit le dire.
  samePassword,

  userNotFound,
  sessionExpired,

  /// gotrue a refusé sans rien de reconnaissable. Distinct d'[unknown], qui
  /// couvre tout le reste : ici l'on sait au moins que c'est l'authentification.
  authFailed,

  network,
  storage,
  forbidden,

  /// L'application demande une colonne que la base n'a pas encore : une
  /// migration n'est pas passée. Distinct de `unknown`, dont le message
  /// invite à réessayer — ce qui ne servirait à rien ici.
  schemaOutdated,

  /// L'écriture n'a pas abouti, sans cause reconnue côté PostgREST.
  notSaved,

  // Les cas que les dépôts lèvent eux-mêmes. `AuthFailure` est, de fait, le
  // type d'erreur **affichable** de toute l'application — il vit dans `auth`
  // pour des raisons d'histoire, et chaque dépôt l'importe déjà. Les énumérer
  // ici est le prix d'un message par situation ; le `switch` exhaustif de
  // `message` est ce qui garantit qu'aucune n'en sorte sans mots.

  /// Connexion par pseudo : la fonction SQL `email_pour_pseudo` n'a rien
  /// rendu.
  pseudoInconnu,
  creneauNonEnregistre,
  evenementNonCree,
  evenementNonModifie,
  messageNonEnvoye,
  groupeNonCree,
  tacheNonCreee,
  tacheNonModifiee,

  unknown,
}
