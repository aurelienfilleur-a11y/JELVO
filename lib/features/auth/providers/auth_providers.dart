import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/supabase_providers.dart';
import '../models/credentials_rules.dart';
import '../repository/auth_repository.dart';

/// Dépôt d'authentification. Surchargé dans les tests par un faux dépôt.
final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>(
      (Ref ref) => SupabaseAuthRepository(ref.watch(supabaseClientProvider)),
    );

/// État d'authentification connu de l'application.
///
/// Deux états suffisent : `Supabase.initialize` est attendu dans `main()` et a
/// donc déjà restauré la session persistée au premier build.
enum AuthStatus { signedOut, signedIn }

/// Statut courant, alimenté par le flux du dépôt.
///
/// Un `Notifier` plutôt qu'un `StreamProvider` : la garde de navigation de
/// GoRouter doit lire l'état de façon synchrone, sans passer par un
/// `AsyncValue`.
final NotifierProvider<AuthStatusNotifier, AuthStatus> authStatusProvider =
    NotifierProvider<AuthStatusNotifier, AuthStatus>(AuthStatusNotifier.new);

class AuthStatusNotifier extends Notifier<AuthStatus> {
  StreamSubscription<bool>? _subscription;

  @override
  AuthStatus build() {
    final AuthRepository repository = ref.watch(authRepositoryProvider);

    _subscription = repository.watchSignedIn().listen((bool signedIn) {
      state = signedIn ? AuthStatus.signedIn : AuthStatus.signedOut;
    });
    ref.onDispose(() => _subscription?.cancel());

    return repository.isSignedIn ? AuthStatus.signedIn : AuthStatus.signedOut;
  }
}

/// Identifiant de l'utilisateur connecté, ou `null`.
final Provider<String?> currentUserIdProvider = Provider<String?>((Ref ref) {
  ref.watch(authStatusProvider);
  return ref.watch(authRepositoryProvider).currentUserId;
});

/// Adresse e-mail de l'utilisateur connecté, ou `null`.
final Provider<String?> currentEmailProvider = Provider<String?>((Ref ref) {
  ref.watch(authStatusProvider);
  return ref.watch(authRepositoryProvider).currentEmail;
});

/// `Listenable` reliant Riverpod à `GoRouter.refreshListenable`.
///
/// GoRouter ne sait pas observer un provider : ce pont lui signale chaque
/// changement de statut pour qu'il rejoue sa redirection.
final Provider<AuthRefreshNotifier> authRefreshProvider =
    Provider<AuthRefreshNotifier>((Ref ref) {
      final AuthRefreshNotifier notifier = AuthRefreshNotifier();
      ref.listen<AuthStatus>(
        authStatusProvider,
        (_, _) => notifier.notify(),
        fireImmediately: false,
      );
      ref.onDispose(notifier.dispose);
      return notifier;
    });

class AuthRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// Vérification de disponibilité d'un pseudo, en direct pendant la saisie.
///
/// Le débounce évite une requête à chaque frappe ; `keepAlive` n'est pas
/// souhaitable ici, un pseudo libre pouvant être pris entre-temps.
final pseudoAvailabilityProvider = FutureProvider.autoDispose
    .family<PseudoAvailability, String>((Ref ref, String pseudo) async {
      if (!CredentialsRules.isPseudoValid(pseudo)) {
        return PseudoAvailability.unknown;
      }

      await Future<void>.delayed(const Duration(milliseconds: 400));
      // Après le débounce, la frappe suivante a pu invalider ce provider.
      if (!ref.mounted) return PseudoAvailability.unknown;

      return ref.read(authRepositoryProvider).checkPseudoAvailability(pseudo);
    });
