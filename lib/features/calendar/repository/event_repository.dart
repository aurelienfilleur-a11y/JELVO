import '../../../data/in_memory_collection.dart';
import '../models/calendar_event.dart';

abstract interface class EventRepository {
  Stream<List<CalendarEvent>> watchEvents();

  CalendarEvent? findById(String id);

  void upsert(CalendarEvent event);

  void remove(String id);
}

class InMemoryEventRepository implements EventRepository {
  InMemoryEventRepository({Iterable<CalendarEvent>? seed, DateTime? anchor})
    : _collection = InMemoryCollection<CalendarEvent>(
        idOf: (CalendarEvent e) => e.id,
        seed: seed ?? demoEvents(anchor ?? DateTime.now()),
      );

  final InMemoryCollection<CalendarEvent> _collection;

  @override
  Stream<List<CalendarEvent>> watchEvents() => _collection.watch().map(
    // `items` est non modifiable : on trie une copie.
    (List<CalendarEvent> events) => List<CalendarEvent>.of(events)
      ..sort((CalendarEvent a, CalendarEvent b) => a.start.compareTo(b.start)),
  );

  @override
  CalendarEvent? findById(String id) => _collection.findById(id);

  @override
  void upsert(CalendarEvent event) => _collection.upsert(event);

  @override
  void remove(String id) => _collection.remove(id);

  /// Agenda de démonstration, positionné autour d'[anchor] pour que l'écran
  /// d'accueil ait toujours quelque chose à montrer, quelle que soit la date.
  ///
  /// Univers familial et amical : repas de famille, sport, anniversaires,
  /// voyage et colocation. L'univers professionnel est hors périmètre produit.
  static List<CalendarEvent> demoEvents(DateTime anchor) {
    final DateTime today = DateTime(anchor.year, anchor.month, anchor.day);
    DateTime at(int dayOffset, int hour, [int minute = 0]) => today
        .add(Duration(days: dayOffset))
        .add(Duration(hours: hour, minutes: minute));

    return <CalendarEvent>[
      CalendarEvent(
        id: 'e1',
        title: 'Brunch chez les parents',
        start: at(0, 9, 30),
        end: at(0, 11, 30),
        location: 'Chez Papi et Mamie',
        groupId: 'g1',
        participantIds: <String>['c1', 'c3', 'c7'],
      ),
      CalendarEvent(
        id: 'e2',
        title: 'Déjeuner avec Camille',
        start: at(0, 12, 30),
        end: at(0, 13, 30),
        location: 'Le Petit Comptoir',
        participantIds: <String>['c1'],
        status: EventStatus.pending,
      ),
      CalendarEvent(
        id: 'e3',
        title: 'Match de foot des enfants',
        start: at(0, 16),
        end: at(0, 17),
        location: 'Stade municipal',
        groupId: 'g1',
        participantIds: <String>['c3', 'c7'],
        status: EventStatus.conflict,
        notes: 'Chevauche le créneau de garde des enfants',
      ),
      CalendarEvent(
        id: 'e4',
        title: 'Séance de sport',
        start: at(1, 7, 30),
        end: at(1, 8, 30),
        location: 'Salle Fitness Park',
      ),
      CalendarEvent(
        id: 'e5',
        title: 'Anniversaire de Léa',
        start: at(1, 19),
        end: at(1, 23),
        location: 'Chez Léa',
        groupId: 'g1',
        participantIds: <String>['c1', 'c3', 'c7'],
      ),
      CalendarEvent(
        id: 'e6',
        title: 'Randonnée du lac Blanc',
        start: at(3, 8),
        end: at(3, 17),
        location: 'Chamonix',
        groupId: 'g3',
        participantIds: <String>['c4', 'c6', 'c1', 'c2'],
        status: EventStatus.pending,
      ),
      CalendarEvent(
        id: 'e7',
        title: 'Rendez-vous dentiste',
        start: at(4, 11),
        end: at(4, 11, 45),
        location: 'Cabinet Voltaire',
      ),
      CalendarEvent(
        id: 'e8',
        title: 'Soirée jeux à la coloc',
        start: at(6, 18, 30),
        end: at(6, 20),
        location: 'Coloc Bastille',
        groupId: 'g4',
        participantIds: <String>['c6', 'c4'],
        status: EventStatus.draft,
      ),
      CalendarEvent(
        id: 'e9',
        title: 'Départ pour la Corse',
        start: at(9, 7),
        end: at(9, 14),
        location: 'Port de Toulon',
        groupId: 'g2',
        participantIds: <String>['c2', 'c5', 'c4'],
        status: EventStatus.pending,
      ),
    ];
  }
}
