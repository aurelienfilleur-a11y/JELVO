import 'package:flutter/material.dart';

import '../../../core/theme/jelvo_colors.dart';

/// Ce que l'utilisateur peut créer depuis le bouton central « + ».
enum CreationKind {
  event(
    label: 'Événement',
    description: 'Un créneau dans votre agenda, seul ou partagé',
    icon: Icons.event_rounded,
  ),
  task(
    label: 'Tâche',
    description: 'Une action à faire, avec échéance et responsable',
    icon: Icons.check_circle_outline_rounded,
  ),
  group(
    label: 'Groupe',
    description: 'Un espace partagé avec vos proches ou vos amis',
    icon: Icons.groups_rounded,
  );

  const CreationKind({
    required this.label,
    required this.description,
    required this.icon,
  });

  final String label;
  final String description;
  final IconData icon;

  /// La couleur dépend du thème : elle ne peut plus être une donnée
  /// d'énumération, qui est constante par construction.
  Color color(JelvoColors c) => switch (this) {
    CreationKind.event => c.primary,
    CreationKind.task => c.success,
    CreationKind.group => c.warning,
  };

  /// Type porté par le paramètre d'URL de `/creer`.
  ///
  /// Une valeur absente ou inconnue renvoie `null` plutôt que de lever : une
  /// URL saisie à la main ne doit pas casser l'écran, elle doit seulement
  /// perdre sa pré-sélection.
  static CreationKind? fromParam(String? value) => switch (value) {
    'event' => CreationKind.event,
    'task' => CreationKind.task,
    'group' => CreationKind.group,
    _ => null,
  };
}
