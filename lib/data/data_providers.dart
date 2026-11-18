import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'clock.dart';
import 'onboarding_storage.dart';
import 'theme_storage.dart';
import 'session_persistence.dart';

/// Vrai si l'on tourne dans un navigateur.
///
/// Passer par un provider plutôt que par `kIsWeb` directement rend le cas web
/// **éprouvable** : les tests de widget s'exécutent sur la machine virtuelle,
/// où `kIsWeb` vaut faux, et une consigne réservée au web y serait donc
/// invisible — donc jamais vérifiée.
final Provider<bool> estSurLeWebProvider = Provider<bool>((Ref ref) => kIsWeb);

/// Réglage « Se souvenir de moi », posé par `main()`.
///
/// La valeur par défaut n'écrit rien nulle part : en test comme dans un
/// harnais où `main()` n'a pas tourné, régler la case ne doit ni échouer ni
/// toucher au stockage réel.
final Provider<SessionPersistence> sessionPersistenceProvider =
    Provider<SessionPersistence>(
      (Ref ref) => SessionPersistence(
        session: const EphemeralSessionStorage(),
        drapeau: const EphemeralSessionStorage(),
      ),
    );

/// Mémoire de l'écran de bienvenue.
///
/// Surchargé dans `main()` par l'instance déjà chargée : la redirection le lit
/// de façon synchrone dès le premier `build`.
final Provider<OnboardingStorage> onboardingStorageProvider =
    Provider<OnboardingStorage>((Ref ref) => EphemeralOnboardingStorage());

/// Mémoire de l'apparence choisie, et le choix lui-même.
///
/// Surchargé dans `main()` par l'instance déjà chargée : `MaterialApp` lit le
/// mode dès le premier `build`, et l'ignorer ferait s'ouvrir l'application en
/// clair avant de basculer.
final Provider<ThemeStorage> themeStorageProvider = Provider<ThemeStorage>(
  (Ref ref) => EphemeralThemeStorage(),
);

/// L'apparence courante — c'est ce que lit `MaterialApp.themeMode`.
///
/// Un `Notifier` et non un simple provider : le réglage se change en cours de
/// route, et changer `ThemeData` est ce qui reconstruit les écrans.
final NotifierProvider<ThemeModeNotifier, ThemeMode> themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.watch(themeStorageProvider).mode;

  /// L'état change **avant** l'écriture : l'écran suit le doigt, et un
  /// stockage lent ne doit pas retarder l'apparence.
  Future<void> choisir(ThemeMode mode) async {
    if (state == mode) return;
    state = mode;
    await ref.read(themeStorageProvider).enregistrer(mode);
  }
}

/// Horloge de l'application.
///
/// À surcharger dans les tests :
/// ```dart
/// ProviderScope(
///   overrides: [clockProvider.overrideWithValue(FixedClock(date))],
///   child: const JelvoApp(),
/// );
/// ```
final Provider<Clock> clockProvider = Provider<Clock>(
  (Ref ref) => const SystemClock(),
);

/// Date et heure courantes, dérivées de [clockProvider].
///
/// Ce provider n'est pas auto-rafraîchi : invalidez-le (`ref.invalidate`) pour
/// forcer un recalcul, par exemple au retour au premier plan.
final Provider<DateTime> nowProvider = Provider<DateTime>(
  (Ref ref) => ref.watch(clockProvider).now(),
);
