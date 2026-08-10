import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../../groups/models/group_member.dart';

/// Carte « Assigner à » : les membres du groupe en rangée d'avatars.
///
/// La sélection se fait au doigt, sur l'avatar lui-même : dans une famille, on
/// reconnaît un visage plus vite qu'on ne lit une liste déroulante. L'avatar
/// choisi porte un contour violet et une pastille de validation — deux
/// signaux plutôt qu'un, pour que le choix reste lisible sans la couleur.
///
/// **Aucun sélectionné signifie « tâche libre »**, et non « pour moi » : elle
/// apparaît alors sans preneur, et n'importe quel membre peut s'en charger
/// depuis son écran de détail.
class AssigneePicker extends StatelessWidget {
  const AssigneePicker({
    super.key,
    required this.membres,
    required this.selection,
    required this.onToggle,
    this.titre = 'Assigner à',
    this.aideLibre =
        'Personne de sélectionné : la tâche restera libre, et '
        'n’importe quel membre pourra s’en charger.',
  });

  final List<GroupMember> membres;
  final Set<String> selection;
  final ValueChanged<String> onToggle;
  final String titre;
  final String aideLibre;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(titre, style: AppTypography.h3),
          AppSpacing.gapMd,
          if (membres.isEmpty)
            Text(
              'Les membres du groupe n’ont pas encore été chargés.',
              style: AppTypography.bodyMuted,
            )
          else
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: membres.length,
                separatorBuilder: (_, _) => AppSpacing.hGapMd,
                itemBuilder: (BuildContext context, int index) {
                  final GroupMember membre = membres[index];
                  return _Avatar(
                    membre: membre,
                    choisi: selection.contains(membre.userId),
                    onTap: () => onToggle(membre.userId),
                  );
                },
              ),
            ),
          if (selection.isEmpty && membres.isNotEmpty) ...<Widget>[
            AppSpacing.gapSm,
            Text(aideLibre, style: AppTypography.caption),
          ],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.membre,
    required this.choisi,
    required this.onTap,
  });

  final GroupMember membre;
  final bool choisi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: choisi,
      button: true,
      label: membre.displayName,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.cardRadius,
        child: SizedBox(
          width: 64,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: choisi ? AppColors.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: AvatarStack(
                      avatars: <AvatarData>[
                        AvatarData(
                          name: membre.displayName,
                          imageUrl: membre.avatarUrl,
                        ),
                      ],
                      size: 48,
                    ),
                  ),
                  if (choisi)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surface,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                membre.shortName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(
                  color: choisi ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: choisi
                      ? AppTypography.semiBold
                      : AppTypography.medium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
