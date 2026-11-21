import 'package:flutter/material.dart';

import '../../../core/theme/jelvo_colors.dart';
import '../../../l10n/app_localizations.dart';

/// Ce que l'utilisateur peut créer depuis le bouton central « + ».
enum CreationKind {
  event(Icons.event_rounded),
  task(Icons.check_circle_outline_rounded),
  group(Icons.groups_rounded);

  const CreationKind(this.icon);

  final IconData icon;

  /// Le libellé dépend de la langue : il ne peut pas être une donnée
  /// d'énumération, qui est constante par construction — même raison que la
  /// couleur juste en dessous.
  String label(AppTexts t) => switch (this) {
    CreationKind.event => t.createEvenement,
    CreationKind.task => t.createTache,
    CreationKind.group => t.createGroupe,
  };

  String description(AppTexts t) => switch (this) {
    CreationKind.event => t.createCreneauAgendaSeulPartage,
    CreationKind.task => t.createActionFaireEcheanceResponsable,
    CreationKind.group => t.createEspacePartageProchesAmis,
  };

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
