import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/data_providers.dart';
import '../../../data/supabase_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/message.dart';
import '../repository/chat_repository.dart';
import '../services/voice_player.dart';
import '../services/voice_recorder.dart';

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
    Duration? mediaDuration,
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
      mediaDuration: mediaDuration,
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
        mediaDuration: mediaDuration,
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
    final ChatRepository repository = ref.watch(chatRepositoryProvider);

    // Le compteur doit bouger **sans** qu'on entre dans la conversation :
    // c'est tout l'objet d'une pastille. On écoute donc un canal global, et
    // non celui d'un groupe ouvert.
    final StreamSubscription<void> abonnement = repository
        .watchAllMessages()
        .listen((_) => refresh());
    ref.onDispose(abonnement.cancel);

    return repository.unreadCounts();
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

/// Nombre de **conversations** qui contiennent des messages non lus.
///
/// Ce n'est délibérément pas le nombre de messages. Trois personnes qui
/// écrivent dans le même groupe, cela reste **une** conversation à ouvrir : ce
/// que la pastille annonce, c'est le nombre d'endroits où aller, pas le volume
/// de ce qui s'y trouve. Un « 47 » sur l'onglet dirait quelque chose de vrai
/// et d'inutile.
///
/// La notification système, elle, fait l'inverse — une par message. Les deux
/// répondent à des questions différentes : « où dois-je aller ? » ici,
/// « que s'est-il passé ? » sur l'écran verrouillé.
final Provider<int> unreadConversationsProvider = Provider<int>((Ref ref) {
  final Map<String, int> parGroupe =
      ref.watch(unreadMessagesProvider).value ?? const <String, int>{};
  return parGroupe.values.where((int nombre) => nombre > 0).length;
});

/// URL signée d'un média, résolue à la demande.
///
/// `autoDispose` : une URL signée expire, et la garder en cache au-delà de
/// l'affichage donnerait un lien mort. Sortir de la conversation et y revenir
/// en redemande une fraîche.
final signedMediaUrlProvider = FutureProvider.autoDispose
    .family<String, String>(
      (Ref ref, String path) =>
          ref.watch(chatRepositoryProvider).signedMediaUrl(path),
    );

/// Enregistreur de messages vocaux. Surchargé dans les tests : un micro et un
/// canal de plateforme n'existent pas dans un test de widget.
final Provider<VoiceRecorder> voiceRecorderProvider = Provider<VoiceRecorder>((
  Ref ref,
) {
  final VoiceRecorder enregistreur = SystemVoiceRecorder();
  ref.onDispose(enregistreur.disposer);
  return enregistreur;
});

/// Fabrique du lecteur audio, pour la même raison.
final Provider<VoicePlayer Function()> voicePlayerFactoryProvider =
    Provider<VoicePlayer Function()>((Ref ref) => JustAudioVoicePlayer.new);

/// Ce qui joue, où l'on en est.
///
/// Un seul message vocal à la fois : c'est l'état qui le tient, et non chaque
/// bulle. Deux voix simultanées ne s'écoutent ni l'une ni l'autre.
@immutable
class VoicePlayback {
  const VoicePlayback({
    this.messageId,
    this.playing = false,
    this.loading = false,
    this.position = Duration.zero,
    this.duration,
  });

  /// Message actuellement chargé — pas forcément en train de jouer.
  final String? messageId;
  final bool playing;

  /// L'URL signée est en cours de demande, ou le fichier de chargement.
  final bool loading;
  final Duration position;

  /// Celle annoncée par le fichier. Nulle tant qu'il n'est pas chargé : la
  /// bulle affiche alors celle que la base a retenue.
  final Duration? duration;

  bool estCharge(String id) => messageId == id;
  bool joue(String id) => messageId == id && playing;

  VoicePlayback copyWith({
    String? messageId,
    bool? playing,
    bool? loading,
    Duration? position,
    Duration? duration,
  }) => VoicePlayback(
    messageId: messageId ?? this.messageId,
    playing: playing ?? this.playing,
    loading: loading ?? this.loading,
    position: position ?? this.position,
    duration: duration ?? this.duration,
  );
}

final NotifierProvider<VoicePlaybackNotifier, VoicePlayback>
voicePlaybackProvider = NotifierProvider<VoicePlaybackNotifier, VoicePlayback>(
  VoicePlaybackNotifier.new,
);

