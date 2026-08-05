import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/models/auth_failure.dart';
import '../models/app_notification.dart';

/// Accès à la boîte de notifications de l'utilisateur.
///
/// L'écriture n'est pas exposée : les lignes sont créées par des déclencheurs
/// `security definer` côté base, la table n'ayant volontairement aucune
/// politique d'insertion. Voir `supabase/notifications.sql`.
abstract interface class NotificationRepository {
  /// Notifications de l'utilisateur, la plus récente en tête.
  Future<List<AppNotification>> fetchNotifications();

  Future<void> markRead(String id);

  Future<void> markAllRead();
}

class SupabaseNotificationRepository implements NotificationRepository {
  const SupabaseNotificationRepository(this._client);

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  @override
  Future<List<AppNotification>> fetchNotifications() async {
    final String? userId = _userId;
    if (userId == null) return const <AppNotification>[];

    try {
      final List<Map<String, dynamic>> rows = await _client
          .from('notifications')
          .select('id, type, payload, read_at, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(100);
      return rows.map(AppNotification.fromRow).toList();
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<void> markRead(String id) async {
    final String? userId = _userId;
    if (userId == null) return;

    try {
      await _client
          .from('notifications')
          .update(<String, dynamic>{
            'read_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id)
          .eq('user_id', userId);
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<void> markAllRead() async {
    final String? userId = _userId;
    if (userId == null) return;

    try {
      await _client
          .from('notifications')
          .update(<String, dynamic>{
            'read_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('user_id', userId)
          .isFilter('read_at', null);
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }
}
