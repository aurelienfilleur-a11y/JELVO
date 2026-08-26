import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_text_field.dart';
import 'avatar_stack.dart';

/// Une personne qu'on peut désigner dans un formulaire.
///
/// Volontairement pauvre : un identifiant et de quoi l'afficher. C'est ce qui
/// permet à ce sélecteur de vivre dans `core` — il sert aussi bien les
/// assignés d'une tâche que les convives d'un événement, sans connaître ni
/// `GroupMember` ni `Contact`.
@immutable
class PickablePerson {
  const PickablePerson({
    required this.id,
    required this.name,
    required this.shortName,
    this.avatarUrl,
  });

  final String id;
  final String name;

  /// Le prénom seul, pour tenir sous un avatar de 56 dp.
  final String shortName;

  final String? avatarUrl;

  AvatarData get avatar => AvatarData(name: name, imageUrl: avatarUrl);
}

/// Rangée horizontale d'avatars sélectionnables.
///
/// La sélection se fait sur l'avatar lui-même : dans une famille, on reconnaît
/// un visage plus vite qu'on ne lit une liste déroulante. L'avatar choisi porte
/// un contour violet **et** une pastille de validation — deux signaux plutôt
/// qu'un, pour que le choix reste lisible sans la couleur.
class PersonAvatarRow extends StatelessWidget {
  const PersonAvatarRow({
    super.key,
    required this.personnes,
    required this.selection,
    required this.onToggle,
    this.onAutre,
  });

  final List<PickablePerson> personnes;
  final Set<String> selection;
  final ValueChanged<String> onToggle;

  /// Ouvre la liste complète. `null` masque le bouton « Autre » — il n'a de
  /// sens que si la rangée ne montre pas déjà tout le monde.
  final VoidCallback? onAutre;

  @override
  Widget build(BuildContext context) {
    final int total = personnes.length + (onAutre == null ? 0 : 1);

    return SizedBox(
      // Hauteur réservée en dur : la rangée défile horizontalement, et son
      // contenu ne peut pas mesurer sa propre hauteur dans un `ListView`.
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: total,
        separatorBuilder: (_, _) => AppSpacing.hGapMd,
        itemBuilder: (BuildContext context, int index) {
          if (index == personnes.length) {
            return _Autre(onTap: onAutre!);
          }
          final PickablePerson personne = personnes[index];
          return _Pastille(
            personne: personne,
            index: index,
            choisi: selection.contains(personne.id),
            onTap: () => onToggle(personne.id),
          );
        },
      ),
    );
  }
}

class _Pastille extends StatelessWidget {
  const _Pastille({
    required this.personne,
    required this.index,
    required this.choisi,
    required this.onTap,
  });

  final PickablePerson personne;
  final int index;
  final bool choisi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: choisi,
      label: personne.name,
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
                  AvatarImage(
                    data: personne.avatar,
                    size: 56,
                    index: index,
                    border: choisi
                        ? Border.all(color: AppColors.primary, width: 3)
                        : null,
                  ),
                  if (choisi)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
              AppSpacing.gapXs,
              Text(
                personne.shortName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(
                  color: choisi ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: choisi ? AppTypography.semiBold : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Le cercle « Autre » en bout de rangée.
class _Autre extends StatelessWidget {
  const _Autre({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Voir tous les membres',
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.cardRadius,
        child: SizedBox(
          width: 64,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.more_horiz_rounded,
                  color: AppColors.primary,
                ),
              ),
              AppSpacing.gapXs,
              Text(
                'Autre',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La liste complète, avec recherche, quand la rangée ne suffit plus.
///
/// Elle rend les **noms entiers** là où la rangée n'a la place que du prénom :
/// c'est ce qui la rend utile, et non le seul fait de tout montrer.
class PersonPickerSheet extends StatefulWidget {
  const PersonPickerSheet({
    super.key,
    required this.titre,
    required this.personnes,
    required this.selection,
    required this.onToggle,
    this.aide,
  });

  final String titre;
  final List<PickablePerson> personnes;
  final Set<String> selection;
  final ValueChanged<String> onToggle;
  final String? aide;

  /// Ouvre la feuille. Elle écrit au fil des touches : refermer vaut donc
  /// « j'ai fini », jamais « j'annule » — il n'y a rien à valider.
  static Future<void> ouvrir(
    BuildContext context, {
    required String titre,
    required List<PickablePerson> personnes,
    required Set<String> selection,
    required ValueChanged<String> onToggle,
    String? aide,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => PersonPickerSheet(
        titre: titre,
        personnes: personnes,
        selection: selection,
        onToggle: onToggle,
        aide: aide,
      ),
    );
  }

  @override
  State<PersonPickerSheet> createState() => _PersonPickerSheetState();
}

class _PersonPickerSheetState extends State<PersonPickerSheet> {
  final TextEditingController _recherche = TextEditingController();
  late final Set<String> _selection = Set<String>.of(widget.selection);
  String _terme = '';

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<PickablePerson> visibles = _terme.isEmpty
        ? widget.personnes
        : widget.personnes
              .where(
                (PickablePerson p) => p.name.toLowerCase().contains(_terme),
              )
              .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(widget.titre, style: AppTypography.h2),
                  if (widget.aide != null) ...<Widget>[
                    AppSpacing.gapXs,
                    Text(widget.aide!, style: AppTypography.bodyMuted),
                  ],
                  AppSpacing.gapMd,
                  AppTextField(
                    hint: 'Rechercher',
                    controller: _recherche,
                    prefixIcon: Icons.search_rounded,
                    onChanged: (String valeur) =>
                        setState(() => _terme = valeur.trim().toLowerCase()),
                  ),
                ],
              ),
            ),
            Flexible(
              child: visibles.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        'Personne à ce nom.',
                        style: AppTypography.bodyMuted,
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: visibles.length,
                      itemBuilder: (BuildContext context, int index) {
                        final PickablePerson personne = visibles[index];
                        return CheckboxListTile(
                          value: _selection.contains(personne.id),
                          controlAffinity: ListTileControlAffinity.trailing,
                          title: Text(personne.name, style: AppTypography.body),
                          secondary: AvatarImage(
                            data: personne.avatar,
                            size: 40,
                            index: index,
                          ),
                          onChanged: (_) {
                            widget.onToggle(personne.id);
                            setState(() {
                              if (!_selection.remove(personne.id)) {
                                _selection.add(personne.id);
                              }
                            });
                          },
                        );
                      },
                    ),
            ),
            AppSpacing.gapMd,
          ],
        ),
      ),
    );
  }
}
