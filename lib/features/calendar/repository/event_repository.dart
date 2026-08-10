import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/models/auth_failure.dart';
import '../models/calendar_event.dart';

/// Accès à l'agenda : événements de groupe et rendez-vous personnels.
///
/// Comme pour les tâches, les écritures passent par des fonctions SQL :
/// `events` n'a pas de politique DELETE et `event_participants` non plus.
abstract interface class EventRepository {
  /// Événements visibles, éventuellement bornés dans le temps ou restreints à
  /// un groupe.
  Future<List<CalendarEvent>> fetchEvents({
    DateTime? from,
    DateTime? to,
    String? groupId,
  });

  Future<CalendarEvent> createEvent({
    required String title,
    required DateTime startsAt,
    DateTime? endsAt,
    String? groupId,
    String? description,
    String? location,
    String? rrule,
    String? imageUrl,
    int? reminderMinutes,
    List<String>? participants,
  });

  /// Remplace tous les champs modifiables. Réservé au propriétaire et aux
  /// admins du groupe : déplacer une date engage tous les participants.
  Future<CalendarEvent> updateEvent({
    required String eventId,
    required String title,
    required DateTime startsAt,
    DateTime? endsAt,
    String? description,
    String? location,
    String? rrule,
    String? imageUrl,
    int? reminderMinutes,
  });

  Future<void> respond({
    required String eventId,
    required EventResponse response,
  });

  Future<void> deleteEvent(String eventId);
}

class SupabaseEventRepository implements EventRepository {
  const SupabaseEventRepository(this._client);

  final SupabaseClient _client;

  bool get _signedIn => _client.auth.currentUser != null;

  @override
  Future<List<CalendarEvent>> fetchEvents({
    DateTime? from,
    DateTime? to,
    String? groupId,
  }) async {
    if (!_signedIn) return const <CalendarEvent>[];
    try {
      final Object? result = await _client.rpc<Object?>(
        'mon_agenda',
        params: <String, dynamic>{
          'p_debut': from?.toUtc().toIso8601String(),
          'p_fin': to?.toUtc().toIso8601String(),
          'p_group_id': groupId,
        },
      );
      return _rows(result).map(CalendarEvent.fromRow).toList();
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<CalendarEvent> createEvent({
    required String title,
    required DateTime startsAt,
    DateTime? endsAt,
    String? groupId,
    String? description,
    String? location,
    String? rrule,
    String? imageUrl,
    int? reminderMinutes,
    List<String>? participants,
  }) async {
    try {
      final Object? result = await _client.rpc<Object?>(
        'creer_evenement',
        params: <String, dynamic>{
          'p_title': title,
          'p_starts_at': startsAt.toUtc().toIso8601String(),
          'p_ends_at': endsAt?.toUtc().toIso8601String(),
          'p_group_id': groupId,
          'p_description': description,
          'p_location': location,
          'p_rrule': rrule,
          'p_image_url': imageUrl,
          'p_reminder_minutes': reminderMinutes,
          'p_participants': participants,
        },
      );
      final List<Map<String, dynamic>> rows = _rows(result);
      if (rows.isEmpty) {
        throw const AuthFailure(
          'L’événement n’a pas pu être créé. Réessayez dans un instant.',
        );
      }
      return CalendarEvent.fromRow(rows.first);
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<CalendarEvent> updateEvent({
    required String eventId,
    required String title,
    required DateTime startsAt,
    DateTime? endsAt,
    String? description,
    String? location,
    String? rrule,
    String? imageUrl,
    int? reminderMinutes,
  }) async {
    try {
      final Object? result = await _client.rpc<Object?>(
        'modifier_evenement',
        params: <String, dynamic>{
          'p_event_id': eventId,
          'p_title': title,
          'p_starts_at': startsAt.toUtc().toIso8601String(),
          'p_ends_at': endsAt?.toUtc().toIso8601String(),
          'p_description': description,
          'p_location': location,
          'p_rrule': rrule,
          'p_image_url': imageUrl,
          'p_reminder_minutes': reminderMinutes,
        },
      );
      final List<Map<String, dynamic>> rows = _rows(result);
      if (rows.isEmpty) {
        throw const AuthFailure(
          'L’événement n’a pas pu être modifié. Réessayez dans un instant.',
        );
      }
      return CalendarEvent.fromRow(rows.first);
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<void> respond({
    required String eventId,
    required EventResponse response,
  }) async {
    try {
      await _client.rpc<Object?>(
        'repondre_evenement',
        params: <String, dynamic>{
          'p_event_id': eventId,
          'p_reponse': response.dbValue,
        },
      );
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    try {
      await _client.rpc<Object?>(
        'supprimer_evenement',
        params: <String, dynamic>{'p_event_id': eventId},
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
