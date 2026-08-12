import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/data_providers.dart';
import '../../../data/supabase_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/message.dart';
import '../repository/chat_repository.dart';

/// Dépôt du chat. Surchargé dans les tests par un faux dépôt.
final Provider<ChatRepository> chatRepositoryProvider =
    Provider<ChatRepository>(
      (Ref ref) => SupabaseChatRepository(ref.watch(supabaseClientProvider)),
    );

/// Conversation d'un groupe, la plus récente d'abord.
///
/// Le temps réel n'apporte qu'un **signal** : à chaque changement, on relit la
/// fenêtre courante. `postgres_changes` ne transporte que les colonnes brutes
/// — ni nom d'expéditeur, ni agrégat de réactions, ni compte de lectures —, et
/// les reconstituer côté client reviendrait à réécrire la jointure SQL, avec
/// deux endroits où elle peut diverger.
// Riverpod 3 n'exporte pas les types `*Family` : on laisse l'inférence faire.
final conversationProvider =
    AsyncNotifierProvider.family<ConversationNotifier, List<Message>, String>(
      ConversationNotifier.new,
    );

class ConversationNotifier extends AsyncNotifier<List<Message>> {
  ConversationNotifier(this.groupId);

  final String groupId;

  /// Messages affichés avant confirmation du serveur, par identifiant local.
  /// Ils ne viennent pas de la base et n'y retournent pas : sans eux, taper
  /// « Envoyer » ne produirait rien de visible avant l'aller-retour.
  final List<Message> _enAttente = <Message>[];

  ChatRepository get _repository => ref.read(chatRepositoryProvider);

  @override
  Future<List<Message>> build() async {
    ref.watch(authStatusProvider);
    final ChatRepository repository = ref.watch(chatRepositoryProvider);

    final StreamSubscription<void> abonnement = repository
        .watchChanges(groupId)
        .listen((_) => _relire());

    ref.onDispose(() {
      abonnement.cancel();
      repository.leave(groupId);
    });

    return _avecEnAttente(await repository.fetchMessages(groupId));
  }

  Future<void> _relire() async {
    final AsyncValue<List<Message>> lu = await AsyncValue.guard(
      () => _repository.fetchMessages(groupId),
    );
    // Une relecture qui échoue ne doit pas effacer la conversation à l'écran :
    // le réseau va et vient, et un état d'erreur ferait clignoter l'écran à
    // chaque coupure.
    state = lu.when(
      data: (List<Message> messages) =>
          AsyncData<List<Message>>(_avecEnAttente(messages)),
      error: (_, _) => state,
      loading: () => state,
    );
  }

  Future<void> refresh() => _relire();

  /// Relit une page plus ancienne et l'ajoute à la suite.
  Future<void> loadMore() async {
    final List<Message> courants = state.value ?? const <Message>[];
    if (courants.isEmpty) return;
    final List<Message> plusAnciens = await _repository.fetchMessages(
      groupId,
      before: courants.last.createdAt,
    );
    if (plusAnciens.isEmpty) return;
    state = AsyncData<List<Message>>(<Message>[...courants, ...plusAnciens]);
  }

  /// Envoi optimiste : le message apparaît tout de suite, puis la relecture
  /// déclenchée par le temps réel le remplace par la version du serveur.
  Future<void> send({
    String? content,
    String? mediaUrl,
    MediaKind? mediaKind,
  }) async {
    final String? moi = ref.read(currentUserIdProvider);
    final DateTime maintenant = ref.read(clockProvider).now();
    final String cleLocale = 'local-${maintenant.microsecondsSinceEpoch}';

    final Message provisoire = Message(
      id: cleLocale,
      groupId: groupId,
      senderId: moi ?? '',
      createdAt: maintenant,
      content: content,
      mediaUrl: mediaUrl,
      mediaKind: mediaKind,
      pending: true,
    );

    _enAttente.insert(0, provisoire);
    state = AsyncData<List<Message>>(_avecEnAttente(state.value));

    try {
      await _repository.send(
        groupId,
        content: content,
        mediaUrl: mediaUrl,
        mediaKind: mediaKind,
      );
      _enAttente.removeWhere((Message m) => m.id == cleLocale);
      await _relire();
    } catch (_) {
      final int index = _enAttente.indexWhere((Message m) => m.id == cleLocale);
      if (index != -1) {
        _enAttente[index] = provisoire.copyWith(pending: false, failed: true);
      }
      state = AsyncData<List<Message>>(_avecEnAttente(state.value));
      rethrow;
    }
  }

  /// Retire un message dont l'envoi a échoué. Il n'a jamais existé côté base.
  void discardFailed(String id) {
    _enAttente.removeWhere((Message m) => m.id == id);
    state = AsyncData<List<Message>>(_avecEnAttente(state.value));
  }

