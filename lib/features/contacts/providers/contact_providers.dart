import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/avatar_stack.dart';
import '../../../data/supabase_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/contact.dart';
import '../repository/contact_repository.dart';

/// Dépôt des contacts. À surcharger dans les tests avec un faux dépôt.
final Provider<ContactRepository> contactRepositoryProvider =
    Provider<ContactRepository>(
      (Ref ref) => SupabaseContactRepository(ref.watch(supabaseClientProvider)),
    );

/// Carnet complet : relations acceptées et demandes en attente.
final AsyncNotifierProvider<ContactsNotifier, List<Contact>> contactsProvider =
    AsyncNotifierProvider<ContactsNotifier, List<Contact>>(
      ContactsNotifier.new,
    );

class ContactsNotifier extends AsyncNotifier<List<Contact>> {
  @override
  Future<List<Contact>> build() {
    ref.watch(authStatusProvider);
    return ref.watch(contactRepositoryProvider).fetchContacts();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(contactRepositoryProvider).fetchContacts(),
    );
  }
}

List<Contact> _all(Ref ref) =>
    ref.watch(contactsProvider).value ?? const <Contact>[];

/// Contacts confirmés, favoris en tête puis par ordre alphabétique.
final Provider<List<Contact>> acceptedContactsProvider =
    Provider<List<Contact>>(
      (Ref ref) => _all(ref).where((Contact c) => c.isAccepted).toList(),
    );

/// Demandes reçues, en attente de réponse.
final Provider<List<Contact>> incomingRequestsProvider =
    Provider<List<Contact>>(
      (Ref ref) => _all(ref).where((Contact c) => c.isIncomingRequest).toList(),
    );

/// Demandes envoyées, sans réponse pour l'instant.
final Provider<List<Contact>> outgoingRequestsProvider =
    Provider<List<Contact>>(
      (Ref ref) => _all(ref).where((Contact c) => c.isOutgoingRequest).toList(),
    );

/// Contacts marqués comme favoris, épinglés en tête de liste.
final Provider<List<Contact>> favoriteContactsProvider =
    Provider<List<Contact>>(
      (Ref ref) => ref
          .watch(acceptedContactsProvider)
          .where((Contact c) => c.isFavorite)
          .toList(),
    );

/// Sens du tri du carnet. Un seul bouton bascule entre les deux : c'est le
/// seul réglage de tri que la maquette propose, et deux valeurs n'ont pas
/// besoin d'un menu.
enum ContactSort {
  asc('A–Z'),
  desc('Z–A');

  const ContactSort(this.label);

  final String label;

  ContactSort get inverse =>
      this == ContactSort.asc ? ContactSort.desc : ContactSort.asc;
}

final NotifierProvider<ContactSortNotifier, ContactSort> contactSortProvider =
    NotifierProvider<ContactSortNotifier, ContactSort>(ContactSortNotifier.new);

class ContactSortNotifier extends Notifier<ContactSort> {
  @override
  ContactSort build() => ContactSort.asc;

  void toggle() => state = state.inverse;
}

/// Une section du carnet : une lettre, et ce qu'elle contient.
@immutable
class ContactSection {
  const ContactSection({required this.letter, required this.contacts});

  final String letter;
  final List<Contact> contacts;
}

/// Terme de recherche saisi dans l'écran Contacts.
final NotifierProvider<ContactQuery, String> contactQueryProvider =
    NotifierProvider<ContactQuery, String>(ContactQuery.new);

class ContactQuery extends Notifier<String> {
  @override
  String build() => '';

  void update(String value) => state = value;

  void clear() => state = '';
}

/// Carnet filtré par [contactQueryProvider], sur le nom ou le pseudo.
final Provider<List<Contact>> filteredContactsProvider =
    Provider<List<Contact>>((Ref ref) {
      final List<Contact> contacts = ref.watch(acceptedContactsProvider);
      final String query = ref.watch(contactQueryProvider).trim().toLowerCase();
      if (query.isEmpty) return contacts;

      return contacts.where((Contact c) {
        return c.fullName.toLowerCase().contains(query) ||
            (c.pseudo?.toLowerCase().contains(query) ?? false);
      }).toList();
    });

