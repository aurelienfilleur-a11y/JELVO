import 'package:flutter/foundation.dart';

import '../../availability/models/availability.dart';
import '../../contacts/models/contact.dart';
import 'profile.dart';

/// Un groupe que l'on a en commun avec la personne consultée.
///
/// Ce sont **nos** groupes : les afficher ne révèle donc rien qu'on ne puisse
/// déjà lire dans leur liste de membres, et il n'y a pas de règle d'accès à
/// poser par-dessus.
@immutable
class GroupeCommun {
  const GroupeCommun({required this.id, required this.nom, this.photoUrl});

  factory GroupeCommun.depuisJson(Map<String, dynamic> json) => GroupeCommun(
    id: json['id'] as String,
    nom: (json['nom'] as String?) ?? '',
    photoUrl: json['photo_url'] as String?,
  );

  final String id;
  final String nom;
  final String? photoUrl;
}

/// Les trois compteurs, **réservés aux contacts**.
///
/// Volontairement distincts de `ProfileStats`, qui agrège les listes déjà
/// chargées du compte connecté : ceux-ci sont comptés par la base pour
/// quelqu'un d'autre, dont on ne peut lire aucune liste. Les deux ne peuvent
/// donc pas se dériver l'un de l'autre.
@immutable
class StatistiquesPubliques {
  const StatistiquesPubliques({
    required this.groupes,
    required this.evenements,
    required this.tachesTerminees,
  });

  factory StatistiquesPubliques.depuisJson(Map<String, dynamic> json) =>
      StatistiquesPubliques(
        groupes: (json['groupes'] as num?)?.toInt() ?? 0,
        evenements: (json['evenements'] as num?)?.toInt() ?? 0,
        tachesTerminees: (json['taches_terminees'] as num?)?.toInt() ?? 0,
      );

  final int groupes;
  final int evenements;
  final int tachesTerminees;
}

/// Le profil de quelqu'un d'autre, tel que `profil_consultable` le rend.
///
/// **La fonction SQL décide de ce qui est lisible, pas cet écran.** Les deux
/// champs réservés aux contacts arrivent donc à `null` quand on ne l'est pas,
/// et il n'y a rien à filtrer ici — l'affichage suit la donnée reçue.
///
/// L'adresse e-mail n'y figure pas : elle vit dans `auth.users`, que la
/// fonction ne lit pas. Ce n'est pas un champ omis, c'est un champ qui
/// n'existe nulle part dans cette lecture.
@immutable
class ProfilConsultable {
  const ProfilConsultable({
    required this.profil,
    required this.cestMoi,
    required this.groupesCommuns,
    this.relation,
    this.statistiques,
    this.disponibilite,
  });

  /// La ligne est lisible par les deux parseurs qui existent déjà :
  /// `Profile.fromMap` pour les champs publics, `Contact.fromRow` pour la
  /// relation. C'est pour cela que la fonction SQL reprend les noms de
  /// colonnes de `profiles` et de `mes_contacts` — un troisième vocabulaire
  /// aurait demandé un troisième parseur, donc un troisième endroit où se
  /// tromper.
  factory ProfilConsultable.depuisLigne(Map<String, dynamic> row) {
    final Object? statistiques = row['statistiques'];
    return ProfilConsultable(
      profil: Profile.fromMap(row),
      cestMoi: (row['cest_moi'] as bool?) ?? false,
      // `statut` nul signifie qu'aucune ligne `contacts` ne lie les deux
      // personnes — ni contact, ni demande dans un sens ou dans l'autre.
      // `Contact` n'a pas de valeur pour « aucune relation », et n'a pas à en
      // avoir : c'est l'absence d'objet qui le dit.
      relation: row['statut'] == null ? null : Contact.fromRow(row),
      groupesCommuns: <GroupeCommun>[
        for (final Object? g
            in (row['groupes_partages'] as List<Object?>?) ?? const <Object?>[])
          if (g is Map<String, dynamic>) GroupeCommun.depuisJson(g),
      ],
      statistiques: statistiques is Map<String, dynamic>
          ? StatistiquesPubliques.depuisJson(statistiques)
          : null,
      // `fromDb` ramène tout mot inconnu à `unknown` ; c'est bien l'absence
      // de valeur, et non un mot, qui dit « vous n'êtes pas contact ».
      disponibilite: row['disponibilite'] == null
          ? null
          : PeerAvailability.fromDb(row['disponibilite'] as String?),
    );
  }

  final Profile profil;

  /// Son propre profil, ouvert par ce chemin — en touchant son avatar dans une
  /// conversation, par exemple. L'écran n'offre alors aucune action de
  /// relation et renvoie vers « Mon profil ».
  final bool cestMoi;

  /// `null` quand la personne n'est pas dans le carnet, à aucun titre.
  ///
  /// Quand elle y est, l'objet se donne tel quel à `ContactActions` : il porte
  /// le sens de la relation, donc le bout où l'on se trouve, et c'est lui qui
  /// décide de la colonne de favori à écrire.
  final Contact? relation;

  final List<GroupeCommun> groupesCommuns;

  /// `null` dès que l'on n'est pas un contact accepté.
  final StatistiquesPubliques? statistiques;

  /// `null` dès que l'on n'est pas un contact accepté.
  final PeerAvailability? disponibilite;

  bool get estContact => relation?.status == ContactStatus.accepted;

  /// Une demande reçue, qu'on peut donc accepter.
  bool get demandeRecue =>
      relation != null &&
      relation!.status == ContactStatus.pending &&
      relation!.direction == ContactDirection.incoming;

  /// Une demande envoyée, qui attend une réponse d'en face.
  bool get demandeEnvoyee =>
      relation != null &&
      relation!.status == ContactStatus.pending &&
      relation!.direction == ContactDirection.outgoing;
}
