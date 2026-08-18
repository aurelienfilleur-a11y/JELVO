import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';

/// Stockage qui ne stocke rien, pour les tests et les harnais.
///
/// `EmptyLocalStorage` de `supabase_flutter` fait déjà cela, mais il n'est pas
/// `const` : on en garde un ici pour pouvoir écrire un provider par défaut
/// sans instancier à chaque lecture.
class EphemeralSessionStorage extends LocalStorage {
  const EphemeralSessionStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async => false;

  @override
  Future<String?> accessToken() async => null;

  @override
  Future<void> removePersistedSession() async {}

  @override
  Future<void> persistSession(String persistSessionString) async {}
}

/// Décide si la session survit à la fermeture de l'application.
///
/// C'est un [LocalStorage] au sens de `supabase_flutter` : c'est lui que
/// gotrue interroge au démarrage pour restaurer une session, et qu'il appelle
/// à chaque rafraîchissement de jeton pour l'écrire.
///
/// **Cochée, la case ne change rien** : on délègue au stockage habituel.
/// Décochée, on n'écrit rien — la session ne vit alors qu'en mémoire, dans le
/// client, et disparaît avec le processus. Ce n'est pas une déconnexion
/// différée qu'on programmerait : il n'y a simplement rien à retrouver.
///
/// **Le drapeau, lui, est persistant.** Il faut le connaître *avant* que la
/// session soit restaurée, donc dès `initialize()`, et il doit survivre à la
/// fermeture pour que le choix tienne d'un lancement à l'autre. Il passe par
/// une seconde instance du même stockage plutôt que par une nouvelle
/// dépendance : `persistSession` y écrit un marqueur, `hasAccessToken` le
/// relit. L'usage est détourné, la brique est la bonne.
class SessionPersistence extends LocalStorage {
  SessionPersistence({LocalStorage? session, LocalStorage? drapeau})
    : _session =
          session ??
          SharedPreferencesLocalStorage(
            persistSessionKey: cleDeSessionParDefaut(),
          ),
      _drapeau =
          drapeau ??
          SharedPreferencesLocalStorage(
            persistSessionKey: 'jelvo-session-ephemere',
          );

  /// Clé de session par défaut de `supabase_flutter`, reconstituée **à
  /// l'identique** : en choisir une autre ferait perdre les sessions déjà
  /// enregistrées par les versions précédentes, et déconnecterait tout le
  /// monde à la mise à jour. Le format vient de `Supabase.initialize`.
  static String cleDeSessionParDefaut() =>
      'sb-${Uri.parse(AppConfig.supabaseUrl).host.split('.').first}-auth-token';

  final LocalStorage _session;
  final LocalStorage _drapeau;

  bool _seSouvenir = true;

  /// Vrai si la session doit survivre à la fermeture. **Coché par défaut**,
  /// et c'est l'absence de marqueur qui le dit : ne rien avoir choisi revient
  /// à choisir le comportement habituel.
  bool get seSouvenir => _seSouvenir;

  @override
  Future<void> initialize() async {
    await _drapeau.initialize();
    await _session.initialize();
    _seSouvenir = !(await _drapeau.hasAccessToken());
  }

  /// À appeler **avant** la connexion : gotrue écrit la session dans la
  /// foulée, et le drapeau doit déjà être à jour quand il le fait.
  Future<void> definir({required bool seSouvenir}) async {
    _seSouvenir = seSouvenir;
    if (seSouvenir) {
      await _drapeau.removePersistedSession();
    } else {
      await _drapeau.persistSession('1');
      // Une session déjà écrite lors d'une connexion précédente survivrait
      // sinon au décochage, ce qui donnerait exactement l'impression que la
      // case ne fonctionne pas.
      await _session.removePersistedSession();
    }
  }

  @override
  Future<bool> hasAccessToken() =>
      _seSouvenir ? _session.hasAccessToken() : Future<bool>.value(false);

  @override
  Future<String?> accessToken() =>
      _seSouvenir ? _session.accessToken() : Future<String?>.value();

  @override
  Future<void> persistSession(String persistSessionString) => _seSouvenir
      ? _session.persistSession(persistSessionString)
      : Future<void>.value();

  /// La suppression n'est **jamais** conditionnelle : se déconnecter doit
  /// effacer, quel que soit le réglage.
  @override
  Future<void> removePersistedSession() => _session.removePersistedSession();
}