  List<Message> _avecEnAttente(List<Message>? confirmes) => <Message>[
    ..._enAttente,
    ...?confirmes,
  ];
}

/// Qui est en train d'écrire dans ce groupe, par nom affiché.
///
/// Un signal de frappe se périme tout seul : sans expiration, quelqu'un qui
/// ferme l'application en plein mot resterait « en train d'écrire »
/// indéfiniment.
final typingProvider =
    NotifierProvider.family<TypingNotifier, List<String>, String>(
      TypingNotifier.new,
    );

class TypingNotifier extends Notifier<List<String>> {
  TypingNotifier(this.groupId);

  final String groupId;

  /// Fin de validité de chaque signal reçu.
  final Map<String, ({String nom, DateTime jusqua})> _actifs =
      <String, ({String nom, DateTime jusqua})>{};

  static const Duration _validite = Duration(seconds: 5);

  @override
  List<String> build() {
    final StreamSubscription<TypingSignal> abonnement = ref
        .watch(chatRepositoryProvider)
        .watchTyping(groupId)
        .listen(_recevoir);

    final Timer minuterie = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _purger(),
    );

    ref.onDispose(() {
      abonnement.cancel();
      minuterie.cancel();
    });

    return const <String>[];
  }

  void _recevoir(TypingSignal signal) {
    if (!signal.typing) {
      _actifs.remove(signal.userId);
    } else {
      _actifs[signal.userId] = (
        nom: signal.name ?? 'Quelqu’un',
        jusqua: ref.read(clockProvider).now().add(_validite),
      );
    }
    _publier();
  }

  void _purger() {
    final DateTime maintenant = ref.read(clockProvider).now();
    final int avant = _actifs.length;
    _actifs.removeWhere(
      (_, ({String nom, DateTime jusqua}) valeur) =>
          valeur.jusqua.isBefore(maintenant),
    );
    if (_actifs.length != avant) _publier();
  }

  void _publier() => state = <String>[
    for (final ({String nom, DateTime jusqua}) valeur in _actifs.values)
      valeur.nom,
  ];
}

/// Non-lus par groupe, pour les pastilles de la liste des groupes.
final AsyncNotifierProvider<UnreadMessagesNotifier, Map<String, int>>
unreadMessagesProvider =
    AsyncNotifierProvider<UnreadMessagesNotifier, Map<String, int>>(
      UnreadMessagesNotifier.new,
    );

class UnreadMessagesNotifier extends AsyncNotifier<Map<String, int>> {
  @override
  Future<Map<String, int>> build() {
    ref.watch(authStatusProvider);
    return ref.watch(chatRepositoryProvider).unreadCounts();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(chatRepositoryProvider).unreadCounts(),
    );
  }
}

/// Non-lus d'un groupe donné, zéro par défaut.
final unreadForGroupProvider = Provider.family<int, String>(
  (Ref ref, String groupId) =>
      (ref.watch(unreadMessagesProvider).value ??
          const <String, int>{})[groupId] ??
      0,
);

/// Écritures. Les widgets ne touchent jamais au dépôt.
final Provider<ChatActions> chatActionsProvider = Provider<ChatActions>(
  ChatActions.new,
);

class ChatActions {
  const ChatActions(this._ref);

  final Ref _ref;

  ChatRepository get _repository => _ref.read(chatRepositoryProvider);

  Future<void> send(
    String groupId, {
    String? content,
    String? mediaUrl,
    MediaKind? mediaKind,
  }) => _ref
      .read(conversationProvider(groupId).notifier)
      .send(content: content, mediaUrl: mediaUrl, mediaKind: mediaKind);

  /// Renvoie faux si rien n'a été supprimé — c'est la fonction SQL qui le dit,
  /// et non l'absence d'exception : sans politique DELETE, une écriture sans
  /// effet répond 200.
  Future<bool> delete(String groupId, String messageId) async {
    final bool retire = await _repository.deleteMessage(messageId);
    await _ref.read(conversationProvider(groupId).notifier).refresh();
    return retire;
  }

  Future<void> react(String groupId, String messageId, String? emoji) async {
    await _repository.react(messageId, emoji);
    await _ref.read(conversationProvider(groupId).notifier).refresh();
  }

  Future<void> markRead(String groupId) async {
    await _repository.markRead(groupId);
    await _ref.read(unreadMessagesProvider.notifier).refresh();
  }

  Future<void> announceTyping(
    String groupId, {
    required bool typing,
    String? name,
  }) => _repository.announceTyping(groupId, typing: typing, name: name);
}
