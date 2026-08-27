import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/app_config.dart';
import '../../auth/models/auth_failure.dart';
import '../models/message.dart';

/// Qui est en train d'écrire, à un instant donné.
class TypingSignal {
  const TypingSignal({
    required this.userId,
    required this.name,
    required this.typing,
  });

  final String userId;
  final String? name;
  final bool typing;
}

/// Accès à la conversation d'un groupe.
///
/// Toutes les écritures passent par des fonctions SQL. Deux raisons, chacune
/// suffisante : `messages` n'a **pas de politique DELETE** — la suppression est
/// donc douce et doit dire si elle a agi —, et rien ne garantit qu'un membre
/// puisse lire la ligne `profiles` d'un autre.
///
/// Voir `supabase/tranche5a_chat.sql`.
abstract interface class ChatRepository {
  /// Messages du groupe, les plus récents d'abord.
  ///
  /// [before] pagine par curseur et non par `offset` : dans une conversation
  /// qui s'allonge pendant qu'on la remonte, un `offset` saute des lignes.
  Future<List<Message>> fetchMessages(
    String groupId, {
    DateTime? before,
    int limit,
  });

  /// Émet à chaque changement de la conversation.
  ///
  /// **Un signal, pas les données.** `postgres_changes` ne transporte que les
  /// colonnes brutes de la ligne : ni le nom de l'expéditeur, ni l'agrégat des
  /// réactions, ni le compte de lectures, que seule la fonction SQL sait
  /// assembler. Reconstituer tout cela côté client, ce serait réécrire la
  /// jointure — et se donner un second endroit où elle peut diverger.
  Stream<void> watchChanges(String groupId);

  /// Renvoie l'identifiant du message créé.
  ///
  /// [mediaDuration] n'a de sens que pour un message vocal : la fonction SQL
  /// l'écarte pour tout autre type de média.
  Future<String> send(
    String groupId, {
    String? content,
    String? mediaUrl,
    MediaKind? mediaKind,
    Duration? mediaDuration,
  });

  /// Suppression douce. **Le booléen fait foi**, pas l'absence d'exception :
  /// sans politique DELETE, une écriture qui ne touche aucune ligne se solde
  /// par un 200 côté PostgREST.
  Future<bool> deleteMessage(String messageId);

  /// Pose, remplace ou retire une réaction. Renvoie l'emoji retenu, ou `null`
  /// s'il a été retiré. Passer le même emoji deux fois le retire.
  Future<String?> react(String messageId, String? emoji);

  /// Marque la conversation comme lue et renvoie l'instant retenu.
  Future<DateTime> markRead(String groupId);

  /// Non-lus par groupe, pour les pastilles.
  Future<Map<String, int>> unreadCounts();

  /// Émet à chaque message reçu, **quel que soit le groupe**.
  ///
  /// Sans ce signal global, la pastille de l'onglet ne bougerait qu'après une
  /// visite dans la conversation concernée — c'est-à-dire précisément quand
  /// elle n'a plus rien à annoncer. `watchChanges` ne sert qu'un groupe à la
  /// fois, et n'est abonné que pendant que l'écran est ouvert.
  ///
  /// RLS filtre pour nous : on ne reçoit que les messages des groupes dont on
  /// est membre, sans avoir à les énumérer.
  Stream<void> watchAllMessages();

  /// Annonce que l'on écrit — ou que l'on a cessé.
  ///
  /// Passe par un **broadcast** Realtime et non par une table : l'information
  /// vaut deux secondes, et l'écrire en base laisserait des lignes derrière
  /// chaque frappe.
  Future<void> announceTyping(
    String groupId, {
    required bool typing,
    String? name,
  });

  /// Signaux de frappe des autres membres.
  Stream<TypingSignal> watchTyping(String groupId);

  /// Téléverse un média et renvoie **le chemin** dans le bucket.
  ///
  /// Le chemin, et non une URL : le bucket est privé, sa lecture passe par une
  /// URL signée qui expire. Stocker l'URL dans `messages.media_url` la ferait
  /// pourrir en quelques heures.
  ///
  /// La convention `<group_id>/<uuid>.<ext>` n'est pas cosmétique : les
  /// politiques du bucket lisent le **premier segment** pour savoir de quel
  /// groupe relève l'objet.
  Future<String> uploadMedia({
    required String groupId,
    required Uint8List bytes,
    required String extension,
    required MediaKind kind,
  });

  /// URL signée d'un média, valable un temps limité.
  Future<String> signedMediaUrl(String path);