class VoicePlaybackNotifier extends Notifier<VoicePlayback> {
  VoicePlayer? _lecteur;
  final List<StreamSubscription<void>> _abonnements =
      <StreamSubscription<void>>[];

  @override
  VoicePlayback build() {
    ref.onDispose(() {
      for (final StreamSubscription<void> a in _abonnements) {
        a.cancel();
      }
      _lecteur?.disposer();
    });
    return const VoicePlayback();
  }

  /// Lance, met en pause ou reprend. Un seul appel pour les trois : côté
  /// bulle, c'est un seul bouton.
  Future<void> basculer(String messageId, String chemin) async {
    if (state.estCharge(messageId) && _lecteur != null) {
      if (state.playing) {
        await _lecteur!.pauser();
      } else {
        await _lecteur!.jouer();
      }
      return;
    }

    // Changer de message : le lecteur précédent s'arrête et disparaît. Le
    // garder ferait tourner deux flux dont un que personne n'écoute.
    await _liberer();

    state = VoicePlayback(messageId: messageId, loading: true);

    try {
      final String url = await ref
          .read(chatRepositoryProvider)
          .signedMediaUrl(chemin);

      final VoicePlayer lecteur = ref.read(voicePlayerFactoryProvider)();
      _lecteur = lecteur;

      final Duration? duree = await lecteur.charger(url);

      _abonnements.add(
        lecteur.positions.listen((Duration position) {
          if (state.messageId == messageId) {
            state = state.copyWith(position: position);
          }
        }),
      );
      _abonnements.add(
        lecteur.lectures.listen((bool joue) {
          if (state.messageId == messageId) {
            state = state.copyWith(playing: joue, loading: false);
          }
        }),
      );
      _abonnements.add(
        lecteur.fins.listen((_) {
          // Revenir au début plutôt que rester à la fin : le bouton
          // « lire » doit relire, et non ne rien faire.
          if (state.messageId == messageId) {
            state = VoicePlayback(messageId: messageId, duration: duree);
          }
        }),
      );

      state = state.copyWith(loading: false, duration: duree);
      await lecteur.jouer();
    } catch (_) {
      // Une lecture qui échoue laisse la bulle telle quelle : le message est
      // là, seul son son manque, et une conversation ne doit pas s'arrêter
      // là-dessus.
      await _liberer();
      state = const VoicePlayback();
    }
  }

  Future<void> allerA(Duration position) async {
    if (_lecteur == null) return;
    await _lecteur!.allerA(position);
    state = state.copyWith(position: position);
  }

  Future<void> _liberer() async {
    for (final StreamSubscription<void> abonnement in _abonnements) {
      await abonnement.cancel();
    }
    _abonnements.clear();
    await _lecteur?.disposer();
    _lecteur = null;
  }
}

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
    Duration? mediaDuration,
  }) => _ref
      .read(conversationProvider(groupId).notifier)
      .send(
        content: content,
        mediaUrl: mediaUrl,
        mediaKind: mediaKind,
        mediaDuration: mediaDuration,
      );

  /// Téléverse puis envoie. Les deux vont ensemble : un objet déposé sans
  /// message qui le référence resterait dans le bucket sans que personne ne
  /// puisse le voir ni le retrouver.
  Future<void> sendMedia(
    String groupId, {
    required Uint8List bytes,
    required String extension,
    required MediaKind kind,
    String? caption,
    Duration? duration,
  }) async {
    final String chemin = await _repository.uploadMedia(
      groupId: groupId,
      bytes: bytes,
      extension: extension,
      kind: kind,
    );
    await send(
      groupId,
      content: caption,
      mediaUrl: chemin,
      mediaKind: kind,
      mediaDuration: duration,
    );
  }

  /// Téléverse et envoie un message vocal. Même chemin que [sendMedia], à la
  /// durée près — elle vient de l'enregistrement, et non du fichier.
  Future<void> sendVoice(
    String groupId, {
    required VoiceRecording enregistrement,
  }) => sendMedia(
    groupId,
    bytes: enregistrement.bytes,
    extension: enregistrement.extension,
    kind: MediaKind.audio,
    duration: enregistrement.duration,
  );

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
