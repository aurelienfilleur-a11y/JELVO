import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/models/auth_failure.dart';
import '../models/availability.dart';

/// Accès aux disponibilités.
///
/// Toutes les écritures passent par des fonctions SQL : `availabilities`
/// pourrait n'avoir aucune politique DELETE, auquel cas un `delete` direct ne
/// toucherait aucune ligne et PostgREST répondrait 200 sans erreur. Voir
/// `supabase/tranche4_disponibilites.sql`.
abstract interface class AvailabilityRepository {
  /// Ses propres créneaux, avec tout le détail.
  Future<List<AvailabilitySlot>> fetchMine();

  /// Crée un créneau, ou modifie celui dont l'identifiant est fourni.
  Future<AvailabilitySlot> save({
    String? id,
    required AvailabilityKind kind,
    required AvailabilityStatus status,
    required int start,
    required int end,
    int? weekday,
    DateTime? onDate,
  });

  Future<bool> remove(String id);

  /// Statut de plusieurs personnes à un instant donné.
  ///
  /// Ne renvoie jamais qu'un mot parmi trois par personne : le détail des
  /// créneaux d'autrui n'est visible de personne.
  Future<Map<String, PeerAvailability>> statusesAt({
    required List<String> userIds,
    required DateTime at,
  });
}

class SupabaseAvailabilityRepository implements AvailabilityRepository {
  const SupabaseAvailabilityRepository(this._client);

  final SupabaseClient _client;

  bool get _signedIn => _client.auth.currentUser != null;

  @override
  Future<List<AvailabilitySlot>> fetchMine() async {
    if (!_signedIn) return const <AvailabilitySlot>[];
    try {
      final Object? result = await _client.rpc<Object?>('mes_disponibilites');
      return _rows(result).map(AvailabilitySlot.fromRow).toList();
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<AvailabilitySlot> save({
    String? id,
    required AvailabilityKind kind,
    required AvailabilityStatus status,
    required int start,
    required int end,
    int? weekday,
    DateTime? onDate,
  }) async {
    try {
      final Object? result = await _client.rpc<Object?>(
        'definir_disponibilite',
        params: <String, dynamic>{
          'p_id': id,
          'p_kind': kind.dbValue,
          'p_status': status.dbValue,
          'p_start': AvailabilitySlot.formaterHeure(start),
          'p_end': AvailabilitySlot.formaterHeure(end),
          // La base borne le jour à 0..6 (`extract(dow)`) : un dimanche écrit
          // en ISO — 7 — casserait sur `availabilities_weekday_check`.
          'p_weekday': AvailabilitySlot.jourBaseDepuisIso(weekday),
          // `date` et non `timestamptz` : envoyer un instant ferait glisser le
          // jour d'un fuseau à l'autre.
          'p_on_date': onDate == null
              ? null
              : '${onDate.year.toString().padLeft(4, '0')}-'
                    '${onDate.month.toString().padLeft(2, '0')}-'
                    '${onDate.day.toString().padLeft(2, '0')}',
        },
      );
      final List<Map<String, dynamic>> rows = _rows(result);
      if (rows.isEmpty) {
        throw const AuthFailure(
          'Le créneau n’a pas pu être enregistré. Réessayez dans un instant.',
        );
      }
      return AvailabilitySlot.fromRow(rows.first);
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<bool> remove(String id) async {
    try {
      final Object? result = await _client.rpc<Object?>(
        'supprimer_disponibilite',
        params: <String, dynamic>{'p_id': id},
      );
      return result == true;
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<Map<String, PeerAvailability>> statusesAt({
    required List<String> userIds,
    required DateTime at,
  }) async {
    if (!_signedIn || userIds.isEmpty) {
      return const <String, PeerAvailability>{};
    }
    try {
      final Object? result = await _client.rpc<Object?>(
        'statuts_de_disponibilite',
        params: <String, dynamic>{
          'p_users': userIds,
          'p_at': at.toUtc().toIso8601String(),
        },
      );
      return <String, PeerAvailability>{
        for (final Map<String, dynamic> row in _rows(result))
          row['user_id'] as String: PeerAvailability.fromDb(
            row['statut'] as String?,
          ),
      };
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
