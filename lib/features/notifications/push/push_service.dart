import 'push_service_stub.dart'
    if (dart.library.js_interop) 'push_service_web.dart';

/// Ce que l'on peut dire de l'état des notifications système.
enum PushStatus {
  /// La plateforme ne sait pas faire — ni navigateur, ni cible compilée pour.
  nonSupporte,

  /// Sur iOS, Web Push n'existe **que** dans une application ajoutée à l'écran
  /// d'accueil. Dans un onglet Safari, l'API n'est même pas exposée.
  installationRequise,

  /// Possible, mais l'autorisation n'a pas encore été demandée.
  aAutoriser,

  /// L'autorisation a été refusée. Elle ne peut plus être redemandée depuis
  /// l'application : seul un réglage du navigateur la rouvre.
  refuse,

  /// Autorisé et abonné.
  actif,
}

/// Un abonnement Web Push, réduit à ce que la base stocke.
class PushSubscriptionData {
  const PushSubscriptionData({
    required this.endpoint,
    required this.p256dh,
    required this.auth,
  });

  /// L'adresse de destination. C'est elle qui part dans `push_tokens.token`.
  final String endpoint;
  final String p256dh;
  final String auth;
}

/// Accès aux notifications système du navigateur.
///
/// L'implémentation réelle est chargée par import conditionnel : sur la
/// machine virtuelle et sur les cibles natives, c'est le talon qui répond
/// `nonSupporte`. Aucun `kIsWeb` disséminé, et rien de `dart:js_interop` ne
/// remonte jusqu'aux écrans.
abstract interface class PushService {
  /// État courant, sans rien demander à l'utilisateur.
  Future<PushStatus> status();

  /// Demande l'autorisation puis s'abonne.
  ///
  /// **À n'appeler que depuis un geste.** Hors d'un clic, les navigateurs
  /// ignorent la demande — et iOS la refuse définitivement.
  Future<PushSubscriptionData?> subscribe();

  /// Abonnement existant, s'il y en a un. Sert à réenregistrer au démarrage :
  /// un abonnement peut être révoqué sans que l'application en soit avertie.
  Future<PushSubscriptionData?> currentSubscription();

  /// Se désabonne côté navigateur. Renvoie l'endpoint retiré, pour que la base
  /// puisse l'oublier aussi.
  Future<String?> unsubscribe();
}

/// Construit le service adapté à la plateforme.
PushService creerServicePush() => creerServicePushImpl();
