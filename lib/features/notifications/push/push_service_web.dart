import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import '../../../data/app_config.dart';
import 'push_service.dart';

// Interopérabilité déclarée à la main plutôt qu'en tirant `package:web` : tout
// ce qui suit tient dans `dart:js_interop`, fourni par le SDK, et n'ajoute donc
// aucune dépendance au projet.

@JS('navigator')
external _Navigator get _navigator;

@JS('window')
external _Window get _window;

/// Présent seulement là où Web Push existe. Sur iOS hors écran d'accueil, le
/// symbole est simplement absent — c'est le test le plus direct.
@JS('PushManager')
external JSFunction? get _pushManagerApi;

@JS('Notification')
external _NotificationStatique? get _notificationApi;

extension type _Navigator._(JSObject _) implements JSObject {
  external _ServiceWorkerContainer? get serviceWorker;

  /// Safari iOS d'avant la norme : vrai quand l'application vient de l'écran
  /// d'accueil. Conservé parce qu'il reste le signal le plus fiable là-bas.
  external JSBoolean? get standalone;
}

extension type _Window._(JSObject _) implements JSObject {
  external _MediaQueryList matchMedia(String requete);
}

extension type _MediaQueryList._(JSObject _) implements JSObject {
  external bool get matches;
}

extension type _NotificationStatique._(JSObject _) implements JSObject {
  external String get permission;
  external JSPromise<JSString> requestPermission();
}

extension type _ServiceWorkerContainer._(JSObject _) implements JSObject {
  external JSPromise<_ServiceWorkerRegistration> register(
    String url,
    JSObject options,
  );
  external JSPromise<_ServiceWorkerRegistration> getRegistration(String scope);
}

extension type _ServiceWorkerRegistration._(JSObject _) implements JSObject {
  external _PushManager? get pushManager;
}

extension type _PushManager._(JSObject _) implements JSObject {
  external JSPromise<_PushSubscription?> getSubscription();
  external JSPromise<_PushSubscription> subscribe(JSObject options);
}

extension type _PushSubscription._(JSObject _) implements JSObject {
  external String get endpoint;
  external JSPromise<JSBoolean> unsubscribe();
  external JSObject toJSON();
}

/// Notifications système du navigateur.
///
/// **Portée `push/`** : le service worker de Flutter occupe déjà la portée de
/// base, et deux enregistrements ne peuvent pas la partager. Un abonnement
/// appartient à l'enregistrement et non à la page, donc une portée étroite ne
/// gêne rien.
class PushServiceWeb implements PushService {
  const PushServiceWeb();

  static const String _fichierSw = 'jelvo_push_sw.js';
  static const String _portee = 'push/';

  @override
  Future<PushStatus> status() async {
    if (!_apiDisponible) {
      // **Sur iOS, l'API n'existe pas dans un onglet Safari** — seulement dans
      // une application ajoutée à l'écran d'accueil. Distinguer les deux cas
      // change le conseil à donner : installer, ou changer de navigateur.
      return _peutEtreInstalle
          ? PushStatus.installationRequise
          : PushStatus.nonSupporte;
    }

    switch (_notificationApi!.permission) {
      case 'denied':
        return PushStatus.refuse;
      case 'granted':
        final PushSubscriptionData? abonnement = await currentSubscription();
        return abonnement == null ? PushStatus.aAutoriser : PushStatus.actif;
      default:
        return PushStatus.aAutoriser;
    }
  }

  /// Vrai si tout ce qu'il faut est exposé. Sur iOS hors écran d'accueil,
  /// `PushManager` est simplement absent.
  bool get _apiDisponible =>
      _notificationApi != null &&
      _navigator.serviceWorker != null &&
      _pushManagerApi != null &&
      AppConfig.vapidPublicKey.isNotEmpty;

  /// Vrai si l'on est dans un navigateur qui saurait faire une fois
  /// l'application installée — en pratique, Safari sur iOS.
  bool get _peutEtreInstalle =>
      !_estInstallee && _navigator.serviceWorker != null;

  bool get _estInstallee =>
      _window.matchMedia('(display-mode: standalone)').matches ||
      (_navigator.standalone?.toDart ?? false);

  @override
  Future<PushSubscriptionData?> subscribe() async {
    if (!_apiDisponible) return null;

    // La demande doit venir d'un geste : hors clic, elle est ignorée, et iOS
    // la compte comme un refus définitif. L'appelant s'en charge.
    final String reponse =
        (await _notificationApi!.requestPermission().toDart).toDart;
    if (reponse != 'granted') return null;

    final _ServiceWorkerRegistration enregistrement = await _enregistrer();
    final _PushManager? gestionnaire = enregistrement.pushManager;
    if (gestionnaire == null) return null;

    final _PushSubscription abonnement = await gestionnaire
        .subscribe(
          <String, Object?>{
                // **Obligatoire, et pas seulement par politesse** : un push
                // silencieux fait révoquer l'abonnement après quelques récidives.
                'userVisibleOnly': true,
                'applicationServerKey': _cleServeur(AppConfig.vapidPublicKey),
              }.jsify()!
              as JSObject,
        )
        .toDart;

    return _lire(abonnement);
  }

  @override
  Future<PushSubscriptionData?> currentSubscription() async {
    if (!_apiDisponible) return null;
    final _ServiceWorkerRegistration enregistrement = await _enregistrer();
    final _PushSubscription? abonnement = await enregistrement.pushManager
        ?.getSubscription()
        .toDart;
    return abonnement == null ? null : _lire(abonnement);
  }

  @override
  Future<String?> unsubscribe() async {
    if (!_apiDisponible) return null;
    final _ServiceWorkerRegistration enregistrement = await _enregistrer();
    final _PushSubscription? abonnement = await enregistrement.pushManager
        ?.getSubscription()
        .toDart;
    if (abonnement == null) return null;

    final String endpoint = abonnement.endpoint;
    await abonnement.unsubscribe().toDart;
    return endpoint;
  }

  Future<_ServiceWorkerRegistration> _enregistrer() => _navigator.serviceWorker!
      .register(
        _fichierSw,
        <String, Object?>{'scope': _portee}.jsify()! as JSObject,
      )
      .toDart;

  /// `toJSON()` rend l'endpoint et les deux clés **déjà encodés en base64url**.
  /// Les relire depuis `getKey()` demanderait de convertir des `ArrayBuffer`
  /// pour arriver au même résultat.
  static PushSubscriptionData? _lire(_PushSubscription abonnement) {
    final Object? brut = abonnement.toJSON().dartify();
    if (brut is! Map) return null;

    final Object? cles = brut['keys'];
    if (cles is! Map) return null;

    final String? endpoint = brut['endpoint'] as String?;
    final String? p256dh = cles['p256dh'] as String?;
    final String? auth = cles['auth'] as String?;
    if (endpoint == null || p256dh == null || auth == null) return null;

    return PushSubscriptionData(endpoint: endpoint, p256dh: p256dh, auth: auth);
  }

  /// base64url → octets. La norme accepte aussi une chaîne, mais toutes les
  /// implémentations ne la traitent pas de la même façon : le tableau d'octets
  /// est le seul format que tout le monde lit pareil.
  static JSUint8Array _cleServeur(String base64Url) {
    final String complet = base64Url.padRight(
      base64Url.length + (4 - base64Url.length % 4) % 4,
      '=',
    );
    final Uint8List octets = base64Url_.decode(complet);
    return octets.toJS;
  }
}

/// Alias local : `base64Url` de `dart:convert` accepte le remplissage `=`.
const Base64Codec base64Url_ = base64Url;

PushService creerServicePushImpl() => const PushServiceWeb();
