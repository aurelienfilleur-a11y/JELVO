import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../contacts/models/contact.dart';
import '../../contacts/providers/contact_providers.dart';

/// Choix des personnes à inviter, dans l'écran de création d'un groupe.
///
/// **Le groupe et ses premiers membres se décident au même endroit.** Avant,
/// il fallait créer le groupe, ouvrir son écran, puis inviter — trois étapes
/// pour une seule intention, et un groupe vide entre-temps.
///
/// La rangée d'avatars est l'état d'ouverture, et la recherche ne sert qu'à
/// retrouver quelqu'un qu'elle ne montre pas : dans un carnet de quelques
/// dizaines de contacts, taper un nom est plus long que le reconnaître.
class GroupMemberPicker extends ConsumerStatefulWidget {
  const GroupMemberPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });

  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final bool enabled;

  @override
  ConsumerState<GroupMemberPicker> createState() => _GroupMemberPickerState();
}

class _GroupMemberPickerState extends ConsumerState<GroupMemberPicker> {
  final TextEditingController _recherche = TextEditingController();
  String _terme = '';

  /// Combien d'avatars la rangée propose avant de renvoyer à la recherche.
  static const int _suggestions = 12;

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Contact> contacts = _ordonnes(
      ref.watch(acceptedContactsProvider),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(
          title: 'Choisir dans mes contacts',
          subtitle: 'Les invitations partent à la création du groupe',
        ),
        AppSpacing.gapMd,

        if (contacts.isEmpty)
          _SansContact()
        else ...<Widget>[
          AppTextField(
            label: '',
            hint: 'Rechercher un contact',
            controller: _recherche,
            enabled: widget.enabled,
            prefixIcon: Icons.search_rounded,
            onChanged: (String valeur) =>
                setState(() => _terme = valeur.trim().toLowerCase()),
          ),
          AppSpacing.gapMd,

          if (_terme.isEmpty)
            _Rangee(
              contacts: contacts.take(_suggestions).toList(),
              selected: widget.selected,
              enabled: widget.enabled,
              onToggle: _basculer,
            )
          else
            _Resultats(
              contacts: _filtres(contacts),
              selected: widget.selected,
              enabled: widget.enabled,
              onToggle: _basculer,
            ),

          AppSpacing.gapMd,
          _Compteur(
            nombre: widget.selected.length,
            onClear: widget.enabled && widget.selected.isNotEmpty
                ? () => widget.onChanged(const <String>{})
                : null,
          ),
        ],
      ],
    );
  }

  /// Favoris d'abord : ce sont les personnes qu'on invite le plus souvent, et
  /// la rangée n'en montre qu'une douzaine.
  List<Contact> _ordonnes(List<Contact> contacts) {
    final List<Contact> copie = List<Contact>.of(contacts)
      ..sort((Contact a, Contact b) {
        if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
        return a.sortKey.compareTo(b.sortKey);
      });
    return copie;
  }

  List<Contact> _filtres(List<Contact> contacts) => contacts
      .where(
        (Contact c) =>
            c.fullName.toLowerCase().contains(_terme) ||
            (c.pseudo?.toLowerCase().contains(_terme) ?? false),
      )
      .toList();

  void _basculer(String id) {
    final Set<String> apres = Set<String>.of(widget.selected);
    if (!apres.remove(id)) apres.add(id);
    widget.onChanged(apres);
  }
}

/// Rangée d'avatars, état d'ouverture du sélecteur.
class _Rangee extends StatelessWidget {
  const _Rangee({
    required this.contacts,
    required this.selected,
    required this.enabled,
    required this.onToggle,
  });

  final List<Contact> contacts;
  final Set<String> selected;
  final bool enabled;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Hauteur réservée en dur : la rangée défile horizontalement et son
      // contenu ne peut pas mesurer sa propre hauteur dans un ListView.
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: contacts.length,
        separatorBuilder: (_, _) => AppSpacing.hGapMd,
        itemBuilder: (BuildContext context, int index) {
          final Contact contact = contacts[index];
          return _Pastille(
            contact: contact,
            index: index,
            choisi: selected.contains(contact.id),
            onTap: enabled ? () => onToggle(contact.id) : null,
          );
        },
      ),
    );
  }
}

/// Un avatar cliquable, avec son prénom dessous.
class _Pastille extends StatelessWidget {
  const _Pastille({
    required this.contact,
    required this.index,
    required this.choisi,
    required this.onTap,
  });

  final Contact contact;
  final int index;
  final bool choisi;
  final VoidCallback? onTap;

  static const double _taille = 56;

  @override
  Widget build(BuildContext context) {
    final AvatarData donnees = AvatarData(
      name: contact.fullName,
      imageUrl: contact.avatarUrl,
    );

    return Semantics(
      button: true,
      selected: choisi,
      label: contact.fullName,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: SizedBox(
          width: 68,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  AvatarImage(
                    data: donnees,
                    size: _taille,
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
                contact.shortName,
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

/// Résultats de recherche, en liste plutôt qu'en rangée : on cherche un nom,
/// on doit donc le lire en entier.
class _Resultats extends StatelessWidget {
  const _Resultats({
    required this.contacts,
    required this.selected,
    required this.enabled,
    required this.onToggle,
  });

  final List<Contact> contacts;
  final Set<String> selected;
  final bool enabled;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    if (contacts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text('Aucun contact à ce nom.', style: AppTypography.bodyMuted),
      );
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          for (final (int index, Contact contact) in contacts.indexed)
            CheckboxListTile(
              value: selected.contains(contact.id),
              onChanged: enabled ? (_) => onToggle(contact.id) : null,
              controlAffinity: ListTileControlAffinity.trailing,
              title: Text(contact.fullName, style: AppTypography.body),
              subtitle: contact.pseudo == null
                  ? null
                  : Text(contact.pseudoHandle, style: AppTypography.caption),
              secondary: _MiniAvatar(contact: contact, index: index),
            ),
        ],
      ),
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({required this.contact, required this.index});

  final Contact contact;
  final int index;

  @override
  Widget build(BuildContext context) {
    final AvatarData donnees = AvatarData(
      name: contact.fullName,
      imageUrl: contact.avatarUrl,
    );
    return AvatarImage(data: donnees, size: 40, index: index);
  }
}

class _Compteur extends StatelessWidget {
  const _Compteur({required this.nombre, required this.onClear});

  final int nombre;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            switch (nombre) {
              0 => 'Personne n’est invité pour l’instant.',
              1 => '1 personne sera invitée.',
              _ => '$nombre personnes seront invitées.',
            },
            style: AppTypography.caption.copyWith(
              color: nombre == 0 ? AppColors.textSecondary : AppColors.primary,
              fontWeight: nombre == 0 ? null : AppTypography.semiBold,
            ),
          ),
        ),
        if (onClear != null)
          TextButton(onPressed: onClear, child: const Text('Tout retirer')),
      ],
    );
  }
}

/// Un carnet vide n'est pas une erreur : il faut le dire, et dire par où
/// passer à la place, plutôt que d'afficher une rangée vide.
class _SansContact extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: AppRadii.fieldRadius,
      ),
      child: Text(
        'Votre carnet est vide pour l’instant. Vous pourrez inviter depuis '
        'l’écran du groupe, par lien de partage ou par pseudo.',
        style: AppTypography.caption.copyWith(color: AppColors.midnight),
      ),
    );
  }
}
