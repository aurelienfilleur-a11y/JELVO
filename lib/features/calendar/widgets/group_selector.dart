import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../groups/models/group.dart';
import '../../groups/providers/group_providers.dart';

/// « Dans quel groupe ? » — la ligne qui porte la photo du groupe, son nom et
/// son nombre de membres.
///
/// Elle n'existait pas : le groupe d'un événement était **imposé par l'écran
/// d'où l'on venait**. Ouvert depuis le calendrier ou depuis le « + », le
/// formulaire ne pouvait créer qu'un rendez-vous personnel, sans aucun moyen
/// de le rattacher à un groupe.
///
/// « Personnel » est une valeur du choix, et non son absence : un rendez-vous
/// que l'on est seul à voir est un cas courant, pas un défaut de saisie.
class GroupSelector extends ConsumerWidget {
  const GroupSelector({
    super.key,
    required this.groupId,
    required this.onChanged,
    this.label = 'Dans quel groupe ? *',
  });

  final String? groupId;
  final ValueChanged<String?> onChanged;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Group> groupes = ref.watch(activeGroupsProvider);
    final Group? choisi = groupId == null
        ? null
        : groupes.where((Group g) => g.id == groupId).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: AppTypography.caption.copyWith(
            fontWeight: AppTypography.medium,
            color: AppColors.midnight,
          ),
        ),
        AppSpacing.gapSm,
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          onTap: () => _ouvrir(context, groupes),
          child: Row(
            children: <Widget>[
              _Vignette(groupe: choisi),
              AppSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      choisi?.name ?? 'Personnel',
                      style: AppTypography.body.copyWith(
                        fontWeight: AppTypography.semiBold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      choisi?.memberLabel ?? 'Vous seul le verrez',
                      style: AppTypography.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.expand_more_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _ouvrir(BuildContext context, List<Group> groupes) async {
    final ({String? id})? choix = await showModalBottomSheet<({String? id})>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text('Dans quel groupe ?', style: AppTypography.h2),
            ),
            AppSpacing.gapMd,
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  _Ligne(
                    groupe: null,
                    choisi: groupId == null,
                    onTap: () =>
                        Navigator.of(sheetContext).pop((id: null as String?)),
                  ),
                  for (final Group groupe in groupes)
                    _Ligne(
                      groupe: groupe,
                      choisi: groupe.id == groupId,
                      onTap: () =>
                          Navigator.of(sheetContext).pop((id: groupe.id)),
                    ),
                ],
              ),
            ),
            AppSpacing.gapMd,
          ],
        ),
      ),
    );
    if (choix != null) onChanged(choix.id);
  }
}

/// La photo du groupe, ou son initiale sur l'accent dérivé de l'identifiant —
/// le même repli que partout ailleurs.
class _Vignette extends StatelessWidget {
  const _Vignette({required this.groupe});

  final Group? groupe;

  @override
  Widget build(BuildContext context) {
    final Group? g = groupe;
    if (g == null) {
      return Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: AppColors.primarySoft,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.person_outline_rounded,
          color: AppColors.primary,
        ),
      );
    }

    final Color accent = g.accent.color;
    final Widget repli = Container(
      width: 44,
      height: 44,
      color: accent.withValues(alpha: 0.16),
      alignment: Alignment.center,
      child: Text(
        g.name.isEmpty ? '?' : g.name.characters.first.toUpperCase(),
        style: AppTypography.h3.copyWith(color: accent),
      ),
    );

    return ClipOval(
      child: g.photoUrl == null
          ? repli
          : Image.network(
              g.photoUrl!,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => repli,
              loadingBuilder:
                  (BuildContext _, Widget enfant, ImageChunkEvent? p) =>
                      p == null ? enfant : repli,
            ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({
    required this.groupe,
    required this.choisi,
    required this.onTap,
  });

  final Group? groupe;
  final bool choisi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _Vignette(groupe: groupe),
      title: Text(groupe?.name ?? 'Personnel', style: AppTypography.body),
      subtitle: Text(
        groupe?.memberLabel ?? 'Vous seul le verrez',
        style: AppTypography.caption,
      ),
      trailing: choisi
          ? const Icon(Icons.check_rounded, color: AppColors.primary)
          : null,
      onTap: onTap,
    );
  }
}
