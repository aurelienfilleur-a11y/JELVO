import 'package:flutter/foundation.dart';

import '../../../core/widgets/status_dot.dart';

/// État de confirmation d'un événement partagé.
enum EventStatus {
  confirmed('Confirmé', StatusTone.success),
  pending('En attente', StatusTone.warning),
  conflict('Conflit', StatusTone.danger),
  draft('Brouillon', StatusTone.neutral);

  const EventStatus(this.label, this.tone);

  final String label;
  final StatusTone tone;
}

/// Un créneau de l'agenda, personnel ou rattaché à un groupe.
@immutable
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.location,
    this.groupId,
    this.participantIds = const <String>[],
    this.status = EventStatus.confirmed,
    this.isAllDay = false,
    this.notes,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final String? location;

  /// Groupe organisateur, `null` pour un événement personnel.
  final String? groupId;

  final List<String> participantIds;
  final EventStatus status;
  final bool isAllDay;
  final String? notes;

  Duration get duration => end.difference(start);

  bool get isPersonal => groupId == null;

  /// Vrai si l'événement chevauche le jour calendaire [day].
  bool occursOn(DateTime day) {
    final DateTime dayStart = DateTime(day.year, day.month, day.day);
    final DateTime dayEnd = dayStart.add(const Duration(days: 1));
    return start.isBefore(dayEnd) && end.isAfter(dayStart);
  }

  CalendarEvent copyWith({
    String? title,
    DateTime? start,
    DateTime? end,
    String? location,
    String? groupId,
    List<String>? participantIds,
    EventStatus? status,
    bool? isAllDay,
    String? notes,
  }) {
    return CalendarEvent(
      id: id,
      title: title ?? this.title,
      start: start ?? this.start,
      end: end ?? this.end,
      location: location ?? this.location,
      groupId: groupId ?? this.groupId,
      participantIds: participantIds ?? this.participantIds,
      status: status ?? this.status,
      isAllDay: isAllDay ?? this.isAllDay,
      notes: notes ?? this.notes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is CalendarEvent && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
