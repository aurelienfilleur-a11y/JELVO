import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/models/auth_failure.dart';

/// Un type de notification et son réglage.
class NotificationPreference {
  const NotificationPreference({
    required this.type,
    required this.label,
    required this.description,
    required this.enabled,
  });

  factory NotificationPreference.fromRow(Map<String, dynamic> row) =>
      NotificationPreference(
        type: row['type'] as String,
        label: row['libelle'] as String? ?? '',
        description: row['description'] as String? ?? '',
        enabled: row['enabled'] as bool? ?? true,
      );

  final String type;
  final String label;
  final String description;
  final bool enabled;

  NotificationPreference copyWith({bool? enabled}) => NotificationPreference(
    type: type,
    label: label,
    description: description,
    enabled: enabled ?? this.enabled,
  );
}

/// Abonnements et préférences de notification, côté base.
///
/// Les six types viennent de `types_de_notification()` : c'est **elle** qui
/// fait autorité, pas une liste recopiée dans le code. En ajouter un côté SQL
/// le fait apparaître dans les réglages sans toucher à Dart.
abstract interface class PushRepository {
  Future<List<NotificationPreference>> fetchPreferences();

  Future<void> setPreference({required String type, required bool enabled});

  /// Enregistre — ou réenregistre — un abonnement.
  Future<void> registerSubscription({
    required String endpoint,
    required String p256dh,
    required String auth,
  });

  Future<void> forgetSubscription(String endpoint);
}

class SupabasePushRepository implements PushRepository {
  const SupabasePushRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<NotificationPreference>> fetchPreferences() async {
    if (_client.auth.currentUser == null) {
      return const <NotificationPreference>[];
    }
    try {
      final Object? result = await _client.rpc<Object?>(
        'mes_preferences_notification',
      );
      return _rows(result).map(NotificationPreference.fromRow).toList();
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<void> setPreference({
    required String type,
    required bool enabled,
  }) async {
    try {
      await _client.rpc<Object?>(
        'definir_preference_notification',
        params: <String, dynamic>{'p_type': type, 'p_enabled': enabled},
      );
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<void> registerSubscription({
    required String endpoint,
    required String p256dh,
    required String auth,
  }) async {
    try {
      await _client.rpc<Object?>(
        'enregistrer_push',
        params: <String, dynamic>{
          // `token` porte l'endpoint : c'est l'adresse de destination, donc le
          // jeton au sens de cette table.
          'p_token': endpoint,
          'p_platform': 'web',
          'p_p256dh': p256dh,
          'p_auth': auth,
        },
      );
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<void> forgetSubscription(String endpoint) async {
    try {
      await _client.rpc<Object?>(
        'oublier_push',
        params: <String, dynamic>{'p_token': endpoint},
      );
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  static List<Map<String, dynamic>> _rows(Object? result) {
    if (result is List) {
      return result.whereType<Map<String, dynamic>>().toList();
    }
    if (result is Map<String, dynamic>) return <Map<String, dynamic>>[result];
    return const <Map<String, dynamic>>[];
  }
}
