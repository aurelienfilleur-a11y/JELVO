import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Ce que l'utilisateur peut créer depuis le bouton central « + ».
enum CreationKind {
  event(
    label: 'Événement',
    description: 'Un créneau dans votre agenda, seul ou partagé',
    icon: Icons.event_rounded,
    color: AppColors.primary,
  ),
  task(
    label: 'Tâche',
    description: 'Une action à faire, avec échéance et responsable',
    icon: Icons.check_circle_outline_rounded,
    color: AppColors.success,
  ),
  group(
    label: 'Groupe',
    description: 'Un espace partagé avec vos proches ou vos collègues',
    icon: Icons.groups_rounded,
    color: AppColors.warning,
  );

  const CreationKind({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String label;
  final String description;
  final IconData icon;
  final Color color;
}
