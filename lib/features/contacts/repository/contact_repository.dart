import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/models/auth_failure.dart';
import '../models/contact.dart';

/// Résultat d'une demande de mise en relation.
enum ContactRequestOutcome {
  envoyee,
  dejaContact,
  dejaDemandee,
  soiMeme;

  String get message => switch (this) {
    ContactRequestOutcome.envoyee => 'Demande envoyée.',
    ContactRequestOutcome.dejaContact =>
      'Cette personne fait déjà partie de vos contacts.',
    ContactRequestOutcome.dejaDemandee => 'Une demande est déjà en attente.',
    ContactRequestOutcome.soiMeme =>
      'Vous ne pouvez pas vous ajouter vous-même.',
  };
}

/// Accès au carnet de contacts.
abstract interface class ContactRepository {
  /// Relations de l'utilisateur, acceptées comme en attente.
  Future<List<Contact>> fetchContacts();

  /// Recherche de profils par début de pseudo, à partir de deux caractères.
  Future<List<ProfileSummary>> searchByPseudo(String term);

  Future<ContactRequestOutcome> sendRequest(String userId);

  Future<void> acceptRequest(String userId);

  /// Refuse une demande reçue : la ligne est supprimée, faute de valeur
  /// « refusé » dans le type `contact_status`.
  Future<void> declineRequest(String userId);

  Future<void> removeContact(String userId);

  Future<void> setFavorite({
    required String userId,
    required ContactDirection direction,
    required bool value,
  });
}

class SupabaseContactRepository implements ContactRepository {
  const SupabaseContactRepository(this._client);

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  @override
  Future<List<Contact>> fetchContacts() async {
    if (_userId == null) return const <Contact>[];
    try {
      final Object? result = await _client.rpc<Object?>('mes_contacts');
      final List<Contact> contacts = _asRows(
        result,
      ).map(Contact.fromRow).toList();

      contacts.sort((Contact a, Contact b) {
        // Favoris épinglés en tête, puis ordre alphabétique.
        if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
        return a.sortKey.compareTo(b.sortKey);
      });
      return contacts;
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<List<ProfileSummary>> searchByPseudo(String term) async {
    final String trimmed = term.trim().toLowerCase();
    if (trimmed.length < 2) return const <ProfileSummary>[];

    try {
      final Object? result = await _client.rpc<Object?>(
        'chercher_profils_par_pseudo',
        params: <String, dynamic>{'terme': trimmed},
      );
      return _asRows(result).map(ProfileSummary.fromRow).toList();
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<ContactRequestOutcome> sendRequest(String userId) async {
    final String? me = _userId;
    if (me == null) {
      throw const AuthFailure(
        'Votre session a expiré. Reconnectez-vous.',
        kind: AuthFailureKind.sessionExpired,
      );
    }
    if (me == userId) return ContactRequestOutcome.soiMeme;

    try {
      // La relation peut déjà exister dans un sens comme dans l'autre.
      final List<Map<String, dynamic>> existing = await _client
          .from('contacts')
          .select('status, requester_id')
          .or(
            'and(requester_id.eq.$me,addressee_id.eq.$userId),'
            'and(requester_id.eq.$userId,addressee_id.eq.$me)',
          );

      if (existing.isNotEmpty) {
        return existing.first['status'] == 'accepted'
            ? ContactRequestOutcome.dejaContact
            : ContactRequestOutcome.dejaDemandee;
      }

      await _client.from('contacts').insert(<String, dynamic>{
        'requester_id': me,
        'addressee_id': userId,
        'status': 'pending',
      });
      return ContactRequestOutcome.envoyee;
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<void> acceptRequest(String userId) async {
    final String? me = _userId;
    if (me == null) return;
    try {
      await _client
          .from('contacts')
          .update(<String, dynamic>{'status': 'accepted'})
          .eq('requester_id', userId)
          .eq('addressee_id', me);
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<void> declineRequest(String userId) => removeContact(userId);

  @override
  Future<void> removeContact(String userId) async {
    final String? me = _userId;
    if (me == null) return;
    try {
      await _client
          .from('contacts')
          .delete()
          .or(
            'and(requester_id.eq.$me,addressee_id.eq.$userId),'
            'and(requester_id.eq.$userId,addressee_id.eq.$me)',
          );
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<void> setFavorite({
    required String userId,
    required ContactDirection direction,
    required bool value,
  }) async {
    final String? me = _userId;
    if (me == null) return;

    // Chacun épingle de son côté : la colonne écrite dépend du bout de la
    // relation où se trouve l'utilisateur.
    final bool iAmRequester = direction == ContactDirection.outgoing;
    final String column = iAmRequester
        ? 'favorite_requester'
        : 'favorite_addressee';

    try {
      await _client
          .from('contacts')
          .update(<String, dynamic>{column: value})
          .eq('requester_id', iAmRequester ? me : userId)
          .eq('addressee_id', iAmRequester ? userId : me);
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  static List<Map<String, dynamic>> _asRows(Object? result) {
    if (result is List) {
      return result.whereType<Map<String, dynamic>>().toList();
    }
    if (result is Map<String, dynamic>) return <Map<String, dynamic>>[result];
    return const <Map<String, dynamic>>[];
  }
}
