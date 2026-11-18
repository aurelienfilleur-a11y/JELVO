import 'package:flutter/material.dart';

import '../../../core/core.dart';

/// Ce que propose le « + » de la barre de saisie.
enum ChatAction { tache, evenement, media }

/// Feuille d'actions du bouton « + ».
///
/// **Trois entrées, et non cinq.** La maquette propose aussi « Nouvelle
/// liste », « Nouvelle dépense » et « Nouvelle note » : aucune des trois
/// n'existe dans Jelvo, ni en base ni à l'écran. Les afficher promettrait une
/// fonctionnalité qui n'arrive pas — la même règle que les pictogrammes
/// écartés de l'écran du groupe.
///
/// « Photo ou vidéo » ne figure pas sur la maquette, mais existe bel et bien
/// et n'avait pas d'autre entrée que le trombone : la ranger ici met les trois
/// choses qu'on peut ajouter à une conversation au même endroit.
class ChatActionsSheet extends StatelessWidget {
  const ChatActionsSheet({super.key});

  static Future<ChatAction?> ouvrir(BuildContext context) {
    return showModalBottomSheet<ChatAction>(
      context: context,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => const ChatActionsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _Ligne(
            icon: Icons.check_circle_outline_rounded,
            teinte: context.couleurs.success,
            fond: context.couleurs.successSoft,
            titre: 'Nouvelle tâche',
            sousTitre: 'Créer une tâche à faire',
            action: ChatAction.tache,
          ),
          _Ligne(
            icon: Icons.calendar_month_rounded,
            teinte: context.couleurs.primary,
            fond: context.couleurs.primarySoft,
            titre: 'Nouvel événement',
            sousTitre: 'Planifier un événement',
            action: ChatAction.evenement,
          ),
          _Ligne(
            icon: Icons.photo_library_outlined,
            teinte: context.couleurs.warning,
            fond: context.couleurs.warningSoft,
            titre: 'Photo ou vidéo',
            sousTitre: 'Envoyer un média',
            action: ChatAction.media,
          ),
          AppSpacing.gapMd,
        ],
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({
    required this.icon,
    required this.teinte,
    required this.fond,
    required this.titre,
    required this.sousTitre,
    required this.action,
  });

  final IconData icon;
  final Color teinte;
  final Color fond;
  final String titre;
  final String sousTitre;
  final ChatAction action;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: fond,
          borderRadius: AppRadii.fieldRadius,
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: teinte),
      ),
      title: Text(
        titre,
        style: context.typo.body.copyWith(fontWeight: AppTypography.medium),
      ),
      subtitle: Text(sousTitre, style: context.typo.caption),
      onTap: () => Navigator.of(context).pop(action),
    );
  }
}