/// Le carnet filtré, trié, puis découpé par lettre.
///
/// Le regroupement vit ici et non dans l'écran : l'index alphabétique de
/// droite et la liste doivent lire **la même** découpe, faute de quoi une
/// lettre du rail pourrait ne correspondre à aucune section.
final Provider<List<ContactSection>> contactSectionsProvider =
    Provider<List<ContactSection>>((Ref ref) {
      final ContactSort tri = ref.watch(contactSortProvider);
      final List<Contact> contacts =
          List<Contact>.of(ref.watch(filteredContactsProvider))..sort(
            (Contact a, Contact b) => tri == ContactSort.asc
                ? a.sortKey.compareTo(b.sortKey)
                : b.sortKey.compareTo(a.sortKey),
          );

      final List<ContactSection> sections = <ContactSection>[];
      for (final Contact contact in contacts) {
        final String lettre = contact.indexLetter;
        if (sections.isNotEmpty && sections.last.letter == lettre) {
          sections.last.contacts.add(contact);
        } else {
          sections.add(
            ContactSection(letter: lettre, contacts: <Contact>[contact]),
          );
        }
      }
      return sections;
    });

/// Lettres réellement présentes, dans l'ordre du carnet.
///
/// Le rail ne montre que celles-là : une lettre sans contact serait une cible
/// qui ne mène nulle part.
final Provider<List<String>> contactLettersProvider = Provider<List<String>>(
  (Ref ref) => ref
      .watch(contactSectionsProvider)
      .map((ContactSection s) => s.letter)
      .toList(),
);

/// Recherche de nouveaux profils par pseudo, avec débounce de saisie.
// Riverpod 3 n'exporte pas les types `*Family` : on laisse l'inférence faire.
final pseudoSearchProvider = FutureProvider.autoDispose
    .family<List<ProfileSummary>, String>((Ref ref, String term) async {
      if (term.trim().length < 2) return const <ProfileSummary>[];

      await Future<void>.delayed(const Duration(milliseconds: 350));
      // Après le débounce, la frappe suivante a pu invalider ce provider.
      if (!ref.mounted) return const <ProfileSummary>[];

      return ref.read(contactRepositoryProvider).searchByPseudo(term);
    });

/// Convertit des identifiants de contact en [AvatarData] pour `AvatarStack`.
///
/// C'est le seul endroit qui fait le pont entre le domaine et le design
/// system : les cartes restent ainsi indépendantes du modèle `Contact`.
final Provider<List<AvatarData> Function(Iterable<String>)>
avatarsForContactIdsProvider =
    Provider<List<AvatarData> Function(Iterable<String>)>((Ref ref) {
      final List<Contact> contacts = ref.watch(acceptedContactsProvider);
      final Map<String, Contact> byId = <String, Contact>{
        for (final Contact c in contacts) c.id: c,
      };

      return (Iterable<String> ids) => ids
          .map((String id) => byId[id])
          .whereType<Contact>()
          .map(
            (Contact c) => AvatarData(name: c.fullName, imageUrl: c.avatarUrl),
          )
          .toList();
    });

/// Écritures sur le carnet.
final Provider<ContactActions> contactActionsProvider =
    Provider<ContactActions>(ContactActions.new);

class ContactActions {
  const ContactActions(this._ref);

  final Ref _ref;

  ContactRepository get _repository => _ref.read(contactRepositoryProvider);

  Future<ContactRequestOutcome> sendRequest(String userId) async {
    final ContactRequestOutcome outcome = await _repository.sendRequest(userId);
    await _refresh();
    return outcome;
  }

  Future<void> accept(String userId) async {
    await _repository.acceptRequest(userId);
    await _refresh();
  }

  Future<void> decline(String userId) async {
    await _repository.declineRequest(userId);
    await _refresh();
  }

  Future<void> remove(String userId) async {
    await _repository.removeContact(userId);
    await _refresh();
  }

  Future<void> toggleFavorite(Contact contact) async {
    await _repository.setFavorite(
      userId: contact.id,
      direction: contact.direction,
      value: !contact.isFavorite,
    );
    await _refresh();
  }

  Future<void> _refresh() => _ref.read(contactsProvider.notifier).refresh();
}
