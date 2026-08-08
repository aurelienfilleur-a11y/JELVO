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
  String? lastRespondedId;
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
  Future<void> respond({
    required String eventId,
    required EventResponse response,
  }) async {
    lastRespondedId = eventId;
    lastResponse = response;
  }

  @override
  Future<void> deleteEvent(String eventId) async =>
      _events.removeWhere((CalendarEvent e) => e.id == eventId);
}
