import 'package:supabase_flutter/supabase_flutter.dart';

import 'session_persistence.dart';

/// Se souvient que l'écran de bienvenue a été vu.
///
/// **Ce drapeau ne peut pas vivre en base.** L'écran s'affiche *avant* toute
/// authentification, à quelqu'un qui n'a pas encore de compte : il n'existe
/// aucune ligne `profiles` où l'écrire, et rien à lire au démarrage. C'est donc
/// une mémoire d'appareil, et elle l'est doublement à raison — une application
/// installée sur l'écran d'accueil a son propre stockage, et y remontrer la
/// présentation une fois est le comportement juste.
///
/// La brique est celle de [SessionPersistence] : un `LocalStorage` de gotrue
/// détourné en booléen — `persistSession` pose le marqueur, `hasAccessToken`
/// le relit. L'usage est détourné, mais il évite une dépendance de plus pour
/// un seul `bool`, et c'est déjà le choix qu'a fait « Se souvenir de moi ».
class OnboardingStorage {
  OnboardingStorage({LocalStorage? drapeau})
    : _drapeau =
          drapeau ??
          SharedPreferencesLocalStorage(
            persistSessionKey: 'jelvo-bienvenue-vue',
          );

  final LocalStorage _drapeau;

  bool _dejaVu = false;

  /// Vrai si l'écran de bienvenue a déjà été montré.
  ///
  /// **Faux par défaut** : c'est la présence du marqueur qui dit « vu », et une
  /// installation neuve n'en a aucun.
  bool get dejaVu => _dejaVu;

  /// À appeler dans `main()`, **avant `runApp`**.
  ///
  /// La redirection du routeur lit ce drapeau de façon synchrone, pour la même
  /// raison qu'`authStatusProvider` : une redirection ne peut pas attendre un
  /// `AsyncValue`.
  Future<void> initialize() async {
    await _drapeau.initialize();
    _dejaVu = await _drapeau.hasAccessToken();
  }

  Future<void> marquerVu() async {
    if (_dejaVu) return;
    _dejaVu = true;
    await _drapeau.persistSession('1');
  }
}

/// Stockage qui ne retient rien : en test comme dans un harnais où `main()`
/// n'a pas tourné, marquer l'écran vu ne doit ni échouer ni toucher au
/// stockage réel.
///
/// [dejaVu] permet de partir de l'un ou l'autre état sans passer par un
/// `initialize()` asynchrone — une installation neuve, ou quelqu'un qui a déjà
/// vu la présentation.
class EphemeralOnboardingStorage extends OnboardingStorage {
  EphemeralOnboardingStorage({bool dejaVu = false})
    : super(drapeau: const EphemeralSessionStorage()) {
    _dejaVu = dejaVu;
  }
}
