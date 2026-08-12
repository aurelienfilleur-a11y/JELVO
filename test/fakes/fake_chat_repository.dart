import 'dart:async';
import 'dart:typed_data';

import 'package:jelvo/features/chat/models/message.dart';
import 'package:jelvo/features/chat/repository/chat_repository.dart';

/// Conversation en mémoire, pour les tests de widget.
///
/// Le temps réel est simulé par un `StreamController` : un vrai canal
/// Realtime demande une socket, que le harnais de test n'a pas. Ce qui est
/// éprouvé ici, c'est donc que **l'écran réagit au signal** — pas que le
/// signal arrive, ce qui ne se vérifie qu'à l'usage.
class FakeChatRepository implements ChatRepository {
  FakeChatRepository({List<Message>? messages, Map<String, int>? unread})
    : _messages = List<Message>.of(messages ?? demoMessages()),
      _unread = Map<String, int>.of(unread ?? const <String, int>{'g1': 2});

  final List<Message> _messages;
  final Map<String, int> _unread;

  final StreamController<void> _changements =
      StreamController<void>.broadcast();
  final StreamController<TypingSignal> _frappes =
      StreamController<TypingSignal>.broadcast();

  /// Dernier appel reçu, pour les assertions.
  String? lastSentContent;
  String? lastDeletedId;
  String? lastReactedId;
  String? lastEmoji;
  String? lastReadGroupId;
  bool? lastTyping;

  /// Le refus de suppression, pour éprouver le chemin « aucune ligne touchée »
  /// que PostgREST solde par un 200.
  bool deletionSucceeds = true;

  static const String moi = 'utilisateur-test';

  static List<Message> demoMessages() => <Message>[
    Message(
      id: 'm3',
      groupId: 'g1',
      senderId: 'u2',
      createdAt: DateTime(2026, 8, 3, 8, 40),
      content: 'J’apporte le dessert',
    ),
    Message(
      id: 'm2',
      groupId: 'g1',
      senderId: moi,
      createdAt: DateTime(2026, 8, 3, 8, 32),
      content: 'On se retrouve à midi',
      readCount: 1,
    ),
    Message(
      id: 'm1',
      groupId: 'g1',
      senderId: 'u2',
      createdAt: DateTime(2026, 8, 3, 8, 30),
      content: 'Bonjour tout le monde',
      senderName: 'Léa Marchand',
      reactions: const <MessageReaction>[
        MessageReaction(userId: moi, emoji: '👍'),
      ],
    ),
  ];

  /// Pousse un message comme le ferait le temps réel.
  void receive(Message message) {
    _messages.insert(0, message);
    _changements.add(null);
  }

  /// Simule quelqu'un qui écrit.
  void emitTyping(TypingSignal signal) => _frappes.add(signal);

  @override
  Future<List<Message>> fetchMessages(
    String groupId, {
    DateTime? before,
    int limit = 50,
  }) async {
    final List<Message> filtres = _messages
        .where((Message m) => m.groupId == groupId)
        .where((Message m) => before == null || m.createdAt.isBefore(before))
        .toList();
    return filtres.take(limit).toList();
  }

  @override
  Stream<void> watchChanges(String groupId) => _changements.stream;

  @override
  Stream<TypingSignal> watchTyping(String groupId) => _frappes.stream;

  @override
  Future<String> send(
    String groupId, {
    String? content,
    String? mediaUrl,
    MediaKind? mediaKind,
  }) async {
    lastSentContent = content;
    final Message message = Message(
      id: 'm${_messages.length + 1}',
      groupId: groupId,
      senderId: moi,
      createdAt: DateTime(2026, 8, 3, 9),
      content: content,
      mediaUrl: mediaUrl,
      mediaKind: mediaKind,
    );
    _messages.insert(0, message);
    return message.id;
  }

  @override
  Future<bool> deleteMessage(String messageId) async {
    lastDeletedId = messageId;
    if (!deletionSucceeds) return false;
    final int index = _messages.indexWhere((Message m) => m.id == messageId);
    if (index == -1) return false;
    _messages[index] = _messages[index].copyWith(
      deletedAt: DateTime(2026, 8, 3, 9),
      reactions: const <MessageReaction>[],
    );
    return true;
  }

  @override
  Future<String?> react(String messageId, String? emoji) async {
    lastReactedId = messageId;
    lastEmoji = emoji;

    final int index = _messages.indexWhere((Message m) => m.id == messageId);
    if (index == -1) return null;

    final Message message = _messages[index];
    final String? actuel = message.reactionOf(moi);
    final List<MessageReaction> restantes = message.reactions
        .where((MessageReaction r) => r.userId != moi)
        .toList();

    // Reposer le même emoji le retire : c'est ce que fait `reagir_message`.
    if (emoji == null || actuel == emoji) {
      _messages[index] = message.copyWith(reactions: restantes);
      return null;
    }

    _messages[index] = message.copyWith(
      reactions: <MessageReaction>[
        ...restantes,
        MessageReaction(userId: moi, emoji: emoji),
      ],
    );
    return emoji;
  }

  @override
  Future<DateTime> markRead(String groupId) async {
    lastReadGroupId = groupId;
    _unread[groupId] = 0;
    return DateTime(2026, 8, 3, 9);
  }

  @override
  Future<Map<String, int>> unreadCounts() async => Map<String, int>.of(_unread);

  @override
  Future<void> announceTyping(
    String groupId, {
    required bool typing,
    String? name,
  }) async {
    lastTyping = typing;
  }

  /// Dernier média téléversé, pour les assertions.
  String? lastUploadedPath;
  int? lastUploadedBytes;

  @override
  Future<String> uploadMedia({
    required String groupId,
    required Uint8List bytes,
    required String extension,
    required MediaKind kind,
  }) async {
    lastUploadedBytes = bytes.length;
    // Même convention que le vrai dépôt : c'est le premier segment que lisent
    // les politiques du bucket.
    lastUploadedPath = '$groupId/media-${_media++}.$extension';
    return lastUploadedPath!;
  }

  int _media = 1;

  @override
  Future<String> signedMediaUrl(String path) async =>
      'https://exemple.test/signe/$path';

  @override
  Future<void> leave(String groupId) async {}

  void dispose() {
    _changements.close();
    _frappes.close();
  }
}
