import 'package:flutter/foundation.dart';

import '../../../core/widgets/avatar_stack.dart';
import '../../../core/widgets/status_dot.dart';

/// Réponse d'un participant à un événement.
///
/// Reflète le type `event_response` de la base : `yes`, `no`, `maybe`,
/// `pending`.
enum EventResponse {
  yes('Oui', StatusTone.success),
  maybe('Peut-être', StatusTone.warning),
  no('Non', StatusTone.danger),
  pending('En attente', StatusTone.neutral);

  const EventResponse(this.label, this.tone);

  final String label;
  final StatusTone tone;

  static EventResponse fromDb(String? value) => switch (value) {
    'yes' => EventResponse.yes,
    'no' => EventResponse.no,
    'maybe' => EventResponse.maybe,
    _ => EventResponse.pending,
  };

  String get dbValue => name;
}

/// Un participant, avec son profil et sa réponse.
@immutable
class EventParticipant {
  const EventParticipant({
    required this.userId,
    required this.response,
    this.name,
    this.avatarUrl,
  });

  factory EventParticipant.fromJson(Map<String, dynamic> json) {
    return EventParticipant(
      userId: json['user_id'] as String,
      response: EventResponse.fromDb(json['response'] as String?),
      name: json['nom'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  final String userId;
  final EventResponse response;
  final String? name;
  final String? avatarUrl;

  String get displayName => name ?? 'Membre';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventParticipant && other.userId == userId);

  @override
  int get hashCode => userId.hashCode;
}

/// Un créneau de l'agenda, partagé avec un groupe ou strictement personnel.
@immutable
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.location,
    this.groupId,
    this.ownerId,
    this.notes,
    this.rrule,
    this.imageUrl,
    this.reminderMinutes,
    this.myResponse = EventResponse.pending,
    this.participants = const <EventParticipant>[],
    this.yesCount = 0,
  });

  factory CalendarEvent.fromRow(Map<String, dynamic> row) {
    final Object? bruts = row['participants'];
    final DateTime start =
        DateTime.tryParse((row['starts_at'] as String?) ?? '')?.toLocal() ??
        DateTime.now();
    return CalendarEvent(
      id: row['id'] as String,
      title: (row['title'] as String?) ?? '',
      start: start,
      end:
          DateTime.tryParse((row['ends_at'] as String?) ?? '')?.toLocal() ??
          start.add(const Duration(hours: 1)),
      location: row['location'] as String?,
      groupId: row['group_id'] as String?,
      ownerId: row['owner_id'] as String?,
      notes: row['description'] as String?,
      rrule: row['rrule'] as String?,
      imageUrl: row['image_url'] as String?,
      reminderMinutes: row['reminder_minutes'] as int?,
      myResponse: EventResponse.fromDb(row['ma_reponse'] as String?),
      participants: bruts is List
          ? bruts
                .whereType<Map<String, dynamic>>()
                .map(EventParticipant.fromJson)
                .toList()
          : const <EventParticipant>[],
      yesCount: (row['nombre_oui'] as int?) ?? 0,
    );
  }

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final String? location;

  /// Groupe organisateur, `null` pour un rendez-vous personnel.
  final String? groupId;

  final String? ownerId;
  final String? notes;
  final String? rrule;
  final String? imageUrl;

  /// Délai de rappel avant le début, en minutes.
  final int? reminderMinutes;

  final EventResponse myResponse;
  final List<EventParticipant> participants;
  final int yesCount;

  Duration get duration => end.difference(start);

  /// Un rendez-vous personnel n'est visible que de son propriétaire.
  bool get isPersonal => groupId == null;

  bool get isRecurring => rrule != null && rrule!.isNotEmpty;

  List<String> get participantIds =>
      participants.map((EventParticipant p) => p.userId).toList();

  /// Conversion domaine → design system, faite ici plutôt que dans chaque
  /// écran : `AvatarStack` ne connaît pas `EventParticipant`.
  List<AvatarData> get avatars => participants
      .map(
        (EventParticipant p) =>
            AvatarData(name: p.displayName, imageUrl: p.avatarUrl),
      )
      .toList();

  /// Vrai si l'événement chevauche le jour calendaire [day].
  bool occursOn(DateTime day) {
    final DateTime dayStart = DateTime(day.year, day.month, day.day);
    final DateTime dayEnd = dayStart.add(const Duration(days: 1));
    return start.isBefore(dayEnd) && end.isAfter(dayStart);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is CalendarEvent && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
