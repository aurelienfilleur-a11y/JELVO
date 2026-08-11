import 'package:flutter/foundation.dart';

import '../../../core/widgets/status_dot.dart';

/// Forme d'un créneau. Reflète le type `availability_kind` du schéma initial.
enum AvailabilityKind {
  recurring('Chaque semaine'),
  exception('Une date précise');

  const AvailabilityKind(this.label);

  final String label;

  String get dbValue => name;

  static AvailabilityKind fromDb(String? value) => value == 'exception'
      ? AvailabilityKind.exception
      : AvailabilityKind.recurring;
}

/// Ce qu'un créneau déclare. Reflète `availability_status`, qui ne connaît que
/// ces deux valeurs — « inconnu » n'est pas un état stocké mais l'absence de
/// réponse, et n'existe donc que pour autrui.
enum AvailabilityStatus {
  available('Disponible', StatusTone.success),
  unavailable('Indisponible', StatusTone.danger);

  const AvailabilityStatus(this.label, this.tone);

  final String label;
  final StatusTone tone;

  String get dbValue => name;

  static AvailabilityStatus fromDb(String? value) => value == 'unavailable'
      ? AvailabilityStatus.unavailable
      : AvailabilityStatus.available;
}

/// Ce que l'on sait de la disponibilité de **quelqu'un d'autre**.
///
/// Trois états, et rien de plus : ni l'heure, ni la raison, ni le créneau.
/// C'est `get_availability_status` qui tranche, côté base, et la règle de
/// visibilité — contacts et co-membres seulement — lui appartient. `inconnu`
/// couvre aussi bien « rien de déclaré » que « vous n'avez pas à le savoir »,
/// et les distinguer serait déjà en dire trop.
enum PeerAvailability {
  available('Disponible', StatusTone.success),
  unavailable('Indisponible', StatusTone.danger),
  unknown('Inconnu', StatusTone.neutral);

  const PeerAvailability(this.label, this.tone);

  final String label;
  final StatusTone tone;

  static PeerAvailability fromDb(String? value) => switch (value) {
    'available' => PeerAvailability.available,
    'unavailable' => PeerAvailability.unavailable,
    _ => PeerAvailability.unknown,
  };
}

/// Un créneau de disponibilité, tel que son propriétaire le voit.
@immutable
class AvailabilitySlot {
  const AvailabilitySlot({
    required this.id,
    required this.kind,
    required this.status,
    required this.start,
    required this.end,
    this.weekday,
    this.onDate,
  });

  factory AvailabilitySlot.fromRow(Map<String, dynamic> row) {
    return AvailabilitySlot(
      id: row['id'] as String,
      kind: AvailabilityKind.fromDb(row['kind'] as String?),
      status: AvailabilityStatus.fromDb(row['status'] as String?),
      start: parseHeure(row['start_time'] as String?),
      end: parseHeure(row['end_time'] as String?),
      weekday: row['weekday'] as int?,
      onDate: DateTime.tryParse((row['on_date'] as String?) ?? ''),
    );
  }

  final String id;
  final AvailabilityKind kind;
  final AvailabilityStatus status;

  /// Heures locales, en minutes depuis minuit. PostgreSQL renvoie `time`
  /// comme « 09:00:00 » ; on ne garde que ce qui sert à afficher et à trier.
  final int start;
  final int end;

  /// Jour de la semaine d'un créneau récurrent, `null` pour une exception.
  ///
  /// **Convention ISO : 1 = lundi … 7 = dimanche**, la même que
  /// `DateTime.weekday` de Dart. Le schéma initial stocke un entier sans dire
  /// lequel ; l'application est cohérente avec elle-même, et cette constante
  /// est le seul endroit à changer si la base attendait `extract(dow)`, où
  /// dimanche vaut 0.
  final int? weekday;

  /// Date d'un créneau exceptionnel, `null` pour un récurrent.
  final DateTime? onDate;

  static const List<String> nomsDeJour = <String>[
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];

  static String nomDuJour(int weekday) => nomsDeJour[(weekday - 1).clamp(0, 6)];

  /// « 09:00 » à partir de minutes depuis minuit.
  static String formaterHeure(int minutes) {
    final String h = (minutes ~/ 60).toString().padLeft(2, '0');
    final String m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// « 09:00:00 » ou « 09:00 » → minutes depuis minuit.
  static int parseHeure(String? valeur) {
    final List<String> morceaux = (valeur ?? '').split(':');
    if (morceaux.length < 2) return 0;
    final int h = int.tryParse(morceaux[0]) ?? 0;
    final int m = int.tryParse(morceaux[1]) ?? 0;
    return h * 60 + m;
  }

  String get plage => '${formaterHeure(start)} – ${formaterHeure(end)}';

  Duration get duree => Duration(minutes: end - start);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AvailabilitySlot && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
