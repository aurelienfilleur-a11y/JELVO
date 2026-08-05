import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../../router/app_routes.dart';
import '../../auth/models/auth_failure.dart';
import '../models/contact.dart';
import '../providers/contact_providers.dart';
import '../widgets/contact_tile.dart';

/// Écran Contacts : demandes reçues, favoris épinglés et carnet alphabétique.
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
    final AsyncValue<List<Contact>> contactsAsync = ref.watch(contactsProvider);
    final List<Contact> contacts = ref.watch(filteredContactsProvider);
    final List<Contact> requests = ref.watch(incomingRequestsProvider);
    final String query = ref.watch(contactQueryProvider);

    return AppScreen(
      title: 'Contacts',
      subtitle: 'Invitez vos proches à partager leurs disponibilités.',
      headerAction: AppScreenAction(
        icon: Icons.person_add_alt_rounded,
        tooltip: 'Ajouter un contact',
        onPressed: () => context.pushNamed(AppRoutes.addContact),
      ),
      slivers: <Widget>[
        SliverPadding(
          padding: AppSpacing.screenHorizontal,
          sliver: SliverToBoxAdapter(
            child: AppTextField(
              controller: _searchController,
              hint: 'Rechercher dans mes contacts',
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

        if (requests.isNotEmpty && query.isEmpty) ...<Widget>[
          _sectionHeader(
            title: 'Demandes reçues',
            subtitle:
                '${requests.length} personne'
                '${requests.length > 1 ? 's' : ''} souhaite'
                '${requests.length > 1 ? 'nt' : ''} vous ajouter',
          ),
          SliverPadding(
            padding: AppSpacing.screenHorizontal,
            sliver: SliverList.separated(
              itemCount: requests.length,
              separatorBuilder: (_, _) => AppSpacing.gapSm,
              itemBuilder: (BuildContext context, int index) {
                final Contact request = requests[index];
                return ContactTile(
                  contact: request,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        onPressed: () => _decline(request),
                        tooltip: 'Refuser',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _accept(request),
                        tooltip: 'Accepter',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.check_circle_rounded,
                          size: 22,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],

        _sectionHeader(
          title: query.isEmpty ? 'Mes contacts' : 'Résultats',
          subtitle:
              '${contacts.length} contact${contacts.length > 1 ? 's' : ''}',
        ),

        if (contactsAsync.isLoading && contacts.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (contactsAsync.hasError && contacts.isEmpty)
          SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Carnet indisponible',
              message: AuthFailure.from(contactsAsync.error!).message,
              actionLabel: 'Réessayer',
              onActionPressed: () =>
                  ref.read(contactsProvider.notifier).refresh(),
            ),
          )
        else if (contacts.isEmpty)
          SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.person_search_rounded,
              title: query.isEmpty ? 'Carnet vide' : 'Aucun résultat',
              message: query.isEmpty
                  ? 'Ajoutez vos proches par leur pseudo ou en scannant leur '
                        'QR code pour planifier ensemble.'
                  : 'Aucun contact ne correspond à « $query ».',
              actionLabel: query.isEmpty ? 'Ajouter un contact' : null,
              onActionPressed: query.isEmpty
                  ? () => context.pushNamed(AppRoutes.addContact)
                  : null,
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
                  onFavoriteToggled: () => _toggleFavorite(contact),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _sectionHeader({required String title, required String subtitle}) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        AppSpacing.xl,
        AppSpacing.screenMargin,
        AppSpacing.md,
      ),
      sliver: SliverToBoxAdapter(
        child: SectionHeader(title: title, subtitle: subtitle),
      ),
    );
  }

  Future<void> _accept(Contact contact) => _run(
    () => ref.read(contactActionsProvider).accept(contact.id),
    success: '${contact.shortName} fait maintenant partie de vos contacts.',
  );

  Future<void> _decline(Contact contact) => _run(
    () => ref.read(contactActionsProvider).decline(contact.id),
    success: 'Demande refusée.',
  );

  Future<void> _toggleFavorite(Contact contact) =>
      _run(() => ref.read(contactActionsProvider).toggleFavorite(contact));

  /// Exécute une écriture et traduit toute erreur en message français.
  Future<void> _run(Future<void> Function() action, {String? success}) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      if (success != null) {
        messenger.showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(AuthFailure.from(error).message)),
      );
    }
  }
}
