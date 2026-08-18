import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/supabase_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../push/push_service.dart';
import '../repository/push_repository.dart';

/// Accès au navigateur. Surchargé dans les tests.
final Provider<PushService> pushServiceProvider = Provider<PushService>(
  (Ref ref) => creerServicePush(),
);

/// Accès à la base. Surchargé dans les tests.
final Provider<PushRepository> pushRepositoryProvider =
    Provider<PushRepository>(
      (Ref ref) => SupabasePushRepository(ref.watch(supabaseClientProvider)),
    );

/// État des notifications système, pour l'écran de réglages.
final AsyncNotifierProvider<PushStatusNotifier, PushStatus> pushStatusProvider =
    AsyncNotifierProvider<PushStatusNotifier, PushStatus>(
      PushStatusNotifier.new,
    );

class PushStatusNotifier extends AsyncNotifier<PushStatus> {
  @override
  Future<PushStatus> build() {
    ref.watch(authStatusProvider);
    return ref.watch(pushServiceProvider).status();
  }

  /// Demande l'autorisation, s'abonne, et enregistre l'abonnement.
  ///
  /// **À n'appeler que depuis un geste** : hors d'un clic, la demande est
  /// ignorée par le navigateur, et iOS la compte comme un refus définitif.
  Future<PushStatus> autoriser() async {
    state = const AsyncLoading<PushStatus>();
    state = await AsyncValue.guard(() async {
      final PushSubscriptionData? abonnement = await ref
          .read(pushServiceProvider)
          .subscribe();

      if (abonnement != null) {
        await ref
            .read(pushRepositoryProvider)
            .registerSubscription(
              endpoint: abonnement.endpoint,
              p256dh: abonnement.p256dh,
              auth: abonnement.auth,
            );
      }
      return ref.read(pushServiceProvider).status();
    });
    return state.value ?? PushStatus.aAutoriser;
  }

  /// Se désabonne des deux côtés. L'ordre compte peu, mais oublier la base
  /// laisserait la file pousser vers un endpoint mort à chaque passage.
  Future<void> desactiver() async {
    state = await AsyncValue.guard(() async {
      final String? endpoint = await ref
          .read(pushServiceProvider)
          .unsubscribe();
      if (endpoint != null) {
        await ref.read(pushRepositoryProvider).forgetSubscription(endpoint);
      }
      return ref.read(pushServiceProvider).status();
    });
  }

  /// Réenregistre l'abonnement courant s'il existe.
  ///
  /// Un abonnement peut être révoqué sans que l'application en soit avertie —
  /// c'est le cas **courant** sur iOS, où retirer l'icône de l'écran d'accueil
  /// le détruit. On réenregistre donc au démarrage plutôt que de faire
  /// confiance à ce que la base contient.
  Future<void> reenregistrer() async {
    final PushSubscriptionData? abonnement = await ref
        .read(pushServiceProvider)
        .currentSubscription();
    if (abonnement == null) return;
    await ref
        .read(pushRepositoryProvider)
        .registerSubscription(
          endpoint: abonnement.endpoint,
          p256dh: abonnement.p256dh,
          auth: abonnement.auth,
        );
  }
}

/// Les six types et leur réglage.
final AsyncNotifierProvider<
  NotificationPreferencesNotifier,
  List<NotificationPreference>
>
notificationPreferencesProvider =
    AsyncNotifierProvider<
      NotificationPreferencesNotifier,
      List<NotificationPreference>
    >(NotificationPreferencesNotifier.new);

class NotificationPreferencesNotifier
    extends AsyncNotifier<List<NotificationPreference>> {
  @override
  Future<List<NotificationPreference>> build() {
    ref.watch(authStatusProvider);
    return ref.watch(pushRepositoryProvider).fetchPreferences();
  }

  /// Bascule un type. L'interrupteur bouge **avant** l'aller-retour : un
  /// réglage qui met une seconde à réagir donne l'impression de ne pas
  /// fonctionner. En cas d'échec, il revient et l'erreur remonte.
  Future<void> basculer(String type, {required bool enabled}) async {
    final List<NotificationPreference> avant =
        state.value ?? const <NotificationPreference>[];

    state = AsyncData<List<NotificationPreference>>(<NotificationPreference>[
      for (final NotificationPreference p in avant)
        p.type == type ? p.copyWith(enabled: enabled) : p,
    ]);

    try {
      await ref
          .read(pushRepositoryProvider)
          .setPreference(type: type, enabled: enabled);
    } catch (_) {
      state = AsyncData<List<NotificationPreference>>(avant);
      rethrow;
    }
  }
}

/// Réenregistre l'abonnement à chaque ouverture de session.
///
/// Un abonnement Web Push meurt sans prévenir : retirer l'icône de l'écran
/// d'accueil sur iOS le détruit, et personne n'en informe la base. Faire
/// confiance à ce qu'elle contient, ce serait pousser indéfiniment vers un
/// endpoint mort. On repose donc l'abonnement courant à chaque démarrage —
/// `enregistrer_push` est idempotent.
final FutureProvider<void> pushRegistrationProvider = FutureProvider<void>((
  Ref ref,
) async {
  if (ref.watch(authStatusProvider) != AuthStatus.signedIn) return;
  await ref.read(pushStatusProvider.notifier).reenregistrer();
});
