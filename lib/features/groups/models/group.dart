import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Couleur d'identité d'un groupe.
///
/// On stocke un enum plutôt qu'une `Color` brute : c'est sérialisable tel quel
/// et cela garantit que tout groupe reste dans la palette.
enum GroupAccent {
  violet(AppColors.primary),
  indigo(AppColors.primaryDark),
  green(AppColors.success),
  amber(AppColors.warning),
  red(AppColors.danger),
  midnight(AppColors.midnight);

  const GroupAccent(this.color);

  final Color color;
}

/// Un groupe partagé : famille, colocation, équipe, association…
@immutable
class Group {
  const Group({
    required this.id,
    required this.name,
    required this.memberIds,
    this.description,
    this.accent = GroupAccent.violet,
    this.icon = Icons.groups_rounded,
    this.upcomingEventCount = 0,
    this.openTaskCount = 0,
  });

  final String id;
  final String name;
  final String? description;

  /// Identifiants des contacts membres, résolus via `contactProviders`.
  final List<String> memberIds;

  final GroupAccent accent;
  final IconData icon;

  /// Compteurs dénormalisés, affichés sur la carte sans recharger l'agenda.
  final int upcomingEventCount;
  final int openTaskCount;

  int get memberCount => memberIds.length;

  /// Résumé affiché à droite de la carte, p. ex. « 2 événements · 3 tâches ».
  String get activityLabel {
    final List<String> parts = <String>[
      if (upcomingEventCount > 0)
        '$upcomingEventCount événement${upcomingEventCount > 1 ? 's' : ''}',
      if (openTaskCount > 0)
        '$openTaskCount tâche${openTaskCount > 1 ? 's' : ''}',
    ];
    return parts.isEmpty ? 'Rien de prévu' : parts.join(' · ');
  }

  Group copyWith({
    String? name,
    String? description,
    List<String>? memberIds,
    GroupAccent? accent,
    IconData? icon,
    int? upcomingEventCount,
    int? openTaskCount,
  }) {
    return Group(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      memberIds: memberIds ?? this.memberIds,
      accent: accent ?? this.accent,
      icon: icon ?? this.icon,
      upcomingEventCount: upcomingEventCount ?? this.upcomingEventCount,
      openTaskCount: openTaskCount ?? this.openTaskCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Group && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
