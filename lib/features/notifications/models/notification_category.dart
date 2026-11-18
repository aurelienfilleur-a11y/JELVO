import 'package:flutter/material.dart';

import '../../../core/theme/jelvo_colors.dart';
import '../repository/push_repository.dart';

/// Les huit types de notification, rangés en trois familles.
///
/// La maquette montre une ligne par famille, pas une par type : huit
/// interrupteurs d'affilée se lisent mal, et trois lignes qui annoncent leur
/// état — « Activées », « Partielles », « Désactivées » — disent l'essentiel
/// sans rien cacher, le détail restant à une touche.
///
/// **Aucun type n'est perdu ni fusionné en base** : `types_de_notification()`
/// reste seule source, et une famille n'est qu'une liste de ses noms. Un type
/// que ce regroupement oublierait apparaîtrait dans [autres], plutôt que de
/// devenir muet.
enum NotificationCategory {
  groupes('Groupes et discussions', Icons.forum_outlined, <String>[
    'chat_message',
    'group_invitation',
  ]),
  evenements('Événements', Icons.calendar_month_outlined, <String>[
    'event_invitation',
    'event_response',
    'event_changed',
  ]),
  taches('Tâches et rappels', Icons.check_circle_outline_rounded, <String>[
    'task_assigned',
    'task_response',
    'reminder',
  ]),
  autres('Autres', Icons.notifications_none_rounded, <String>[]);

  const NotificationCategory(this.label, this.icon, this.types);

  final String label;
  final IconData icon;

  /// Les types de `types_de_notification()` que cette famille couvre.
  /// Vide pour [autres], qui recueille tout le reste.
  final List<String> types;

  /// Les familles proposées à l'écran, [autres] comprise **si** elle a
  /// quelque chose à montrer.
  static List<NotificationCategory> visibles(
    List<NotificationPreference> preferences,
  ) => <NotificationCategory>[
    for (final NotificationCategory c in values)
      if (c.preferencesDe(preferences).isNotEmpty) c,
  ];

  List<NotificationPreference> preferencesDe(
    List<NotificationPreference> toutes,
  ) {
    if (this != NotificationCategory.autres) {
      return <NotificationPreference>[
        for (final NotificationPreference p in toutes)
          if (types.contains(p.type)) p,
      ];
    }
    // Tout ce qu'aucune famille ne réclame : un type ajouté en base sans
    // toucher à ce fichier reste réglable au lieu de disparaître.
    final Set<String> connus = <String>{
      for (final NotificationCategory c in values) ...c.types,
    };
    return <NotificationPreference>[
      for (final NotificationPreference p in toutes)
        if (!connus.contains(p.type)) p,
    ];
  }
}

/// L'état d'une famille, tel que la ligne l'annonce.
enum CategoryState {
  toutes('Activées'),
  partielles('Partielles'),
  aucune('Désactivées');

  const CategoryState(this.label);

  final String label;

  /// Un mot d'état, donc du **texte** : c'est la variante encrée qui le porte.
  Color color(JelvoColors c) => switch (this) {
    CategoryState.toutes => c.primaryInk,
    CategoryState.partielles => c.warningInk,
    CategoryState.aucune => c.textSecondary,
  };

  static CategoryState depuis(List<NotificationPreference> preferences) {
    if (preferences.isEmpty) return CategoryState.aucune;
    final int actives = preferences
        .where((NotificationPreference p) => p.enabled)
        .length;
    if (actives == preferences.length) return CategoryState.toutes;
    return actives == 0 ? CategoryState.aucune : CategoryState.partielles;
  }
}
