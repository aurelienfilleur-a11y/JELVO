import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'clock.dart';

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