  /// Libère les canaux d'un groupe.
  Future<void> leave(String groupId);
}

class SupabaseChatRepository implements ChatRepository {
  SupabaseChatRepository(this._client);

  final SupabaseClient _client;

  /// Un canal par groupe, partagé entre les changements et la frappe : ouvrir
  /// deux canaux sur le même sujet doublerait le trafic pour rien.
  final Map<String, RealtimeChannel> _canaux = <String, RealtimeChannel>{};
  final Map<String, StreamController<void>> _changements =
      <String, StreamController<void>>{};
  final Map<String, StreamController<TypingSignal>> _frappes =
      <String, StreamController<TypingSignal>>{};

  String? get _moi => _client.auth.currentUser?.id;

  @override
  Future<List<Message>> fetchMessages(
    String groupId, {
    DateTime? before,
    int limit = 50,
  }) async {
    try {
      final Object? result = await _client.rpc<Object?>(
        'messages_du_groupe',
        params: <String, dynamic>{
          'p_group_id': groupId,
          'p_avant': before?.toUtc().toIso8601String(),
          'p_limite': limit,
        },
      );
      return _rows(result).map(Message.fromRow).toList();
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Stream<void> watchChanges(String groupId) {
    final StreamController<void> controleur = _changements.putIfAbsent(
      groupId,
      () => StreamController<void>.broadcast(),
    );
    _canal(groupId);
    return controleur.stream;
  }

  @override
  Stream<TypingSignal> watchTyping(String groupId) {
    final StreamController<TypingSignal> controleur = _frappes.putIfAbsent(
      groupId,
      () => StreamController<TypingSignal>.broadcast(),
    );
    _canal(groupId);
    return controleur.stream;
  }

  /// Ouvre le canal du groupe, une seule fois.
  RealtimeChannel _canal(String groupId) {
    return _canaux.putIfAbsent(groupId, () {
      final RealtimeChannel canal = _client.channel('groupe:$groupId');

      // `task_assignees` et `event_participants` s'y ajoutent depuis la
      // tranche 9 : répondre sur une carte n'écrit dans aucune des trois
      // premières, et la carte des autres resterait figée. `prendre_tache`,
      // lui, touche `messages` — il n'avait pas besoin de ce détour.
      for (final String table in const <String>[
        'messages',
        'message_reactions',
        'message_reads',
        'task_assignees',
        'event_participants',
      ]) {
        canal.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          // Trois de ces tables n'ont pas de `group_id` : on ne peut pas les
          // filtrer côté serveur, et le signal est donc plus large que
          // nécessaire. Sans conséquence — il ne déclenche qu'une relecture.
          filter:
              const <String>{
                'message_reactions',
                'task_assignees',
                'event_participants',
              }.contains(table)
              ? null
              : PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'group_id',
                  value: groupId,
                ),
          callback: (_) => _changements[groupId]?.add(null),
        );
      }

      canal.onBroadcast(
        event: 'frappe',
        callback: (Map<String, dynamic> charge) {
          final String? qui = charge['user_id'] as String?;
          // Son propre écho ne regarde personne.
          if (qui == null || qui == _moi) return;
          _frappes[groupId]?.add(
            TypingSignal(
              userId: qui,
              name: charge['nom'] as String?,
              typing: charge['frappe'] == true,
            ),
          );
        },
      );

      canal.subscribe();
      return canal;
    });
  }

