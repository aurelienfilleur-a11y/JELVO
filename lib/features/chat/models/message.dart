import 'package:flutter/foundation.dart';

import 'message_card.dart';

/// Nature d'un média joint. Reflète le type `media_type` du schéma initial,
/// qui ne connaît que ces deux valeurs — c'est **lui**, et non une règle
/// d'écran, qui interdit les documents.
enum MediaKind {
  image,
  video;

  String get dbValue => name;

  static MediaKind? fromDb(String? value) => switch (value) {
    'image' => MediaKind.image,
    'video' => MediaKind.video,
    _ => null,
  };
}

/// Réaction d'une personne à un message.
///
/// La clé primaire `(message_id, user_id)` de `message_reactions` garantit
/// qu'il n'y en a qu'une par personne et par message. L'application n'a donc
/// aucune unicité à faire respecter : elle bascule, la base tranche.
@immutable
class MessageReaction {
  const MessageReaction({required this.userId, required this.emoji});

  factory MessageReaction.fromJson(Map<String, dynamic> json) =>
      MessageReaction(
        userId: json['user_id'] as String,
        emoji: json['emoji'] as String,
      );

  final String userId;
  final String emoji;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageReaction &&
          other.userId == userId &&
          other.emoji == emoji);

  @override
  int get hashCode => Object.hash(userId, emoji);
}

/// Un message de la conversation d'un groupe.
@immutable
class Message {
  const Message({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.createdAt,
    this.content,
    this.mediaUrl,
    this.mediaKind,
    this.deletedAt,
    this.senderName,
    this.senderAvatarUrl,
    this.reactions = const <MessageReaction>[],
    this.readCount = 0,
    this.pending = false,
    this.failed = false,
    this.taskId,
    this.eventId,
    this.card,
  });

  factory Message.fromRow(Map<String, dynamic> row) {
    final Object? brutes = row['reactions'];
    return Message(
      id: row['id'] as String,
      groupId: row['group_id'] as String,
      senderId: row['sender_id'] as String,
      createdAt:
          DateTime.tryParse((row['created_at'] as String?) ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      content: row['content'] as String?,
      mediaUrl: row['media_url'] as String?,
      mediaKind: MediaKind.fromDb(row['media_kind'] as String?),
      deletedAt: DateTime.tryParse(
        (row['deleted_at'] as String?) ?? '',
      )?.toLocal(),
      senderName: _nomAffiche(row),
      senderAvatarUrl: row['avatar_url'] as String?,
      reactions: brutes is List
          ? <MessageReaction>[
              for (final Object? brute in brutes)
                if (brute is Map<String, dynamic>)
                  MessageReaction.fromJson(brute),
            ]
          : const <MessageReaction>[],
      readCount: (row['lu_par'] as num?)?.toInt() ?? 0,
      taskId: row['task_id'] as String?,
      eventId: row['event_id'] as String?,
      card: MessageCard.fromJson(row['carte']),
    );
  }

  final String id;
  final String groupId;
  final String senderId;
  final DateTime createdAt;

  final String? content;
  final String? mediaUrl;
  final MediaKind? mediaKind;

  /// Renseigné pour un message supprimé. La fonction SQL ne renvoie alors ni
  /// contenu ni média : il ne s'agit pas de les masquer à l'écran, mais de ne
  /// pas les faire sortir de la base.
  final DateTime? deletedAt;

  final String? senderName;
  final String? senderAvatarUrl;

  final List<MessageReaction> reactions;

  /// Nombre d'**autres** membres qui ont lu — l'expéditeur ne se compte pas.
  ///
  /// `message_reads` ne stocke qu'un `last_read_at` par conversation : il
  /// n'existe aucun accusé par message dans le schéma, et ce compte est donc
  /// déduit, non lu quelque part.
  final int readCount;

  /// Message affiché avant d'avoir été confirmé par le serveur. Il n'existe
  /// que côté client : sans lui, taper « Envoyer » ne produirait rien de
  /// visible tant que l'aller-retour n'a pas eu lieu.
  final bool pending;

  /// L'envoi a échoué. Distinct de [pending] : un message en attente finira
  /// peut-être par partir, celui-ci non.
  final bool failed;

  /// Élément porté par la carte, quand ce message en est une.
  ///
  /// Une carte **est** une ligne de `messages` : c'est ce qui la garde à sa
  /// place chronologique, la fait passer par le temps réel déjà en place et la
  /// compte dans les non-lus, sans qu'aucun code n'ait à fusionner deux listes
  /// triées ni à faire coïncider deux paginations.
  final String? taskId;

  final String? eventId;

  /// L'état de l'élément au moment de la lecture. `null` sur un message
  /// ordinaire.
  final MessageCard? card;

  bool get isCard => card != null;

  bool get isDeleted => deletedAt != null;

  bool get hasMedia => mediaUrl != null && !isDeleted;

  /// Vrai si au moins un autre membre l'a lu.
  bool get isRead => readCount > 0;

  /// Regroupe les réactions par emoji, dans l'ordre d'apparition.
  Map<String, List<String>> get reactionsByEmoji {
    final Map<String, List<String>> parEmoji = <String, List<String>>{};
    for (final MessageReaction reaction in reactions) {
      (parEmoji[reaction.emoji] ??= <String>[]).add(reaction.userId);
    }
    return parEmoji;
  }

  /// Emoji posé par [userId], ou `null`.
  String? reactionOf(String? userId) {
    if (userId == null) return null;
    for (final MessageReaction reaction in reactions) {
      if (reaction.userId == userId) return reaction.emoji;
    }
    return null;
  }

  Message copyWith({
    List<MessageReaction>? reactions,
    int? readCount,
    DateTime? deletedAt,
    bool? pending,
    bool? failed,
  }) {
    return Message(
      id: id,
      groupId: groupId,
      senderId: senderId,
      createdAt: createdAt,
      content: content,
      mediaUrl: mediaUrl,
      mediaKind: mediaKind,
      deletedAt: deletedAt ?? this.deletedAt,
      senderName: senderName,
      senderAvatarUrl: senderAvatarUrl,
      reactions: reactions ?? this.reactions,
      readCount: readCount ?? this.readCount,
      pending: pending ?? this.pending,
      failed: failed ?? this.failed,
      taskId: taskId,
      eventId: eventId,
      card: card,
    );
  }

  static String? _nomAffiche(Map<String, dynamic> row) {
    final String complet = <String?>[
      row['first_name'] as String?,
      row['last_name'] as String?,
    ].whereType<String>().where((String p) => p.isNotEmpty).join(' ');
    if (complet.isNotEmpty) return complet;
    final String? pseudo = row['pseudo'] as String?;
    return pseudo == null || pseudo.isEmpty ? null : '@$pseudo';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Message && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// Les six emojis proposés au toucher long.
///
/// Une liste fermée plutôt qu'un sélecteur complet : à six, le choix se fait
/// d'un geste, et l'immense majorité des réactions tient dans cette poignée.
/// La base accepte n'importe quel emoji de 8 caractères au plus, donc
/// l'ouvrir plus tard ne demandera aucune migration.
const List<String> emojisDeReaction = <String>[
  '👍',
  '❤️',
  '😂',
  '😮',
  '😢',
  '🎉',
];
