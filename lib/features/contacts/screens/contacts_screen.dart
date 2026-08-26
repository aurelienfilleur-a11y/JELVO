import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../auth/models/auth_failure.dart';
import '../models/contact.dart';
import '../providers/contact_providers.dart';
import '../widgets/alphabet_index.dart';
import '../widgets/contact_sheets.dart';
import '../widgets/contact_tile.dart';
import '../widgets/favorites_strip.dart';

/// Écran Contacts : favoris en tête, puis le carnet rangé par lettre.
///
/// L'index alphabétique de droite saute par `Scrollable.ensureVisible` sur la
/// clé de l'en-tête visé. Cela suppose que les en-têtes soient **construits**,
/// donc une liste non paresseuse : c'est le prix, assumé, d'un saut exact. Un
/// carnet personnel tient dans quelques dizaines de lignes ; le jour où il en
/// compterait des milliers, il faudrait revenir à un calcul d'offset.
class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  // Le contrôleur est local à l'écran ; la valeur, elle, vit dans
  // `contactQueryProvider` pour que le filtrage reste testable sans widget.
  final TextEditingController _searchController = TextEditingController();

  /// Une clé par lettre, posée sur l'en-tête de section : c'est elle que vise
  /// le rail de droite.
  final Map<String, GlobalKey> _ancres = <String, GlobalKey>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Contact>> contactsAsync = ref.watch(contactsProvider);
    final List<ContactSection> sections = ref.watch(contactSectionsProvider);
    final List<Contact> favoris = ref.watch(favoriteContactsProvider);
    final List<Contact> tous = ref.watch(acceptedContactsProvider);
    final List<Contact> requests = ref.watch(incomingRequestsProvider);
    final List<String> lettres = ref.watch(contactLettersProvider);
    final ContactSort tri = ref.watch(contactSortProvider);
    final String query = ref.watch(contactQueryProvider);

    final int total = sections.fold<int>(
      0,
      (int n, ContactSection s) => n + s.contacts.length,
    );

    return Stack(
      children: <Widget>[
        AppScreen(
          title: 'Mes contacts',
          headerAction: AppScreenAction(
            icon: Icons.add_rounded,
            tooltip: 'Ajouter un contact',
            accented: true,
            onPressed: () => AddContactSheet.ouvrir(context),
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

            // La bande des favoris ne s'affiche pas pendant une recherche :
            // elle répondrait à une autre question que celle qu'on pose.
            if (query.isEmpty && tous.isNotEmpty) ...<Widget>[
              const SliverToBoxAdapter(child: AppSpacing.gapXl),
              SliverToBoxAdapter(
                child: FavoritesStrip(
                  favoris: favoris,
                  onGerer: () => ManageFavoritesSheet.ouvrir(context),
                  onTapContact: (Contact c) =>
                      ContactActionsSheet.ouvrir(context, c),
                ),
              ),
            ],

            if (requests.isNotEmpty && query.isEmpty) ...<Widget>[
              _entete(
                titre: 'Demandes reçues',
                sousTitre:
                    '${requests.length} personne'
                    '${requests.length > 1 ? 's' : ''} souhaite'
                    '${requests.length > 1 ? 'nt' : ''} vous ajouter',
              ),
              SliverPadding(
                padding: AppSpacing.screenHorizontal,
                sliver: SliverList.separated(
                  itemCount: requests.length,
                  separatorBuilder: (_, _) => AppSpacing.gapSm,
                  itemBuilder: (BuildContext context, int index) =>
                      _ligneDemande(requests[index]),
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
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        query.isEmpty ? 'Contacts' : 'Résultats',
                        style: AppTypography.h3,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: ref.read(contactSortProvider.notifier).toggle,
                      icon: Text(tri.label, style: AppTypography.caption),
                      label: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (contactsAsync.isLoading && total == 0)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (contactsAsync.hasError && total == 0)
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
            else if (total == 0)
              SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.person_search_rounded,
                  title: query.isEmpty ? 'Carnet vide' : 'Aucun résultat',
                  message: query.isEmpty
                      ? 'Ajoutez vos proches par leur pseudo ou en scannant '
                            'leur QR code pour planifier ensemble.'
                      : 'Aucun contact ne correspond à « $query ».',
                  actionLabel: query.isEmpty ? 'Ajouter un contact' : null,
                  onActionPressed: query.isEmpty
                      ? () => AddContactSheet.ouvrir(context)
                      : null,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.screenMargin,
                  // La gouttière de droite laisse la place au rail des
                  // lettres, qui flotte au-dessus de la liste.
                  right: AppSpacing.screenMargin + 20,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(<Widget>[
                    for (final ContactSection section in sections) ...<Widget>[
                      Padding(
                        key: _ancre(section.letter),
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.xs,
                          AppSpacing.md,
                          0,
                          AppSpacing.sm,
                        ),
                        child: Text(
                          section.letter,
                          // Clé de valeur en plus de l'ancre : la même lettre
                          // figure aussi dans le rail de droite, et les deux
                          // doivent pouvoir se distinguer.
                          key: ValueKey<String>('lettre-${section.letter}'),
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: AppTypography.semiBold,
                          ),
                        ),
                      ),
                      for (final Contact contact in section.contacts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: ContactTile(
                            contact: contact,
                            showSharedGroups: true,
                            showChevron: true,
                            onTap: () =>
                                ContactActionsSheet.ouvrir(context, contact),
                            onFavoriteToggled: () => _toggleFavorite(contact),
                          ),
                        ),
                    ],
                  ]),
                ),
              ),
          ],
        ),

        if (total > 0)
          Positioned(
            top: 0,
            bottom: 0,
            right: 2,
            width: 24,
            child: SafeArea(
              child: Center(
                child: SizedBox(
                  height: 320,
                  child: AlphabetIndex(lettres: lettres, onLettre: _sauterA),
                ),
              ),
            ),
          ),
      ],
    );
  }

  GlobalKey _ancre(String lettre) =>
      _ancres.putIfAbsent(lettre, () => GlobalKey());

  void _sauterA(String lettre) {
    final BuildContext? cible = _ancres[lettre]?.currentContext;
    if (cible == null) return;
    Scrollable.ensureVisible(
      cible,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      alignment: 0.05,
    );
  }

  Widget _ligneDemande(Contact request) {
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
  }

  Widget _entete({required String titre, required String sousTitre}) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        AppSpacing.xl,
        AppSpacing.screenMargin,
        AppSpacing.md,
      ),
      sliver: SliverToBoxAdapter(
        child: SectionHeader(title: titre, subtitle: sousTitre),
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
