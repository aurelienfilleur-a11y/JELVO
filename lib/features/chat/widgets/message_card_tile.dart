import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../router/app_routes.dart';
import '../../auth/models/auth_failure.dart';
import '../../calendar/models/calendar_event.dart';
import '../../calendar/providers/calendar_providers.dart';
import '../../calendar/widgets/response_buttons.dart';
import '../../tasks/models/task.dart';
import '../../tasks/providers/task_providers.dart';
import '../models/message.dart';
import '../models/message_card.dart';

/// Une carte de tâche ou d'événement, posée dans le fil de la conversation.
///
/// Elle occupe toute la largeur là où un message garde 70 % : ce n'est pas
/// quelqu'un qui parle, c'est quelque chose qui arrive au groupe, et la
/// distinction doit se voir avant d'être lue.
///
/// **Un appui ouvre le détail.** Les boutons, eux, répondent sur place : c'est
/// tout l'objet de la carte — ne pas avoir à quitter la conversation pour dire
/// oui.
class MessageCardTile extends ConsumerStatefulWidget {
  const MessageCardTile({super.key, required this.message});

  final Message message;

  @override
  ConsumerState<MessageCardTile> createState() => _MessageCardTileState();
}

class _MessageCardTileState extends ConsumerState<MessageCardTile> {
  bool _enCours = false;

  @override
  Widget build(BuildContext context) {
    final MessageCard? carte = widget.message.card;
    if (carte == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: AppCard(
        onTap: carte.supprimee ? null : _ouvrirLeDetail,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: switch (carte) {
          TaskCard() => _tache(carte),
          EventCardData() => _evenement(carte),
        },
      ),
    );
  }

  // — Tâche ——————————————————————————————————————————————————————————————

