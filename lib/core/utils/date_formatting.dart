import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';

/// Formatage des dates, centralisé pour rester cohérent d'un écran à l'autre.
///
/// **La langue est demandée, jamais devinée.** Chaque méthode prend l'`AppTexts`
/// de l'écran et en lit `localeName` : une classe utilitaire n'a pas de
/// `BuildContext`, et lire une globale — `Intl.defaultLocale` — serait le piège
/// documenté pour les couleurs, où Flutter ne reconstruit que ce qui dépend
/// d'un `InheritedWidget`. Passer `t` **crée** cette dépendance, donc garantit
/// que la date se reformate au changement de langue.
///
/// `initializeDateFormatting()` doit être appelé une fois au démarrage (voir
/// `main.dart`) avant d'utiliser ces helpers — **sans argument**, pour charger
/// les symboles des quatre langues et non ceux d'une seule.
///
/// **Les squelettes l'emportent sur les motifs littéraux.** `DateFormat.jm`
/// plutôt que `DateFormat.Hm` : l'anglais écrit « 2:00 PM » là où le français
/// écrit « 14:00 », et un motif en dur imposerait l'usage français aux quatre
/// langues. De même `yMMMMEEEEd` plutôt que `'EEEE d MMMM y'` : l'espagnol
/// intercale des « de » que le motif français ne prévoit pas.
abstract final class AppDates {
  /// « 14:00 » en français et en allemand, « 2:00 PM » en anglais.
  static String time(DateTime value, AppTexts t) =>
      DateFormat.jm(t.localeName).format(value);

  /// « 14:00 – 15:30 », « 9:00 – 10:30 AM »
  ///
  /// **Le marqueur de demi-journée n'est écrit qu'une fois** quand les deux
  /// heures le partagent. C'est ce que font les formats d'intervalle du CLDR
  /// (`h:mm – h:mm a` en anglais), et `DateFormat` ne les expose pas. Sans
  /// cela, « 9:00 AM – 10:30 AM » débordait la carte d'agenda de l'accueil à
  /// 360 dp : la ligne est mesurée en français, où « 09:00 – 10:30 » tient.
  ///
  /// Le repli est le marqueur répété — un intervalle qui change de
  /// demi-journée, « 11:30 AM – 1:00 PM », doit porter les deux.
  static String timeRange(DateTime start, DateTime end, AppTexts t) {
    final String debut = time(start, t);
    final String fin = time(end, t);
    final String marqueur = _marqueur(start, t);
    if (marqueur.isNotEmpty &&
        debut.endsWith(marqueur) &&
        fin.endsWith(marqueur)) {
      // texte-en-dur-autorise: deux heures et un tiret, sans mot.
      return '${debut.substring(0, debut.length - marqueur.length).trimRight()}'
          ' – $fin';
    }
    // texte-en-dur-autorise: deux heures et un tiret, sans mot.
    return '$debut – $fin';
  }

  /// « AM », « p. m. » — ou la chaîne vide dans une langue qui compte en
  /// 24 heures, où `DateFormat.jm` n'en écrit aucun.
  static String _marqueur(DateTime value, AppTexts t) {
    final String avec = DateFormat.jm(t.localeName).format(value);
    final String sans = DateFormat.Hm(t.localeName).format(value);
    // Les chiffres diffèrent (« 2:00 » contre « 14:00 ») : c'est la fin de la
    // chaîne qui porte le marqueur, et elle seule qu'on compare.
    if (avec.length <= sans.length) return '';
    final RegExpMatch? queue = RegExp(r'[^\d]+$').firstMatch(avec);
    return queue?.group(0)?.trimLeft() ?? '';
  }

  /// « jeu. 6 août », « Thu, Aug 6 »
  static String shortDate(DateTime value, AppTexts t) =>
      DateFormat.MMMEd(t.localeName).format(value);

  /// « Jeudi 6 août 2026 », « Thursday, August 6, 2026 »
  static String fullDate(DateTime value, AppTexts t) =>
      _capitalize(DateFormat.yMMMMEEEEd(t.localeName).format(value));

  /// « Jeudi 6 août » — sans l'année.
  ///
  /// Sous une salutation, l'année n'apprend rien : on sait en quelle année on
  /// est, et elle allonge une ligne qui doit se lire d'un coup d'œil.
  static String dayAndMonth(DateTime value, AppTexts t) =>
      _capitalize(DateFormat.MMMMEEEEd(t.localeName).format(value));

  /// « 29 février » — ni jour de la semaine, ni année.
  ///
  /// Pour un anniversaire, les deux seraient faux : il n'a pas d'année, et le
  /// jour de la semaine change chacune d'elles. [dayAndMonth] porte le jour de
  /// la semaine, qui a du sens sous une salutation et pas ici.
  static String dateSansAnnee(DateTime value, AppTexts t) =>
      DateFormat.MMMMd(t.localeName).format(value);

  /// « Août 2026 »
  static String monthYear(DateTime value, AppTexts t) =>
      _capitalize(DateFormat.yMMMM(t.localeName).format(value));

  /// Initiale du jour de la semaine, pour les en-têtes de calendrier.
  static String weekdayInitial(DateTime value, AppTexts t) =>
      DateFormat.E(t.localeName).format(value).substring(0, 1).toUpperCase();

  /// Libellé relatif : « Aujourd'hui », « Demain », « Hier », sinon la date
  /// courte. Utilisé sur les tâches et les prochains événements.
  /// `AppTexts` est **demandé**, pas deviné : « Aujourd'hui » et « Hier » sont
  /// du texte, et une classe utilitaire sans `BuildContext` ne peut pas le
  /// résoudre elle-même. Le paramètre est positionnel et vient avant le bloc
  /// nommé — Dart refuse l'inverse.
  static String relativeDay(DateTime value, AppTexts t, {DateTime? now}) {
    final DateTime reference = now ?? DateTime.now();
    final int days = dayDifference(value, reference);
    return switch (days) {
      0 => t.coreAujourdHui,
      1 => t.coreDemain,
      -1 => t.coreHier,
      _ => shortDate(value, t),
    };
  }

  /// Ancienneté d'un événement passé : « à l'instant », « il y a 2 h »,
  /// « il y a 3 jours », puis la date au-delà d'une semaine.
  ///
  /// [relativeDay] répond à « quel jour ? », celle-ci à « depuis combien de
  /// temps ? ». Les deux questions ne se posent pas au même endroit : une
  /// échéance se situe dans le calendrier, une invitation se situe par rapport
  /// à maintenant.
  static String timeAgo(DateTime value, AppTexts t, {DateTime? now}) {
    final DateTime reference = now ?? DateTime.now();
    final Duration ecart = reference.difference(value);

    // Une date à venir n'a pas d'ancienneté : mieux vaut le dire que d'écrire
    // « il y a -3 minutes ».
    if (ecart.isNegative) return t.coreInstant;
    if (ecart.inMinutes < 1) return t.coreInstant;
    if (ecart.inMinutes < 60) return t.coreIlYaMinutes(ecart.inMinutes);
    if (ecart.inHours < 24) return t.coreIlYaHeures(ecart.inHours);
    // **Un pluriel, et il passe par ICU.** Le `${n > 1 ? 's' : ''}` d'avant
    // était du français écrit en Dart : il n'a aucun sens en anglais, où le
    // pluriel commence à 2 mais s'écrit autrement, ni en allemand. `plural`
    // laisse chaque langue poser ses propres formes.
    if (ecart.inDays < 7) return t.coreIlYaJours(ecart.inDays);
    return t.coreLeDate(shortDate(value, t));
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
