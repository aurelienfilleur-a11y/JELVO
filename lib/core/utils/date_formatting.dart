import 'package:intl/intl.dart';

/// Formatage des dates en français, centralisé pour rester cohérent d'un
/// écran à l'autre.
///
/// `initializeDateFormattingFr()` doit être appelé une fois au démarrage
/// (voir `main.dart`) avant d'utiliser ces helpers.
abstract final class AppDates {
  static const String locale = 'fr_FR';

  /// « 14:00 »
  static String time(DateTime value) => DateFormat.Hm(locale).format(value);

  /// « 14:00 – 15:30 »
  static String timeRange(DateTime start, DateTime end) =>
      '${time(start)} – ${time(end)}';

  /// « jeu. 6 août »
  static String shortDate(DateTime value) =>
      DateFormat('E d MMM', locale).format(value);

  /// « Jeudi 6 août 2026 »
  static String fullDate(DateTime value) =>
      _capitalize(DateFormat('EEEE d MMMM y', locale).format(value));

  /// « Jeudi 6 août » — sans l'année.
  ///
  /// Sous une salutation, l'année n'apprend rien : on sait en quelle année on
  /// est, et elle allonge une ligne qui doit se lire d'un coup d'œil.
  static String dayAndMonth(DateTime value) =>
      _capitalize(DateFormat('EEEE d MMMM', locale).format(value));

  /// « Août 2026 »
  static String monthYear(DateTime value) =>
      _capitalize(DateFormat('MMMM y', locale).format(value));

  /// Initiale du jour de la semaine, pour les en-têtes de calendrier.
  static String weekdayInitial(DateTime value) =>
      DateFormat('E', locale).format(value).substring(0, 1).toUpperCase();

  /// Libellé relatif : « Aujourd'hui », « Demain », « Hier », sinon la date
  /// courte. Utilisé sur les tâches et les prochains événements.
  static String relativeDay(DateTime value, {DateTime? now}) {
    final DateTime reference = now ?? DateTime.now();
    final int days = dayDifference(value, reference);
    return switch (days) {
      0 => "Aujourd'hui",
      1 => 'Demain',
      -1 => 'Hier',
      _ => shortDate(value),
    };
  }

  /// Nombre de jours calendaires entre [value] et [reference], en ignorant
  /// l'heure (une soirée à 23 h et le lendemain 1 h sont bien à 1 jour d'écart).
  static int dayDifference(DateTime value, DateTime reference) {
    final DateTime a = DateTime(value.year, value.month, value.day);
    final DateTime b = DateTime(reference.year, reference.month, reference.day);
    return a.difference(b).inDays;
  }

  /// Vrai si les deux dates tombent le même jour calendaire.
  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _capitalize(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}
