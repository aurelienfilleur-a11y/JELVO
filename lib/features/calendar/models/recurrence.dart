import '../../../l10n/app_localizations.dart';

/// Récurrence et rappel, partagés par les tâches et les événements.
///
/// Le schéma stocke une `rrule` (RFC 5545) sur `tasks` comme sur `events`.
/// L'application n'en propose que les quelques cas courants d'un agenda
/// familial : la grammaire complète — `BYSETPOS`, `UNTIL`, exceptions — n'a pas
/// d'usage ici et n'aurait pas d'interface raisonnable.
///
/// Une `rrule` écrite ailleurs et non reconnue tombe sur [Recurrence.aucune]
/// **sans être effacée** : les écrans ne réécrivent la valeur que si
/// l'utilisateur touche au sélecteur.
enum Recurrence {
  aucune(null),
  quotidienne('FREQ=DAILY'),
  hebdomadaire('FREQ=WEEKLY'),
  bimensuelle('FREQ=WEEKLY;INTERVAL=2'),
  mensuelle('FREQ=MONTHLY'),
  annuelle('FREQ=YEARLY');

  const Recurrence(this.rrule);

  /// La `rrule` reste dans l'énumération : c'est une valeur de la base, pas un
  /// mot d'interface, et elle ne se traduit pas.
  final String? rrule;

  /// **Le libellé est demandé, pas porté.** Une valeur d'énumération est
  /// `const` : elle ne peut pas contenir un texte qui dépend de la langue de
  /// l'appareil. C'est la même règle que pour les couleurs — le modèle dit ce
  /// que la chose est, l'appelant en tire les mots.
  String label(AppTexts t) => switch (this) {
    Recurrence.aucune => t.calendarRecurrenceJamais,
    Recurrence.quotidienne => t.calendarJours,
    Recurrence.hebdomadaire => t.calendarToutesSemaines,
    Recurrence.bimensuelle => t.calendarToutesDeuxSemaines,
    Recurrence.mensuelle => t.calendarMois,
    Recurrence.annuelle => t.calendarAns,
  };

  static Recurrence fromRrule(String? value) {
    final String normalisee = (value ?? '').trim().toUpperCase();
    if (normalisee.isEmpty) return Recurrence.aucune;
    for (final Recurrence r in Recurrence.values) {
      if (r.rrule != null && r.rrule == normalisee) return r;
    }
    return Recurrence.aucune;
  }
}

/// Délai d'un rappel, exprimé **avant** l'échéance ou le début.
///
/// Un seul type pour les deux tables, malgré leur asymétrie : `tasks` porte un
/// instant (`reminder_at`) et `events` un délai (`reminder_minutes`). Cette
/// asymétrie vient du schéma initial ; la convertir ici évite de l'imposer à
/// l'interface, où l'on raisonne dans les deux cas en « combien de temps
/// avant ».
enum ReminderOffset {
  aucun(null),
  dixMinutes(10),
  uneHeure(60),
  laVeille(1440),
  uneSemaine(10080);

  const ReminderOffset(this.minutes);

  final int? minutes;

  /// Même raison que pour [Recurrence.label] : une constante ne connaît pas
  /// la langue.
  String label(AppTexts t) => switch (this) {
    ReminderOffset.aucun => t.calendarRappelAucun,
    ReminderOffset.dixMinutes => t.calendar10MinutesAvant,
    ReminderOffset.uneHeure => t.calendar1HeureAvant,
    ReminderOffset.laVeille => t.calendarVeille,
    ReminderOffset.uneSemaine => t.calendar1SemaineAvant,
  };

  static ReminderOffset fromMinutes(int? minutes) {
    if (minutes == null) return ReminderOffset.aucun;
    for (final ReminderOffset o in ReminderOffset.values) {
      if (o.minutes == minutes) return o;
    }
    return ReminderOffset.aucun;
  }

  /// Retrouve le délai à partir de l'instant enregistré et de l'échéance.
  ///
  /// Le rapprochement est tolérant à la minute près : un aller-retour par la
  /// base peut décaler les secondes, et un écart d'une seconde ne doit pas
  /// faire retomber le sélecteur sur « Aucun ».
  static ReminderOffset fromInstants(DateTime? rappel, DateTime? echeance) {
    if (rappel == null || echeance == null) return ReminderOffset.aucun;
    final int minutes = echeance.difference(rappel).inMinutes;
    for (final ReminderOffset o in ReminderOffset.values) {
      if (o.minutes != null && (o.minutes! - minutes).abs() <= 1) return o;
    }
    return ReminderOffset.aucun;
  }

  /// Instant du rappel pour une échéance donnée, ou `null` s'il n'y a rien à
  /// rappeler — un rappel sans échéance n'aurait pas de point d'ancrage.
  DateTime? instantAvant(DateTime? echeance) {
    if (minutes == null || echeance == null) return null;
    return echeance.subtract(Duration(minutes: minutes!));
  }
}
