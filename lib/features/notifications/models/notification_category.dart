import 'package:flutter/material.dart';

import '../../../core/theme/jelvo_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../repository/push_repository.dart';

/// Les neuf types de notification, rangés en trois familles.
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
  groupes(Icons.forum_outlined, <String>['chat_message', 'group_invitation']),
  evenements(Icons.calendar_month_outlined, <String>[
    'event_invitation',
    'event_response',
    'event_changed',
    // L'anniversaire tient sa place ici parce que les familles suivent
    // **l'endroit où la chose se regarde**, et un anniversaire est une ligne
    // du calendrier. Une famille « Contacts » à un seul type aurait dit le
    // contraire : le carnet n'en montre pas la liste, et ne l'annonce pas.
    'birthday',
  ]),
  taches(Icons.check_circle_outline_rounded, <String>[
    'task_assigned',
    'task_response',
    'reminder',
  ]),
  autres(Icons.notifications_none_rounded, <String>[]);

  const NotificationCategory(this.icon, this.types);
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

  /// Le libellé est **demandé**, pas porté : une valeur d'énumération est
  /// `const`, et ne peut donc pas contenir un texte qui dépend de la langue.
  String label(AppTexts t) => switch (this) {
    NotificationCategory.groupes => t.notificationsGroupesDiscussions,
    NotificationCategory.evenements => 'Événements',
    NotificationCategory.taches => t.notificationsTachesRappels,
    NotificationCategory.autres => 'Autres',
  };
}

/// L'état d'une famille, tel que la ligne l'annonce.
enum CategoryState {
  toutes,
  partielles,
  aucune;

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

  /// Le libellé est **demandé**, pas porté : une valeur d'énumération est
  /// `const`, et ne peut donc pas contenir un texte qui dépend de la langue.
  String label(AppTexts t) => switch (this) {
    CategoryState.toutes => 'Activées',
    CategoryState.partielles => 'Partielles',
    CategoryState.aucune => 'Désactivées',
  };
}