  Widget _tache(TaskCard carte) {
    final CardPerson? titulaire = carte.titulaire;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Entete(
          icone: Icons.task_alt_rounded,
          couleur: AppColors.primary,
          libelle: 'Tâche',
          titre: carte.titre,
          barre: carte.supprimee || carte.terminee,
        ),

        if (carte.dueAt != null && !carte.supprimee) ...<Widget>[
          AppSpacing.gapSm,
          _Ligne(
            icone: Icons.event_outlined,
            texte:
                'Échéance ${AppDates.shortDate(carte.dueAt!)} à '
                '${AppDates.time(carte.dueAt!)}',
          ),
        ],

        if (carte.supprimee) ...<Widget>[
          AppSpacing.gapSm,
          const _Etat(texte: 'Cette tâche a été supprimée.'),
        ] else if (titulaire != null) ...<Widget>[
          AppSpacing.gapSm,
          _Titulaire(personne: titulaire, phrase: _phrase(carte, titulaire)),
          // Seul celui qui l'a prise peut la rendre. Une tâche **confiée** se
          // refuse depuis son écran d'attribution : le refus reste visible
          // pour qui l'a confiée, la disparition non.
          if (carte.priseParMoi) ...<Widget>[
            AppSpacing.gapMd,
            SecondaryButton(
              label: 'Me désister',
              isDestructive: true,
              onPressed: _enCours ? null : _seDesister,
            ),
          ],
        ] else ...<Widget>[
          AppSpacing.gapSm,
          const _Etat(
            texte: 'Proposée au groupe — personne ne l’a encore prise.',
          ),
          AppSpacing.gapMd,
          InvitationActions(
            refuser: 'Non',
            accepter: 'Oui',
            enCours: _enCours,
            onRefuser: _passerSonTour,
            onAccepter: _prendre,
          ),
        ],
      ],
    );
  }

  /// Ce que la carte raconte une fois la tâche entre des mains.
  ///
  /// La même ligne de `task_assignees` se lit de deux façons opposées selon
  /// qu'on s'est proposé ou qu'on vous l'a confiée — d'où `tache_prise`.
  String _phrase(TaskCard carte, CardPerson titulaire) {
    if (carte.prise) return '${titulaire.name} a pris la tâche';
    return switch (titulaire.status) {
      AssigneeStatus.accepted => '${titulaire.name} a accepté la tâche',
      AssigneeStatus.declined => '${titulaire.name} a refusé la tâche',
      AssigneeStatus.done => '${titulaire.name} a terminé la tâche',
      AssigneeStatus.pending || null => 'Tâche attribuée à ${titulaire.name}',
    };
  }

  // — Événement ——————————————————————————————————————————————————————————

  Widget _evenement(EventCardData carte) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Entete(
          icone: Icons.event_rounded,
          couleur: AppColors.warning,
          libelle: 'Événement',
          titre: carte.titre,
          barre: carte.supprimee,
        ),

        if (carte.supprimee) ...<Widget>[
          AppSpacing.gapSm,
          const _Etat(texte: 'Cet événement a été supprimé.'),
        ] else ...<Widget>[
          AppSpacing.gapSm,
          _Ligne(
            icone: Icons.schedule_rounded,
            texte:
                '${AppDates.shortDate(carte.debut)} · '
                '${AppDates.timeRange(carte.debut, carte.fin)}',
          ),
          if (carte.lieu != null && carte.lieu!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 2),
            _Ligne(icone: Icons.place_outlined, texte: carte.lieu!),
          ],
          AppSpacing.gapSm,
          _Ligne(icone: Icons.how_to_reg_rounded, texte: carte.decompte),
          AppSpacing.gapMd,
          ResponseButtons(
            compact: true,
            courante: carte.maReponse,
            onRepondre: _enCours ? (_) {} : _repondreEvenement,
          ),
        ],
      ],
    );
  }

  // — Actions ————————————————————————————————————————————————————————————

  void _ouvrirLeDetail() {
    final String? tache = widget.message.taskId;
    if (tache != null) {
      context.pushNamed(
        AppRoutes.taskDetail,
        pathParameters: <String, String>{'id': tache},
      );
      return;
    }
    final String? evenement = widget.message.eventId;
    if (evenement != null) {
      context.pushNamed(
        AppRoutes.eventDetail,
        pathParameters: <String, String>{'id': evenement},
      );
    }
  }

  /// « Non » sur une tâche ouverte ne s'écrit nulle part : la base ne connaît
  /// pas le refus d'une tâche qu'on ne vous a pas confiée, et l'inventer
  /// demanderait une table. Le geste est donc reconnu, sans mentir sur son
  /// effet.
  void _passerSonTour() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Très bien — la tâche reste proposée au groupe.'),
      ),
    );
  }

  Future<void> _prendre() async {
    final String? tache = widget.message.taskId;
    if (tache == null) return;
    await _agir(() => ref.read(taskActionsProvider).take(tache));
  }

  Future<void> _seDesister() async {
    final String? tache = widget.message.taskId;
    if (tache == null) return;
    await _agir(() => ref.read(taskActionsProvider).withdraw(tache));
  }

  /// **Le mot d'état décide du message**, pas l'absence d'exception : c'est
  /// lui qui distingue « prise » de « quelqu'un vient de la prendre avant
  /// vous », les deux répondant sans erreur.
  Future<void> _agir(Future<TakeOutcome> Function() action) async {
    final ScaffoldMessengerState messager = ScaffoldMessenger.of(context);
    setState(() => _enCours = true);
    try {
      final TakeOutcome resultat = await action();
      messager.showSnackBar(SnackBar(content: Text(resultat.message)));
    } catch (error) {
      messager.showSnackBar(
        SnackBar(content: Text(AuthFailure.from(error).message)),
      );
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _repondreEvenement(EventResponse reponse) async {
    final String? evenement = widget.message.eventId;
    if (evenement == null) return;
    final ScaffoldMessengerState messager = ScaffoldMessenger.of(context);

    setState(() => _enCours = true);
    try {
      await ref.read(eventActionsProvider).respond(evenement, reponse);
    } catch (error) {
      messager.showSnackBar(
        SnackBar(content: Text(AuthFailure.from(error).message)),
      );
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }
}

/// Pastille, catégorie et titre.
class _Entete extends StatelessWidget {
  const _Entete({
    required this.icone,
    required this.couleur,
    required this.libelle,
    required this.titre,
    required this.barre,
  });

  final IconData icone;
  final Color couleur;
  final String libelle;
  final String titre;

  /// Titre barré : supprimé ou terminé. Le garder lisible vaut mieux que de
  /// le retirer — une carte sans titre ne dirait plus de quoi il s'agissait.
  final bool barre;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: couleur.withValues(alpha: 0.12),
            borderRadius: AppRadii.fieldRadius,
          ),
          child: Icon(icone, size: 18, color: couleur),
        ),
        AppSpacing.hGapMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                libelle,
                style: AppTypography.caption.copyWith(color: couleur),
              ),
              const SizedBox(height: 2),
              EmojiText(
                titre,
                style: AppTypography.h3.copyWith(
                  decoration: barre ? TextDecoration.lineThrough : null,
                  color: barre ? AppColors.textSecondary : AppColors.midnight,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({required this.icone, required this.texte});

  final IconData icone;
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icone, size: 15, color: AppColors.textSecondary),
        AppSpacing.hGapSm,
        Expanded(
          child: EmojiText(
            texte,
            style: AppTypography.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Un mot sur l'état de la carte, en gris : ce n'est pas une donnée de
/// l'élément, c'est ce qu'il en est.
class _Etat extends StatelessWidget {
  const _Etat({required this.texte});

  final String texte;

  @override
  Widget build(BuildContext context) => Text(
    texte,
    style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
  );
}

/// Qui l'a prise, ou à qui elle a été confiée.
class _Titulaire extends StatelessWidget {
  const _Titulaire({required this.personne, required this.phrase});

  final CardPerson personne;
  final String phrase;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        AvatarImage(
          data: AvatarData(name: personne.name, imageUrl: personne.avatarUrl),
          size: 28,
        ),
        AppSpacing.hGapSm,
        Expanded(
          child: EmojiText(
            phrase,
            style: AppTypography.body.copyWith(
              fontWeight: AppTypography.semiBold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
