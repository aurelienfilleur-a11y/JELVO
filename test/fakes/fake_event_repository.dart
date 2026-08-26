import 'package:jelvo/features/calendar/models/calendar_event.dart';
import 'package:jelvo/features/calendar/repository/event_repository.dart';

/// Agenda en mémoire, pour les tests de widget.
///
/// Les dates sont calées sur l'horloge figée des tests — `DateTime(2026, 8, 3)`
/// — pour que « Aujourd'hui » et « Demain » restent vrais.
class FakeEventRepository implements EventRepository {
  FakeEventRepository({List<CalendarEvent>? events})
    : _events = List<CalendarEvent>.of(events ?? demoEvents());

  final List<CalendarEvent> _events;

  /// Dernier appel reçu, pour les assertions.
  String? lastCreatedTitle;
  String? lastCreatedGroupId;
  List<String>? lastCreatedParticipants;
  String? lastRespondedId;
  String? lastUpdatedTitle;
  String? lastDeletedId;
  EventResponse? lastResponse;

  static List<CalendarEvent> demoEvents() => <CalendarEvent>[
    CalendarEvent(
      id: 'e1',
      title: 'Brunch chez les parents',
      start: DateTime(2026, 8, 3, 9, 30),
      end: DateTime(2026, 8, 3, 11, 30),
      location: 'Chez Papi et Mamie',
      groupId: 'g1',
      myResponse: EventResponse.yes,
      participants: const <EventParticipant>[
        EventParticipant(
          userId: 'utilisateur-test',
          response: EventResponse.yes,
          name: 'Camille Rousseau',
        ),
        EventParticipant(
          userId: 'u2',
          response: EventResponse.pending,
          name: 'Léa Marchand',
        ),
      ],
      yesCount: 1,
    ),
    CalendarEvent(
      id: 'e2',
      title: 'Randonnée du lac Blanc',
      start: DateTime(2026, 8, 5, 8),
      end: DateTime(2026, 8, 5, 17),
      groupId: 'g2',
      myResponse: EventResponse.pending,
    ),
  ];

  @override
  Future<List<CalendarEvent>> fetchEvents({
    DateTime? from,
    DateTime? to,
    String? groupId,
  }) async => groupId == null
      ? List<CalendarEvent>.of(_events)
      : _events.where((CalendarEvent e) => e.groupId == groupId).toList();

  @override
  Future<CalendarEvent> createEvent({
    required String title,
    required DateTime startsAt,
    DateTime? endsAt,
    String? groupId,
    String? description,
    String? location,
    String? rrule,
    String? imageUrl,
    int? reminderMinutes,
    List<String>? participants,
  }) async {
    lastCreatedTitle = title;
    lastCreatedGroupId = groupId;
    lastCreatedParticipants = participants;
    final CalendarEvent event = CalendarEvent(
      id: 'e${_events.length + 1}',
      title: title,
      start: startsAt,
      end: endsAt ?? startsAt.add(const Duration(hours: 1)),
      groupId: groupId,
      notes: description,
      location: location,
      rrule: rrule,
      imageUrl: imageUrl,
      reminderMinutes: reminderMinutes,
      myResponse: EventResponse.yes,
    );
    _events.add(event);
    return event;
  }

  @override
  Future<CalendarEvent> updateEvent({
    required String eventId,
    required String title,
    required DateTime startsAt,
    DateTime? endsAt,
    String? description,
    String? location,
    String? rrule,
    String? imageUrl,
    int? reminderMinutes,
  }) async {
    lastUpdatedTitle = title;
    final int index = _events.indexWhere((CalendarEvent e) => e.id == eventId);
    final DateTime fin = endsAt ?? startsAt.add(const Duration(hours: 1));
    final CalendarEvent ancien = index == -1
        ? CalendarEvent(id: eventId, title: title, start: startsAt, end: fin)
        : _events[index];
    final CalendarEvent modifie = CalendarEvent(
      id: eventId,
      title: title,
      start: startsAt,
      end: fin,
      notes: description,
      location: location,
      groupId: ancien.groupId,
      ownerId: ancien.ownerId,
      rrule: rrule,
      imageUrl: imageUrl,
      reminderMinutes: reminderMinutes,
      myResponse: ancien.myResponse,
      participants: ancien.participants,
    );
    if (index == -1) {
      _events.add(modifie);
    } else {
      _events[index] = modifie;
    }
    return modifie;
  }

  @override
  Future<void> respond({
    required String eventId,
    required EventResponse response,
  }) async {
    lastRespondedId = eventId;
    lastResponse = response;
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    lastDeletedId = eventId;
    _events.removeWhere((CalendarEvent e) => e.id == eventId);
  }
}
