import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../data/data_providers.dart';
import '../../../router/app_routes.dart';
import '../../auth/models/auth_failure.dart';
import '../../auth/providers/auth_providers.dart';
import '../../create/models/creation_kind.dart';
import '../../groups/models/group.dart';
import '../../groups/providers/group_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../models/media_selection.dart';
import '../models/message.dart';
import '../providers/chat_providers.dart';
import '../services/voice_recorder.dart';
import '../widgets/chat_actions_sheet.dart';
import '../widgets/chat_day_divider.dart';
import '../widgets/chat_header.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_card_tile.dart';
import '../widgets/media_picker_sheet.dart';
import '../widgets/message_composer.dart';

/// Conversation d'un groupe.
///
/// **Une seule conversation par groupe** : ni canaux, ni fils, ni messagerie
/// privée. La table `messages` n'a d'ailleurs qu'un `group_id`, sans notion de
/// destinataire — le schéma initial dit la même chose que le produit.
///
/// La liste est **inversée** : les messages récents sont en bas, et c'est là
/// que l'écran s'ouvre. Une liste à l'endroit obligerait à faire défiler à
/// chaque ouverture, et sauterait au moindre message reçu.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _defilement = ScrollController();

  /// Dernier message marqué lu, pour ne pas réécrire à chaque reconstruction.
  String? _dernierLu;

  /// Un téléversement est en cours : le composeur se verrouille, sans quoi on
  /// pourrait en lancer trois d'affilée sans le voir.
  bool _envoiMedia = false;

  @override
  void initState() {
    super.initState();
    _defilement.addListener(_surDefilement);
    // Écrire dans un provider pendant la construction est interdit par
    // Riverpod : on repousse d'une image.
    Future<void>.microtask(_marquerLu);
  }

  @override
  void dispose() {
    _defilement.dispose();
    super.dispose();
  }

  void _surDefilement() {
    // Liste inversée : le haut de l'historique est atteint quand on approche
    // de l'extrémité *maximale* du défilement.
    if (_defilement.position.pixels >=
        _defilement.position.maxScrollExtent - 200) {
      ref.read(conversationProvider(widget.groupId).notifier).loadMore();
    }
  }

  Future<void> _marquerLu() async {
    if (!mounted) return;
    try {
      await ref.read(chatActionsProvider).markRead(widget.groupId);
    } catch (_) {
      // Un accusé de lecture perdu ne mérite pas d'interrompre la lecture.
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Message>> conversation = ref.watch(
      conversationProvider(widget.groupId),
    );
    final List<Message> messages = conversation.value ?? const <Message>[];
    final Group? groupe = ref.watch(groupByIdProvider(widget.groupId));
    final String? moi = ref.watch(currentUserIdProvider);
    final List<String> ecrivent = ref.watch(typingProvider(widget.groupId));

    // Un message arrivé pendant qu'on regarde est lu : ne pas le marquer
    // laisserait la pastille allumée sur une conversation ouverte.
    final String? plusRecent = messages.isEmpty ? null : messages.first.id;
    if (plusRecent != null && plusRecent != _dernierLu) {
      _dernierLu = plusRecent;
      Future<void>.microtask(_marquerLu);
    }

    final GroupActivity activite = ref.watch(
      groupOngoingProvider(widget.groupId),
    );

    return Scaffold(
      backgroundColor: context.couleurs.background,
      appBar: ChatHeader(
        group: groupe,
        onBack: () => Navigator.of(context).maybePop(),
        onOpenGroup: _ouvrirLeGroupe,
      ),
      body: Column(
        children: <Widget>[
          // Ce qui est en cours dans le groupe, sans une lecture de plus :
          // `mes_taches` et `mon_agenda` sont déjà chargées.
          ChatShortcutBar(
            taches: activite.taches,
            evenements: activite.evenements,
            onOpenGroup: _ouvrirLeGroupe,
          ),
          Expanded(
            child: conversation.hasError && messages.isEmpty
                ? EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Conversation indisponible',
                    message: AuthFailure.from(conversation.error!).message,
                    actionLabel: 'Réessayer',
                    onActionPressed: () => ref
                        .read(conversationProvider(widget.groupId).notifier)
                        .refresh(),
                  )
                : messages.isEmpty
                ? const EmptyState(
                    icon: Icons.forum_outlined,
                    title: 'Rien encore',
                    message:
                        'Lancez la conversation : personne n’a encore écrit '
                        'ici.',
                  )
                : _liste(messages, moi),
          ),

          TypingIndicator(names: ecrivent),
          AppSpacing.gapXs,

          MessageComposer(
            onSend: _envoyer,
            onTypingChanged: _annoncerFrappe,
            onAction: _agir,
            onVoice: _envoyerVocal,
            recorder: ref.watch(voiceRecorderProvider),
            enabled: !_envoiMedia,
          ),
        ],
      ),
    );
  }

  Widget _liste(List<Message> messages, String? moi) {
    final DateTime maintenant = ref.watch(nowProvider);

    return ListView.builder(
      controller: _defilement,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        AppSpacing.md,
        AppSpacing.screenMargin,
        AppSpacing.md,
      ),
      itemCount: messages.length,
      itemBuilder: (BuildContext context, int index) {
        final Message message = messages[index];

        // La liste est inversée : le message d'indice supérieur est le
        // **précédent** dans le temps. Le séparateur de date coiffe donc le
        // premier message d'une journée, et se pose au-dessus de lui — ce qui,
        // dans une liste inversée, veut dire après lui dans la colonne.
        final Message? avant = index + 1 < messages.length
            ? messages[index + 1]
            : null;
        final bool changeDeJour =
            avant == null || !_memeJour(avant.createdAt, message.createdAt);

        final Widget ligne = _ligne(messages, index, moi);
        if (!changeDeJour) return ligne;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ChatDayDivider(
              label: AppDates.relativeDay(message.createdAt, now: maintenant),
            ),
            ligne,
          ],
        );
      },
    );
  }

  static bool _memeJour(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _ligne(List<Message> messages, int index, String? moi) {
    final Message message = messages[index];

    // Une carte n'est pas une bulle : elle occupe toute la largeur, ne
    // porte ni avatar ni réaction, et se répond sur place. Elle reste en
    // revanche **à sa place**, puisque c'est une ligne de `messages` comme
    // les autres.
    if (message.isCard) return MessageCardTile(message: message);

    // La liste est inversée : le message « suivant » à l'écran est celui
    // d'indice supérieur, donc plus ancien.
    final Message? precedent = index + 1 < messages.length
        ? messages[index + 1]
        : null;

    // La liste étant inversée, le message affiché **sous** celui-ci est
    // d'indice inférieur. L'avatar se pose sur le dernier d'une série,
    // c'est-à-dire celui dont le voisin du dessous change d'expéditeur —
    // ou le tout dernier de la conversation.
    final Message? suivant = index > 0 ? messages[index - 1] : null;

    return MessageBubble(
      message: message,
      isMine: message.senderId == moi,
      // Une carte coupe la série : la bulle qui la suit recommence par
      // son nom, celle qui la précède reprend son avatar. Un changement de
      // jour la coupe aussi : le nom se relit sous le séparateur.
      showSender:
          precedent == null ||
          precedent.isCard ||
          precedent.senderId != message.senderId ||
          !_memeJour(precedent.createdAt, message.createdAt),
      showAvatar:
          suivant == null ||
          suivant.isCard ||
          suivant.senderId != message.senderId ||
          !_memeJour(suivant.createdAt, message.createdAt),
      timeLabel: AppDates.time(message.createdAt),
      onLongPress: () => _ouvrirActions(message, moi),
      onReactionTap: (String emoji) => _reagir(message, emoji),
      onRetry: message.failed ? () => _reessayer(message) : null,
    );
  }

  Future<void> _envoyer(String texte) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(chatActionsProvider).send(widget.groupId, content: texte);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(AuthFailure.from(error).message)),
      );
    }
  }

  /// Ouvre l'écran du groupe — l'en-tête et le chevron y mènent tous deux.
  ///
  /// **On dépile, on n'empile pas.** La conversation est posée sur le
  /// navigateur racine, au-dessus de l'écran du groupe : y pousser une
  /// seconde fois `/groupes/<id>` mettrait deux fois la même page dans la
  /// pile, ce que Flutter refuse. Le repli sert le cas où l'on est arrivé
  /// directement — par une notification, par exemple —, et où il n'y a rien
  /// à dépiler.
  void _ouvrirLeGroupe() {
    final GoRouter routeur = GoRouter.of(context);
    if (routeur.canPop()) {
      routeur.pop();
      return;
    }
    routeur.goNamed(
      AppRoutes.groupDetail,
      pathParameters: <String, String>{'id': widget.groupId},
    );
  }

  /// Ce que fait le « + ».
  void _agir(ChatAction action) {
    switch (action) {
      case ChatAction.media:
        _joindre();
      case ChatAction.tache:
        _creer(CreationKind.task);
      case ChatAction.evenement:
        _creer(CreationKind.event);
    }
  }

  /// Le contexte passe par l'**URL** — `/creer?type=task&groupe=<id>` — et non
  /// par un `extra`, qui se perdrait au rafraîchissement du web.
  void _creer(CreationKind kind) {
    context.pushNamed(
      AppRoutes.create,
      queryParameters: <String, String>{
        AppRoutes.createKindParam: kind.name,
        AppRoutes.createGroupParam: widget.groupId,
      },
    );
  }

  Future<void> _envoyerVocal(VoiceRecording enregistrement) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _envoiMedia = true);
    try {
      await ref
          .read(chatActionsProvider)
          .sendVoice(widget.groupId, enregistrement: enregistrement);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(AuthFailure.from(error).message)),
      );
    } finally {
      if (mounted) setState(() => _envoiMedia = false);
    }
  }

  Future<void> _joindre() async {
    final MediaSelection? choix = await choisirMedia(context);
    if (choix == null || !mounted) return;

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _envoiMedia = true);
    try {
      await ref
          .read(chatActionsProvider)
          .sendMedia(
            widget.groupId,
            bytes: choix.bytes,
            extension: choix.extension,
            kind: choix.kind,
          );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(AuthFailure.from(error).message)),
      );
    } finally {
      if (mounted) setState(() => _envoiMedia = false);
    }
  }

  void _reessayer(Message message) {
    ref
        .read(conversationProvider(widget.groupId).notifier)
        .discardFailed(message.id);
    if (message.content != null) _envoyer(message.content!);
  }

  void _annoncerFrappe(bool frappe) {
    final String? nom = ref.read(currentProfileProvider).value?.displayName;
    ref
        .read(chatActionsProvider)
        .announceTyping(widget.groupId, typing: frappe, name: nom);
  }

  Future<void> _reagir(Message message, String emoji) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      // La fonction SQL bascule : reposer le même emoji le retire. L'écran n'a
      // donc pas à savoir si l'on ajoute ou si l'on enlève.
      await ref
          .read(chatActionsProvider)
          .react(widget.groupId, message.id, emoji);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(AuthFailure.from(error).message)),
      );
    }
  }

  Future<void> _ouvrirActions(Message message, String? moi) async {
    if (message.pending || message.failed) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  for (final String emoji in emojisDeReaction)
                    IconButton(
                      // Un emoji n'est pas une icône : `Text` le rend, et
                      // l'infobulle donne au lecteur d'écran ce que le glyphe
                      // ne dit pas.
                      icon: EmojiText(
                        emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                      tooltip: 'Réagir $emoji',
                      isSelected: message.reactionOf(moi) == emoji,
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _reagir(message, emoji);
                      },
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: context.couleurs.border),
            if (message.senderId == moi)
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: context.couleurs.danger,
                ),
                title: Text(
                  'Supprimer le message',
                  style: context.typo.body.copyWith(
                    color: context.couleurs.danger,
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _supprimer(message);
                },
              )
            else
              ListTile(
                leading: Icon(
                  Icons.lock_outline_rounded,
                  color: context.couleurs.textSecondary,
                ),
                title: Text('Vous ne pouvez supprimer que vos messages'),
              ),
            AppSpacing.gapMd,
          ],
        ),
      ),
    );
  }

  Future<void> _supprimer(Message message) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      // Le booléen fait foi : `messages` n'a pas de politique DELETE, et une
      // écriture sans effet répond 200. Annoncer une suppression qui n'a pas
      // eu lieu serait pire que l'échec lui-même.
      final bool retire = await ref
          .read(chatActionsProvider)
          .delete(widget.groupId, message.id);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            retire
                ? 'Message supprimé.'
                : 'Ce message ne peut plus être supprimé.',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(AuthFailure.from(error).message)),
      );
    }
  }
}
