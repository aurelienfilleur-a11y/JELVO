import '../../../data/in_memory_collection.dart';
import '../models/contact.dart';

/// Accès aux contacts.
///
/// L'implémentation est pour l'instant purement locale ; l'interface est
/// néanmoins définie à part pour qu'un futur `ApiContactRepository` puisse s'y
/// substituer sans toucher aux providers.
abstract interface class ContactRepository {
  Stream<List<Contact>> watchContacts();

  Contact? findById(String id);

  List<Contact> findByIds(Iterable<String> ids);

  void toggleFavorite(String id);

  void upsert(Contact contact);

  void remove(String id);
}

class InMemoryContactRepository implements ContactRepository {
  InMemoryContactRepository({Iterable<Contact>? seed})
    : _collection = InMemoryCollection<Contact>(
        idOf: (Contact c) => c.id,
        seed: seed ?? demoContacts,
      );

  final InMemoryCollection<Contact> _collection;

  @override
  Stream<List<Contact>> watchContacts() => _collection.watch().map(
    // `items` est non modifiable : on trie une copie.
    (List<Contact> contacts) =>
        List<Contact>.of(contacts)
          ..sort((Contact a, Contact b) => a.fullName.compareTo(b.fullName)),
  );

  @override
  Contact? findById(String id) => _collection.findById(id);

  @override
  List<Contact> findByIds(Iterable<String> ids) =>
      ids.map(_collection.findById).whereType<Contact>().toList();

  @override
  void toggleFavorite(String id) => _collection.mutate(
    id,
    (Contact c) => c.copyWith(isFavorite: !c.isFavorite),
  );

  @override
  void upsert(Contact contact) => _collection.upsert(contact);

  @override
  void remove(String id) => _collection.remove(id);

  /// Jeu de données de démonstration, affiché tant qu'aucun backend n'est
  /// branché. Univers familial et amical : proches, colocataires et amis de
  /// rando ou de voyage.
  static const List<Contact> demoContacts = <Contact>[
    Contact(
      id: 'c1',
      fullName: 'Camille Rousseau',
      email: 'camille.rousseau@example.com',
      phone: '+33 6 12 34 56 78',
      relation: ContactRelation.friend,
      isFavorite: true,
      sharesCalendar: true,
    ),
    Contact(
      id: 'c2',
      fullName: 'Yanis Bertrand',
      email: 'yanis.bertrand@example.com',
      relation: ContactRelation.friend,
      sharesCalendar: true,
    ),
    Contact(
      id: 'c3',
      fullName: 'Léa Marchand',
      email: 'lea.marchand@example.com',
      phone: '+33 6 98 76 54 32',
      relation: ContactRelation.family,
      isFavorite: true,
    ),
    Contact(
      id: 'c4',
      fullName: 'Noah Delacroix',
      email: 'noah.delacroix@example.com',
      relation: ContactRelation.roommate,
    ),
    Contact(
      id: 'c5',
      fullName: 'Inès Fontaine',
      email: 'ines.fontaine@example.com',
      relation: ContactRelation.family,
      sharesCalendar: true,
    ),
    Contact(
      id: 'c6',
      fullName: 'Théo Lambert',
      relation: ContactRelation.roommate,
    ),
    Contact(
      id: 'c7',
      fullName: 'Sarah Nguyen',
      email: 'sarah.nguyen@example.com',
      relation: ContactRelation.family,
    ),
  ];
}
