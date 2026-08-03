import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/avatar_stack.dart';
import '../models/contact.dart';
import '../repository/contact_repository.dart';

/// Dépôt des contacts. À surcharger dans les tests avec un faux dépôt.
final Provider<ContactRepository> contactRepositoryProvider =
    Provider<ContactRepository>((Ref ref) => InMemoryContactRepository());

/// Tous les contacts, triés par nom.
final StreamProvider<List<Contact>> contactsProvider =
    StreamProvider<List<Contact>>(
      (Ref ref) => ref.watch(contactRepositoryProvider).watchContacts(),
    );

/// Contacts marqués comme favoris.
final Provider<List<Contact>> favoriteContactsProvider =
    Provider<List<Contact>>((Ref ref) {
      final List<Contact> contacts =
          ref.watch(contactsProvider).value ?? const <Contact>[];
      return contacts.where((Contact c) => c.isFavorite).toList();
    });

/// Terme de recherche saisi dans l'écran Contacts.
final NotifierProvider<ContactQuery, String> contactQueryProvider =
    NotifierProvider<ContactQuery, String>(ContactQuery.new);

class ContactQuery extends Notifier<String> {
  @override
  String build() => '';

  void update(String value) => state = value;

  void clear() => state = '';
}

/// Contacts filtrés par [contactQueryProvider], sur le nom ou l'e-mail.
final Provider<List<Contact>> filteredContactsProvider =
    Provider<List<Contact>>((Ref ref) {
      final List<Contact> contacts =
          ref.watch(contactsProvider).value ?? const <Contact>[];
      final String query = ref.watch(contactQueryProvider).trim().toLowerCase();
      if (query.isEmpty) return contacts;

      return contacts.where((Contact c) {
        return c.fullName.toLowerCase().contains(query) ||
            (c.email?.toLowerCase().contains(query) ?? false);
      }).toList();
    });

/// Convertit des identifiants de contact en [AvatarData] pour `AvatarStack`.
///
/// C'est le seul endroit qui fait le pont entre le domaine et le design
/// system : les cartes restent ainsi indépendantes du modèle `Contact`.
final Provider<List<AvatarData> Function(Iterable<String>)>
avatarsForContactIdsProvider =
    Provider<List<AvatarData> Function(Iterable<String>)>((Ref ref) {
      final ContactRepository repository = ref.watch(contactRepositoryProvider);
      // On observe la liste pour que les consommateurs se reconstruisent lorsqu'un
      // contact est ajouté ou renommé.
      ref.watch(contactsProvider);

      return (Iterable<String> ids) => repository
          .findByIds(ids)
          .map(
            (Contact c) => AvatarData(name: c.fullName, imageUrl: c.avatarUrl),
          )
          .toList();
    });
