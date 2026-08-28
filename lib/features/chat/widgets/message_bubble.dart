import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../models/message.dart';
import 'chat_media.dart';
import 'voice_message.dart';

/// Une bulle de la conversation.
///
/// Les messages de l'utilisateur sont à droite, en violet ; ceux des autres à
/// gauche, sur fond clair, précédés de leur nom — mais **seulement quand
/// l'expéditeur change**. Répéter le nom à chaque ligne d'une même personne
/// hache la lecture pour ne rien apprendre.
///
/// **Le nom coiffe la série, l'avatar la termine.** Le nom apparaît sur le
/// premier message d'une suite, l'avatar sur le dernier — celui du bas —, et
/// la gouttière reste réservée sur les autres pour que les bulles ne se
/// décalent pas d'une ligne à l'autre. Poser l'avatar sur chaque message
/// donnerait une colonne de visages répétés, et le poser en haut le
/// séparerait de la fin de la prise de parole.
///
/// Aucun avatar sur ses propres messages : on sait qui l'on est, et la place
/// gagnée profite au texte.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.showSender,
    required this.showAvatar,
    required this.timeLabel,
    required this.onLongPress,
    required this.onReactionTap,
    this.onRetry,
  });

  final Message message;
  final bool isMine;
  final bool showSender;

  /// Vrai sur le dernier message d'une série. Voir la documentation de la
  /// classe : la gouttière est réservée même quand il est faux.
  final bool showAvatar;
  final String timeLabel;
  final VoidCallback onLongPress;

  /// Toucher une pastille de réaction bascule la sienne.
  final ValueChanged<String> onReactionTap;

  /// Proposé uniquement sur un message dont l'envoi a échoué.
  final VoidCallback? onRetry;

  /// Diamètre de l'avatar, et largeur de la gouttière qui lui est réservée.
  ///
  /// 28 dp : assez pour reconnaître un visage à côté d'un texte de 15, assez
  /// peu pour ne pas manger la largeur de bulle sur un écran de 360 dp.
  static const double _tailleAvatar = 28;

  @override
  Widget build(BuildContext context) {
    // Les bulles ont leurs propres jetons : en sombre, `primary` est clair et
    // du texte blanc dessus tomberait à 2,9:1. La bulle de l'utilisateur reste
    // donc un violet profond dans les deux thèmes — c'est la seule pièce de
    // l'interface où l'on tient à ce que la couleur ne bouge pas.
    final Color fond = isMine
        ? context.couleurs.bubbleMine
        : context.couleurs.bubbleOther;
    final Color texte = isMine
        ? context.couleurs.onBubbleMine
        : context.couleurs.onBubbleOther;

    final Widget contenu = Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: <Widget>[
          if (showSender && !isMine)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: 2),
              child: EmojiText(
                message.senderName ?? 'Membre',
                style: context.typo.caption.copyWith(
                  // Une couleur par personne, dérivée de son identifiant :
                  // dans un groupe de huit, le gris uniforme obligeait à lire
                  // le nom pour savoir qui parle.
                  color: SpeakerAccent.colorFor(
                    message.senderId,
                    context.couleurs,
                  ),
                  fontWeight: AppTypography.semiBold,
                ),
              ),
            ),

          ConstrainedBox(
            constraints: BoxConstraints(
              // Les messages des autres cèdent la gouttière de l'avatar : à
              // 360 dp, garder 78 % ferait déborder la ligne.
              maxWidth:
                  MediaQuery.sizeOf(context).width * (isMine ? 0.78 : 0.7),
            ),
            child: GestureDetector(
              onLongPress: message.isDeleted ? null : onLongPress,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: message.isDeleted ? context.couleurs.background : fond,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(AppRadii.card),
                    topRight: const Radius.circular(AppRadii.card),
                    bottomLeft: Radius.circular(isMine ? AppRadii.card : 4),
                    bottomRight: Radius.circular(isMine ? 4 : AppRadii.card),
                  ),
                  border: message.isDeleted
                      ? Border.all(color: context.couleurs.border)
                      : null,
                ),
                child: message.isDeleted
                    ? _supprime(context)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          // Un message vocal n'est pas une vignette : il se
                          // lit sur place, et sa bulle porte le bouton.
                          if (message.isVoice)
                            VoiceMessage(message: message, couleur: texte)
                          else if (message.hasMedia)
                            ChatMedia(message: message),
                          if (message.content != null &&
                              message.content!.isNotEmpty)
                            EmojiText(
                              message.content!,
                              style: context.typo.body.copyWith(color: texte),
                            ),
                          const SizedBox(height: 2),
                          _pied(context, texte),
                        ],
                      ),
              ),
            ),
          ),

          if (message.reactions.isNotEmpty) _reactions(context),

          if (message.failed)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text('Non envoyé — réessayer'),
                style: TextButton.styleFrom(
                  foregroundColor: context.couleurs.danger,
                  textStyle: context.typo.caption,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 24),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
        ],
      ),
    );

    if (isMine) return contenu;

    return Row(
      // L'avatar s'aligne sur le bas de la dernière bulle de la série, pas
      // sur son haut : c'est là que la prise de parole se termine.
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        SizedBox(
          width: _tailleAvatar,
          child: showAvatar
              ? Padding(
                  // Aligné sur la bulle, pas sur la marge basse qui la suit.
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AvatarImage(
                    data: AvatarData(
                      name: message.senderName ?? 'Membre',
                      imageUrl: message.senderAvatarUrl,
                    ),
                    size: _tailleAvatar,
                  ),
                )
              : null,
        ),
        AppSpacing.hGapSm,
        Flexible(child: contenu),
      ],
    );
  }

  /// Un message supprimé ne montre plus rien de son contenu — et n'en reçoit
  /// plus non plus : la fonction SQL ne le renvoie pas.
  Widget _supprime(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          Icons.block_rounded,
          size: 14,
          color: context.couleurs.textSecondary,
        ),
        AppSpacing.hGapSm,
        Text(
          'Message supprimé',
          style: context.typo.caption.copyWith(
            color: context.couleurs.textSecondary,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  /// Heure et, pour ses propres messages seulement, l'accusé.
  ///
  /// L'accusé n'a de sens que sur ce qu'on a envoyé : afficher « lu » sur le
  /// message de quelqu'un d'autre ne dirait rien à personne.
  Widget _pied(BuildContext context, Color couleur) {
    final Color discret = couleur.withValues(alpha: 0.7);

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        Text(
          timeLabel,
          style: context.typo.caption.copyWith(color: discret, fontSize: 11),
        ),
        if (isMine) ...<Widget>[
          const SizedBox(width: 4),
          _accuse(context, discret),
        ],
      ],
    );
  }

  Widget _accuse(BuildContext context, Color discret) {
    if (message.pending) {
      return Icon(Icons.schedule_rounded, size: 13, color: discret);
    }
    if (message.failed) {
      return Icon(
        Icons.error_outline_rounded,
        size: 13,
        color: context.couleurs.danger,
      );
    }
    return Icon(
      message.isRead ? Icons.done_all_rounded : Icons.done_rounded,
      size: 14,
      // Le « lu » se voit à la couleur, pas seulement à la forme : deux coches
      // grises et deux coches vives se distinguent mal en un coup d'œil.
      color: message.isRead ? context.couleurs.onBubbleMine : discret,
    );
  }

  Widget _reactions(BuildContext context) {
    final Map<String, List<String>> parEmoji = message.reactionsByEmoji;

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Wrap(
        spacing: 4,
        children: <Widget>[
          for (final MapEntry<String, List<String>> entree in parEmoji.entries)
            InkWell(
              onTap: () => onReactionTap(entree.key),
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: context.couleurs.surface,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(color: context.couleurs.border),
                ),
                child: EmojiText(
                  entree.value.length > 1
                      ? '${entree.key} ${entree.value.length}'
                      : entree.key,
                  style: context.typo.caption,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
