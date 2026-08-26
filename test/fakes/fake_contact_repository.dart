import 'package:jelvo/features/contacts/models/contact.dart';
import 'package:jelvo/features/contacts/repository/contact_repository.dart';

/// Carnet de contacts en mémoire, pour les tests de widget.
class FakeContactRepository implements ContactRepository {
  FakeContactRepository({
    List<Contact>? contacts,
    List<ProfileSummary>? profiles,
  }) : _contacts = List<Contact>.of(contacts ?? demoContacts),
       _profiles = List<ProfileSummary>.of(profiles ?? demoProfiles);

  final List<Contact> _contacts;
  final List<ProfileSummary> _profiles;

  /// Dernier appel reçu, pour les assertions.
  String? lastRequestedUserId;
  String? lastAcceptedUserId;
  String? lastDeclinedUserId;
  String? lastRemovedUserId;
  bool? lastFavoriteValue;

  static const List<Contact> demoContacts = <Contact>[
    Contact(
      id: 'u2',
      pseudo: 'lea.marchand',
      firstName: 'Léa',
      lastName: 'Marchand',
      isFavorite: true,
      sharedGroups: 3,
    ),
    Contact(
      id: 'u3',
      pseudo: 'yanis.bertrand',
      firstName: 'Yanis',
      lastName: 'Bertrand',
      sharedGroups: 1,
    ),
    Contact(
      id: 'u4',
      pseudo: 'noah.delacroix',
      firstName: 'Noah',
      lastName: 'Delacroix',
      status: ContactStatus.pending,
      direction: ContactDirection.incoming,
    ),
  ];

  static const List<ProfileSummary> demoProfiles = <ProfileSummary>[
    ProfileSummary(
      id: 'u5',
      pseudo: 'sarah.nguyen',
      firstName: 'Sarah',
      lastName: 'Nguyen',
    ),
  ];

  @override
  Future<List<Contact>> fetchContacts() async {
    final List<Contact> contacts = List<Contact>.of(_contacts);
    contacts.sort((Contact a, Contact b) {
      if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
      return a.sortKey.compareTo(b.sortKey);
    });
    return contacts;
  }

  @override
  Future<List<ProfileSummary>> searchByPseudo(String term) async {
    final String needle = term.trim().toLowerCase();
    if (needle.length < 2) return const <ProfileSummary>[];
    return _profiles
        .where((ProfileSummary p) => p.pseudo.startsWith(needle))
        .toList();
  }

  @override
  Future<ContactRequestOutcome> sendRequest(String userId) async {
    lastRequestedUserId = userId;
    return ContactRequestOutcome.envoyee;
  }

  @override
  Future<void> acceptRequest(String userId) async {
    lastAcceptedUserId = userId;
    final int index = _contacts.indexWhere((Contact c) => c.id == userId);
    if (index != -1) {
      _contacts[index] = _contacts[index].copyWith(
        status: ContactStatus.accepted,
      );
    }
  }

  @override
  Future<void> declineRequest(String userId) async {
    lastDeclinedUserId = userId;
    await removeContact(userId);
  }

  @override
  Future<void> removeContact(String userId) async {
    lastRemovedUserId = userId;
    _contacts.removeWhere((Contact c) => c.id == userId);
  }

  @override
  Future<void> setFavorite({
    required String userId,
    required ContactDirection direction,
    required bool value,
  }) async {
    lastFavoriteValue = value;
    final int index = _contacts.indexWhere((Contact c) => c.id == userId);
    if (index != -1) {
      _contacts[index] = _contacts[index].copyWith(isFavorite: value);
    }
  }
}
