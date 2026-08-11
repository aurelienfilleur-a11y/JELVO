import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/status_dot.dart';

/// Ce qu'une ligne de la journée représente.
///
/// Le calendrier agrège quatre sources qui n'ont ni la même table ni la même
/// forme ; les réduire à un type commun est ce qui permet de les trier ensemble
/// par heure, ce qu'une liste par source ne saurait pas faire.
enum AgendaEntryKind {
  /// Événement d'un groupe.
  groupEvent,

  /// Rendez-vous personnel : sans groupe, visible de son seul propriétaire.
  personalEvent,

  /// Tâche datée, placée à l'heure de son échéance.
  task,

  /// Créneau de disponibilité déclaré, en fond de journée.
  availability,
}

/// Une ligne de la timeline du jour.
@immutable
class AgendaEntry {
  const AgendaEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.start,
    required this.end,
    required this.accent,
    this.subtitle,
    this.timeLabel,
    this.statusTone,
    this.statusLabel,
    this.groupId,
  });

  final String id;
  final AgendaEntryKind kind;
  final String title;

  /// Instants réels ; pour une tâche, début et fin valent l'échéance.
  final DateTime start;
  final DateTime end;

  final Color accent;

  /// Groupe, lieu, ou ce qui situe la ligne. Jamais obligatoire.
  final String? subtitle;

  /// Heure affichée dans la gouttière. Calculée à la construction pour que le
  /// widget n'ait pas à connaître `AppDates`.
  final String? timeLabel;

  final StatusTone? statusTone;
  final String? statusLabel;

  final String? groupId;

  /// Un créneau de disponibilité n'ouvre rien : il n'a pas d'écran de détail,
  /// et le toucher ne doit donc pas laisser croire le contraire.
  bool get isOpenable => kind != AgendaEntryKind.availability;

  /// Fond teinté des créneaux, qui doivent rester en retrait des événements.
  Color get background => switch (kind) {
    AgendaEntryKind.availability => AppColors.background,
    _ => AppColors.surface,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AgendaEntry && other.id == id && other.kind == kind);

  @override
  int get hashCode => Object.hash(id, kind);
}