  @override
  Future<String> send(
    String groupId, {
    String? content,
    String? mediaUrl,
    MediaKind? mediaKind,
    Duration? mediaDuration,
  }) async {
    try {
      final Object? result = await _client.rpc<Object?>(
        'envoyer_message',
        params: <String, dynamic>{
          'p_group_id': groupId,
          'p_content': content,
          'p_media_url': mediaUrl,
          'p_media_kind': mediaKind?.dbValue,
          'p_media_duree_s': mediaDuration?.inSeconds,
        },
      );
      if (result is String) return result;
      throw const AuthFailure(
        'Le message n’a pas pu être envoyé. Réessayez dans un instant.',
      );
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<bool> deleteMessage(String messageId) async {
    try {
      final Object? result = await _client.rpc<Object?>(
        'supprimer_message',
        params: <String, dynamic>{'p_message_id': messageId},
      );
      return result == true;
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<String?> react(String messageId, String? emoji) async {
    try {
      final Object? result = await _client.rpc<Object?>(
        'reagir_message',
        params: <String, dynamic>{'p_message_id': messageId, 'p_emoji': emoji},
      );
      return result as String?;
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<DateTime> markRead(String groupId) async {
    try {
      final Object? result = await _client.rpc<Object?>(
        'marquer_lu',
        params: <String, dynamic>{'p_group_id': groupId},
      );
      return DateTime.tryParse(result as String? ?? '')?.toLocal() ??
          DateTime.now();
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<Map<String, int>> unreadCounts() async {
    try {
      final Object? result = await _client.rpc<Object?>('messages_non_lus');
      return <String, int>{
        for (final Map<String, dynamic> row in _rows(result))
          row['group_id'] as String: (row['non_lus'] as num?)?.toInt() ?? 0,
      };
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<void> announceTyping(
    String groupId, {
    required bool typing,
    String? name,
  }) async {
    final String? moi = _moi;
    if (moi == null) return;
    // Un échec d'annonce n'est pas un échec de conversation : on n'a rien à
    // dire à l'utilisateur si l'indicateur de frappe se perd.
    try {
      await _canal(groupId).sendBroadcastMessage(
        event: 'frappe',
        payload: <String, dynamic>{
          'user_id': moi,
          'nom': name,
          'frappe': typing,
        },
      );
    } catch (_) {
      // volontairement ignoré
    }
  }

  RealtimeChannel? _canalGlobal;
  StreamController<void>? _tousLesMessages;

  @override
  Stream<void> watchAllMessages() {
    final StreamController<void> controleur = _tousLesMessages ??=
        StreamController<void>.broadcast();

    _canalGlobal ??= _client
        .channel('jelvo:messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          // Aucun filtre : RLS ne laisse passer que les groupes dont on est
          // membre, et les énumérer côté client donnerait un abonnement à
          // refaire à chaque adhésion.
          callback: (_) => _tousLesMessages?.add(null),
        )
        .subscribe();

    return controleur.stream;
  }

  @override
  Future<String> uploadMedia({
    required String groupId,
    required Uint8List bytes,
    required String extension,
    required MediaKind kind,
  }) async {
    // Le premier segment est l'identifiant du groupe : c'est lui que lisent
    // les politiques du bucket. Le second est tiré au sort, pour qu'un nom de
    // fichier ne révèle rien et que deux envois simultanés ne se marchent pas
    // dessus.
    final String jeton = base64Url
        .encode(List<int>.generate(12, (_) => Random.secure().nextInt(256)))
        .replaceAll('=', '');
    final String chemin = '$groupId/$jeton.$extension';

    try {
      await _client.storage
          .from(AppConfig.chatMediaBucket)
          .uploadBinary(
            chemin,
            bytes,
            fileOptions: FileOptions(
              contentType: _typeMime(extension, kind),
              upsert: false,
            ),
          );
      return chemin;
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<String> signedMediaUrl(String path) async {
    try {
      return await _client.storage
          .from(AppConfig.chatMediaBucket)
          .createSignedUrl(path, AppConfig.chatMediaUrlValidity.inSeconds);
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  static String _typeMime(String extension, MediaKind kind) =>
      switch (extension.toLowerCase()) {
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        'jpg' || 'jpeg' => 'image/jpeg',
        'mp4' => kind == MediaKind.audio ? 'audio/mp4' : 'video/mp4',
        'mov' => 'video/quicktime',
        'webm' => kind == MediaKind.audio ? 'audio/webm' : 'video/webm',
        // Messages vocaux. Deux familles, parce qu'aucun format n'est
        // enregistrable partout : Safari produit de l'AAC dans un conteneur
        // MP4, Chrome et Firefox de l'Opus dans un conteneur WebM.
        'm4a' || 'aac' => 'audio/mp4',
        'ogg' || 'oga' || 'opus' => 'audio/ogg',
        'mp3' => 'audio/mpeg',
        // Repli cohérent avec le type déclaré plutôt qu'un
        // `application/octet-stream` qui empêcherait tout affichage.
        _ => switch (kind) {
          MediaKind.video => 'video/mp4',
          MediaKind.audio => 'audio/mp4',
          MediaKind.image => 'image/jpeg',
        },
      };

  @override
  Future<void> leave(String groupId) async {
    final RealtimeChannel? canal = _canaux.remove(groupId);
    if (canal != null) await _client.removeChannel(canal);
    await _changements.remove(groupId)?.close();
    await _frappes.remove(groupId)?.close();
  }

  static List<Map<String, dynamic>> _rows(Object? result) {
    if (result is List) {
      return result.whereType<Map<String, dynamic>>().toList();
    }
    if (result is Map<String, dynamic>) return <Map<String, dynamic>>[result];
    return const <Map<String, dynamic>>[];
  }
}
