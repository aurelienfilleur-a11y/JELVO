import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/supabase_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/app_notification.dart';
import '../repository/notification_repository.dart';

/// Dépôt des notifications. Surchargé dans les tests par un faux dépôt.
final Provider<NotificationRepository> notificationRepositoryProvider =
    Provider<NotificationRepository>(
      (Ref ref) =>
          SupabaseNotificationRepository(ref.watch(supabaseClientProvider)),
    );

/// Boîte de notifications de l'utilisateur connecté.
final AsyncNotifierProvider<NotificationsNotifier, List<AppNotification>>
notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, List<AppNotification>>(
      NotificationsNotifier.new,
    );

class NotificationsNotifier extends AsyncNotifier<List<AppNotification>> {
  @override
  Future<List<AppNotification>> build() {
    ref.watch(authStatusProvider);
    return ref.watch(notificationRepositoryProvider).fetchNotifications();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(notificationRepositoryProvider).fetchNotifications(),
    );
  }
}

List<AppNotification> _all(Ref ref) =>
    ref.watch(notificationsProvider).value ?? const <AppNotification>[];

/// Notifications non lues.
final Provider<List<AppNotification>> unreadNotificationsProvider =
    Provider<List<AppNotification>>(
      (Ref ref) => _all(ref).where((AppNotification n) => n.isUnread).toList(),
    );

/// Nombre total de notifications non lues, pour la cloche de l'accueil.
final Provider<int> unreadCountProvider = Provider<int>(
  (Ref ref) => ref.watch(unreadNotificationsProvider).length,
);

/// Compteurs de non-lus par onglet de la barre inférieure.
///
/// Chaque type de notification appartient à un onglet et à un seul
/// (`NotificationType.navIndex`) : un même élément n'est donc jamais compté
/// deux fois, et le total de la cloche reste la somme des pastilles.
final Provider<List<int>> unreadByTabProvider = Provider<List<int>>((Ref ref) {
  final List<int> counts = <int>[0, 0, 0, 0];
  for (final AppNotification notification in ref.watch(
    unreadNotificationsProvider,
  )) {
    counts[notification.type.navIndex]++;
  }
  return counts;
});

/// Écritures sur la boîte de notifications.
final Provider<NotificationActions> notificationActionsProvider =
    Provider<NotificationActions>(NotificationActions.new);

class NotificationActions {
  const NotificationActions(this._ref);

  final Ref _ref;

  Future<void> markRead(String id) async {
    await _ref.read(notificationRepositoryProvider).markRead(id);
    await _refresh();
  }

  Future<void> markAllRead() async {
    await _ref.read(notificationRepositoryProvider).markAllRead();
    await _refresh();
  }

  Future<void> _refresh() =>
      _ref.read(notificationsProvider.notifier).refresh();
}
