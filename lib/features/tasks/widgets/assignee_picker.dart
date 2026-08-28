import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../../groups/models/group_member.dart';

/// Carte « Assigner à » : les membres du groupe en rangée d'avatars.
///
/// **Personne n'est présélectionné, et c'est le cœur du composant.** Aucun
/// assigné ne veut pas dire « pour moi » : la tâche est alors *proposée au
/// groupe*, et c'est ce qui produit la carte à boutons Oui / Non dans la
/// conversation. Ce sens est invisible dans une rangée d'avatars — d'où la
/// mention sous la rangée, qui **change avec la sélection** plutôt que de
/// n'apparaître qu'à vide.
///
/// Le rendu lui-même vit dans `core` (`PersonAvatarRow`) : ce widget-ci ne fait
/// que traduire des `GroupMember` en `PickablePerson`.
class AssigneePicker extends StatelessWidget {
  const AssigneePicker({
    super.key,
    required this.membres,
    required this.selection,
    required this.onToggle,
    required this.mention,
    this.titre = 'Assigner à',
  });

  final List<GroupMember> membres;
  final Set<String> selection;
  final ValueChanged<String> onToggle;

  /// Ce que la sélection courante veut dire, en une phrase.
  final String mention;

  final String titre;

  /// Au-delà, la rangée n'en montre qu'une partie et « Autre » ouvre le reste.
  ///
  /// En deçà, la rangée montre déjà tout le monde : un bouton qui n'ouvrirait
  /// que les mêmes visages n'irait nulle part.
  static const int _seuilRangee = 6;

  @override
  Widget build(BuildContext context) {
    final List<PickablePerson> personnes = <PickablePerson>[
      for (final GroupMember membre in membres)
        PickablePerson(
          id: membre.userId,
          name: membre.displayName,
          shortName: membre.shortName,
          avatarUrl: membre.avatarUrl,
        ),
    ];
    final bool tropNombreux = personnes.length > _seuilRangee;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(titre, style: context.typo.h3),
          AppSpacing.gapMd,
          if (personnes.isEmpty)
            Text(
              'Les membres du groupe n’ont pas encore été chargés.',
              style: context.typo.bodyMuted,
            )
          else ...<Widget>[
            PersonAvatarRow(
              personnes: tropNombreux
                  ? personnes.take(_seuilRangee).toList()
                  : personnes,
              selection: selection,
              onToggle: onToggle,
              onAutre: tropNombreux
                  ? () => PersonPickerSheet.ouvrir(
                      context,
                      titre: titre,
                      personnes: personnes,
                      selection: selection,
                      onToggle: onToggle,
                    )
                  : null,
            ),
            AppSpacing.gapSm,
            _Mention(texte: mention, libre: selection.isEmpty),
          ],
        ],
      ),
    );
  }
}

/// La phrase sous la rangée.
///
/// Elle est teintée selon ce qu'elle annonce : violet quand la tâche est
/// confiée à quelqu'un, gris quand elle reste ouverte au groupe. La couleur
/// n'est jamais seule à porter le sens — c'est le texte qui le dit.
class _Mention extends StatelessWidget {
  const _Mention({required this.texte, required this.libre});

  final String texte;
  final bool libre;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          libre ? Icons.campaign_outlined : Icons.person_outline_rounded,
          size: 16,
          color: libre
              ? context.couleurs.textSecondary
              : context.couleurs.primary,
        ),
        AppSpacing.hGapXs,
        Expanded(
          child: Text(
            texte,
            style: context.typo.caption.copyWith(
              color: libre
                  ? context.couleurs.textSecondary
                  : context.couleurs.primary,
              fontWeight: libre ? null : AppTypography.medium,
            ),
          ),
        ),
      ],
    );
  }
}
