import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../models/contact.dart';
import '../providers/contact_providers.dart';
import '../widgets/contact_tile.dart';

/// Écran Contacts : recherche, favoris et carnet complet.
class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  // Le contrôleur est local à l'écran ; la valeur, elle, vit dans
  // `contactQueryProvider` pour que le filtrage reste testable sans widget.
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Contact> contacts = ref.watch(filteredContactsProvider);
    final List<Contact> favorites = ref.watch(favoriteContactsProvider);
    final String query = ref.watch(contactQueryProvider);

    return AppScreen(
      title: 'Contacts',
      subtitle: 'Invitez vos proches à partager leurs disponibilités.',
      headerAction: AppScreenAction(
        icon: Icons.person_add_alt_rounded,
        tooltip: 'Inviter un contact',
        onPressed: _showInviteSheet,
      ),
      slivers: <Widget>[
        SliverPadding(
          padding: AppSpacing.screenHorizontal,
          sliver: SliverToBoxAdapter(
            child: AppTextField(
              controller: _searchController,
              hint: 'Rechercher un contact',
              prefixIcon: Icons.search_rounded,
              textInputAction: TextInputAction.search,
              onChanged: ref.read(contactQueryProvider.notifier).update,
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      tooltip: 'Effacer',
                      onPressed: () {
                        _searchController.clear();
                        ref.read(contactQueryProvider.notifier).clear();
                      },
                    ),
            ),
          ),
        ),

        if (favorites.isNotEmpty && query.isEmpty) ...<Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenMargin,
              AppSpacing.xl,
              AppSpacing.screenMargin,
              AppSpacing.md,
            ),
            sliver: SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Favoris',
                subtitle:
                    '${favorites.length} contact'
                    '${favorites.length > 1 ? 's' : ''} épinglé'
                    '${favorites.length > 1 ? 's' : ''}',
              ),
            ),
          ),
          SliverPadding(
            padding: AppSpacing.screenHorizontal,
            sliver: SliverToBoxAdapter(
              child: AppCard(
                child: Row(
                  children: <Widget>[
                    AvatarStack(
                      avatars: favorites
                          .map(
                            (Contact c) => AvatarData(
                              name: c.fullName,
                              imageUrl: c.avatarUrl,
                            ),
                          )
                          .toList(),
                      size: 36,
                    ),
                    AppSpacing.hGapMd,
                    Expanded(
                      child: Text(
                        favorites.map((Contact c) => c.firstName).join(', '),
                        style: AppTypography.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            AppSpacing.xl,
            AppSpacing.screenMargin,
            AppSpacing.md,
          ),
          sliver: SliverToBoxAdapter(
            child: SectionHeader(
              title: query.isEmpty ? 'Tous les contacts' : 'Résultats',
              subtitle:
                  '${contacts.length} contact'
                  '${contacts.length > 1 ? 's' : ''}',
            ),
          ),
        ),

        if (contacts.isEmpty)
          SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.person_search_rounded,
              title: query.isEmpty ? 'Carnet vide' : 'Aucun résultat',
              message: query.isEmpty
                  ? 'Invitez vos proches pour commencer à planifier ensemble.'
                  : 'Aucun contact ne correspond à « $query ».',
              actionLabel: query.isEmpty ? 'Inviter un contact' : null,
              onActionPressed: query.isEmpty ? _showInviteSheet : null,
            ),
          )
        else
          SliverPadding(
            padding: AppSpacing.screenHorizontal,
            sliver: SliverList.separated(
              itemCount: contacts.length,
              separatorBuilder: (_, _) => AppSpacing.gapSm,
              itemBuilder: (BuildContext context, int index) {
                final Contact contact = contacts[index];
                return ContactTile(
                  contact: contact,
                  onFavoriteToggled: () => ref
                      .read(contactRepositoryProvider)
                      .toggleFavorite(contact.id),
                );
              },
            ),
          ),
      ],
    );
  }

  void _showInviteSheet() {
    final TextEditingController emailController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          // Remonte la feuille au-dessus du clavier.
          AppSpacing.xl + MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Inviter un contact', style: AppTypography.h2),
            AppSpacing.gapSm,
            Text(
              'Envoyez une invitation par e-mail pour partager vos '
              'disponibilités.',
              style: AppTypography.bodyMuted,
            ),
            AppSpacing.gapXl,
            AppTextField(
              label: 'Adresse e-mail',
              hint: 'prenom.nom@example.com',
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.mail_outline_rounded,
              autofocus: true,
            ),
            AppSpacing.gapXl,
            PrimaryButton(
              label: "Envoyer l'invitation",
              icon: Icons.send_rounded,
              onPressed: () {
                Navigator.of(sheetContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Les invitations arrivent bientôt.'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ).whenComplete(emailController.dispose);
  }
}
