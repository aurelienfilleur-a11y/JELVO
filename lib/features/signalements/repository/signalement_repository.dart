import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/models/auth_failure.dart';
import '../models/blocage.dart';
import '../models/signalement.dart';

/// Accès aux signalements d'abus.
///
/// **Rien ici ne lit ni n'écrit la table.** `signalements` n'a aucune
/// politique et aucun privilège : elle est invisible de PostgREST, et les
/// cinq fonctions `security definer` de `tranche15_signalements.sql` sont la
/// seule porte. Chacune porte sa règle dans son corps, de sorte qu'un appel
/// direct — sans passer par cet écran — obtient exactement la même réponse.
abstract interface class SignalementRepository {
  /// Dépose un signalement et renvoie ce que la base en a fait.
  Future<SignalementOutcome> signaler({
    required SignalementCible cible,
    required String cibleId,
    required SignalementMotif motif,
    String? commentaire,
  });

  /// Vrai si l'utilisateur peut lire la file de modération.
  Future<bool> estModerateur();

  /// La file. [traites] choisit l'onglet ; le défaut est ce qui reste à faire.
  Future<List<Signalement>> fetchSignalements({bool traites = false});

  /// Marque traité — ou rouvre, si [traite] est faux.
  Future<SignalementOutcome> traiter({
    required String id,
    String? note,
    bool traite = true,
  });

  /// Suppression douce du message signalé, par un modérateur.
  Future<SignalementOutcome> supprimerMessage(String signalementId);

  /// Bloque quelqu'un. Défait aussi le lien de contact et les invitations en
  /// attente — voir `tranche16_blocage.sql`.
  Future<BlocageOutcome> bloquer(String userId);

  Future<BlocageOutcome> debloquer(String userId);

  /// Les personnes que l'on a bloquées.
  ///
  /// **C'est la seule porte vers le déblocage** : `profil_consultable` ne rend
  /// plus rien sur une personne bloquée.
  Future<List<PersonneBloquee>> fetchBloques();
}

class SupabaseSignalementRepository implements SignalementRepository {
  const SupabaseSignalementRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<SignalementOutcome> signaler({
    required SignalementCible cible,
    required String cibleId,
    required SignalementMotif motif,
    String? commentaire,
  }) async {
    try {
      final Object? mot = await _client.rpc<Object?>(
        'signaler',
        params: <String, dynamic>{
          'p_cible_type': cible.dbValue,
          'p_cible_id': cibleId,
          'p_motif': motif.dbValue,
          'p_commentaire': commentaire,
        },
      );
      return SignalementOutcome.fromDb(mot as String?);
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<bool> estModerateur() async {
    try {
      final Object? reponse = await _client.rpc<Object?>('est_moderateur');
      return reponse == true;
    } catch (error) {
      // **Faux plutôt que lever.** La réponse décide d'une ligne de
      // paramètres : une panne de lecture doit cacher la ligne, pas barrer
      // l'écran entier.
      return false;
    }
  }

  @override
  Future<List<Signalement>> fetchSignalements({bool traites = false}) async {
    try {
      final List<dynamic> rows = await _client.rpc<List<dynamic>>(
        'signalements_a_traiter',
        params: <String, dynamic>{'p_traites': traites},
      );
      return rows
          .whereType<Map<String, dynamic>>()
          .map(Signalement.fromRow)
          .toList();
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<SignalementOutcome> traiter({
    required String id,
    String? note,
    bool traite = true,
  }) async {
    try {
      final Object? mot = await _client.rpc<Object?>(
        'traiter_signalement',
        params: <String, dynamic>{
          'p_signalement_id': id,
          'p_note': note,
          'p_traite': traite,
        },
      );
      return SignalementOutcome.fromDb(mot as String?);
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<SignalementOutcome> supprimerMessage(String signalementId) async {
    try {
      final Object? mot = await _client.rpc<Object?>(
        'supprimer_message_signale',
        params: <String, dynamic>{'p_signalement_id': signalementId},
      );
      return SignalementOutcome.fromDb(mot as String?);
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<BlocageOutcome> bloquer(String userId) async {
    try {
      final Object? mot = await _client.rpc<Object?>(
        'bloquer',
        params: <String, dynamic>{'p_user_id': userId},
      );
      return BlocageOutcome.fromDb(mot as String?);
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<BlocageOutcome> debloquer(String userId) async {
    try {
      final Object? mot = await _client.rpc<Object?>(
        'debloquer',
        params: <String, dynamic>{'p_user_id': userId},
      );
      return BlocageOutcome.fromDb(mot as String?);
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<List<PersonneBloquee>> fetchBloques() async {
    try {
      final List<dynamic> rows = await _client.rpc<List<dynamic>>(
        'mes_blocages',
      );
      return rows
          .whereType<Map<String, dynamic>>()
          .map(PersonneBloquee.fromRow)
          .toList();
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }
}
