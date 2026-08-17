import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'clock.dart';
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
