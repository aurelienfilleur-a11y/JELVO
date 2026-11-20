import 'package:flutter/foundation.dart';

import '../../profile/models/anniversaire.dart';

/// L'anniversaire d'un contact, tel que `anniversaires_de_mes_contacts()` le
/// renvoie.
///
/// ### Pourquoi une lecture à part, et non une colonne de plus sur `mes_contacts`
///
/// Trois raisons, et la première suffirait :
///
/// 1. le calendrier a besoin des anniversaires **sans borne de dates** — un
///    anniversaire est annuel, et la fenêtre affichée change à chaque jour
///    qu'on fait défiler. Le carnet, lui, n'a pas besoin de la date du tout ;
/// 2. ajouter une colonne de sortie à `mes_contacts` impose un
///    `drop function`, qu'une lecture appelée de partout ne mérite pas — même
///    arbitrage que `preset:`, où onze suppressions en production auraient
///    été le prix d'un gain nul côté appelant ;
/// 3. la fonction ne renvoie **que** les contacts qui ont une date : il n'y a
///    rien à écarter côté client, et une personne sans anniversaire ne coûte
///    pas une ligne.
@immutable
class ContactBirthday {
  const ContactBirthday({
    required this.contactId,
    required this.anniversaire,
    this.pseudo,
    this.firstName,
    this.lastName,
    this.avatarUrl,
  });

  /// `null` si la ligne n'a pas de date exploitable — ce qui ne doit pas
  /// arriver, la fonction filtrant déjà, mais une ligne à moitié lue vaut
  /// mieux écartée qu'affichée.
  static ContactBirthday? fromRow(Map<String, dynamic> row) {
    final Anniversaire? date = Anniversaire.depuisLigne(
      row['jour'],
      row['mois'],
    );
    final Object? id = row['contact_id'];
    if (date == null || id is! String) return null;
    return ContactBirthday(
      contactId: id,
      anniversaire: date,
      pseudo: row['pseudo'] as String?,
      firstName: row['first_name'] as String?,
      lastName: row['last_name'] as String?,
      avatarUrl: row['avatar_url'] as String?,
    );
  }

  final String contactId;
  final Anniversaire anniversaire;
  final String? pseudo;
  final String? firstName;
  final String? lastName;

  /// Déjà composé par la fonction SQL — `preset:…` ou une URL.
  final String? avatarUrl;

  /// Nom complet, avec repli sur le pseudo : un profil peut n'avoir jamais
  /// été complété. Même règle que `Contact.fullName`.
  String get fullName {
    final String full = <String?>[
      firstName,
      lastName,
    ].whereType<String>().where((String p) => p.isNotEmpty).join(' ');
    if (full.isNotEmpty) return full;
    if (pseudo != null && pseudo!.isNotEmpty) return '@$pseudo';
    return 'Contact';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContactBirthday && other.contactId == contactId);

  @override
  int get hashCode => contactId.hashCode;
}
