import 'package:flutter/foundation.dart';

import '../../../core/utils/date_formatting.dart';
import '../../../l10n/app_localizations.dart';

/// Un jour et un mois, **sans année**.
///
/// ### Pourquoi pas une `DateTime`
///
/// Une `DateTime` exige une année, et toute année sentinelle — 1900, 2000,
/// l'année courante — est une valeur que quelqu'un finira par lire comme une
/// année de naissance, puis par afficher. Ce type la rend **impossible** :
/// il n'y a pas d'année à ignorer, il n'y en a pas du tout.
///
/// C'est la même raison côté base, où deux `smallint` remplacent une `date` :
/// une date de naissance complète associée à un nom sert couramment de
/// question de sécurité ailleurs, et Jelvo n'en a aucun besoin.
@immutable
class Anniversaire {
  const Anniversaire({required this.jour, required this.mois});

  /// Lit la paire d'une ligne `profiles`, ou rend `null`.
  ///
  /// Les deux colonnes sont renseignées ensemble ou pas du tout — une
  /// contrainte de la base le tient. Une moitié de valeur est donc traitée
  /// comme une absence, plutôt qu'affichée à moitié.
  static Anniversaire? depuisLigne(Object? jour, Object? mois) {
    final int? j = (jour as num?)?.toInt();
    final int? m = (mois as num?)?.toInt();
    if (j == null || m == null) return null;
    return estValide(j, m) ? Anniversaire(jour: j, mois: m) : null;
  }

  /// Le mois comme la base le refuse : un 30 février n'existe pas, un
  /// 29 février oui — c'est une vraie date de naissance.
  ///
  /// Recopie de `profiles_anniversaire_check`. Les deux sont épinglées sur les
  /// mêmes cas par `test/anniversaires_test.dart` et par
  /// `supabase/verification/fumee.sql`.
  static bool estValide(int jour, int mois) {
    if (mois < 1 || mois > 12) return false;
    return jour >= 1 && jour <= joursDansLeMois(mois);
  }

  /// Le nombre de jours du mois, février compris **et bissextile** : la saisie
  /// ne connaît pas d'année, elle doit donc accepter le 29.
  static int joursDansLeMois(int mois) => switch (mois) {
    2 => 29,
    4 || 6 || 9 || 11 => 30,
    _ => 31,
  };

  final int jour;
  final int mois;

  /// Le jour fêté une année donnée.
  ///
  /// **Une seule règle, et le 29 février n'en est pas une exception** : le
  /// jour est ramené au dernier jour du mois quand il le dépasse. Un
  /// anniversaire du 29 février tombe donc le **dernier jour de février** —
  /// le 29 les années bissextiles, le 28 sinon.
  ///
  /// Le reporter au 1er mars le ferait changer de mois, et « mon anniversaire
  /// est en février » cesserait d'être vrai. C'est le seul arbitrage de ce
  /// fichier, et il est le même en SQL (`public.jour_anniversaire`).
  DateTime jourFete(int annee) {
    // Le jour 0 du mois suivant est le dernier du mois courant : Dart
    // normalise, y compris pour décembre.
    final int dernier = DateTime(annee, mois + 1, 0).day;
    return DateTime(annee, mois, jour < dernier ? jour : dernier);
  }

  /// `true` si l'anniversaire se fête ce jour-là, année comprise.
  bool seFeteLe(DateTime jourCivil) {
    final DateTime fete = jourFete(jourCivil.year);
    return fete.month == jourCivil.month && fete.day == jourCivil.day;
  }

  /// « 29 février » — sans année, puisqu'il n'y en a pas.
  ///
  /// L'année 2024 n'apparaît nulle part : elle ne sert qu'à construire une
  /// `DateTime` que le formateur sait lire, et elle est **bissextile** à
  /// dessein — avec 2025, `DateTime` ramènerait le 29 février au 1er mars et
  /// le libellé mentirait sur la date saisie.
  String libelle(AppTexts t) =>
      AppDates.dateSansAnnee(DateTime(2024, mois, jour), t);

  Map<String, dynamic> get versLigne => <String, dynamic>{
    'anniversaire_jour': jour,
    'anniversaire_mois': mois,
  };

  /// Ce qu'il faut écrire pour effacer la date : les **deux** colonnes, sans
  /// quoi la contrainte de la base refuserait la moitié restante.
  static Map<String, dynamic> get versLigneVide => <String, dynamic>{
    'anniversaire_jour': null,
    'anniversaire_mois': null,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Anniversaire && other.jour == jour && other.mois == mois);

  @override
  int get hashCode => Object.hash(jour, mois);

  @override
  // texte-en-dur-autorise: représentation de débogage, jamais affichée.
  String toString() => 'Anniversaire($jour/$mois)';
}
