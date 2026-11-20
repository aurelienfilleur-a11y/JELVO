import 'package:flutter/foundation.dart';

import 'anniversaire.dart';

/// Profil public d'un utilisateur, reflet de la table `profiles`.
///
/// L'adresse e-mail n'en fait pas partie : elle appartient à `auth.users` et
/// n'est lisible que pour l'utilisateur connecté, via sa session.
@immutable
class Profile {
  const Profile({
    required this.id,
    required this.pseudo,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    this.avatarPreset,
    this.bio,
    this.anniversaire,
    this.timezone,
    this.createdAt,
    this.lastSeenAt,
  });

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      pseudo: (map['pseudo'] as String?) ?? '',
      firstName: (map['first_name'] as String?) ?? '',
      lastName: (map['last_name'] as String?) ?? '',
      avatarUrl: map['avatar_url'] as String?,
      avatarPreset: map['avatar_preset'] as String?,
      bio: map['bio'] as String?,
      anniversaire: Anniversaire.depuisLigne(
        map['anniversaire_jour'],
        map['anniversaire_mois'],
      ),
      timezone: map['timezone'] as String?,
      createdAt: _parseDate(map['created_at']),
      lastSeenAt: _parseDate(map['last_seen_at']),
    );
  }

  final String id;
  final String pseudo;
  final String firstName;
  final String lastName;
  final String? avatarUrl;

  /// Identifiant d'un avatar prédéfini (ex. « p2_07 »), ou `null`.
  ///
  /// **Exclusif de [avatarUrl]** : le dernier choisi vide l'autre, dans la
  /// même écriture. Voir `ProfileRepository`.
  final String? avatarPreset;

  final String? bio;

  /// Jour et mois de naissance, **sans année** — facultatif.
  ///
  /// `null` couvre « non renseigné », qui est le cas par défaut : la ligne du
  /// profil invite alors à le remplir, et rien n'apparaît au calendrier de
  /// personne.
  final Anniversaire? anniversaire;

  final String? timezone;
  final DateTime? createdAt;
  final DateTime? lastSeenAt;

  /// La valeur à passer à `AvatarData.imageUrl`.
  ///
  /// Les fonctions SQL de lecture composent déjà cette valeur pour les
  /// **autres** personnes ; pour son propre profil, lu directement dans la
  /// table, c'est ici qu'on la compose.
  String? get avatarAAfficher =>
      avatarPreset == null ? avatarUrl : 'preset:$avatarPreset';

  /// « Prénom Nom », réduit au non-vide.
  String get fullName =>
      <String>[firstName, lastName].where((String p) => p.isNotEmpty).join(' ');

  /// Nom d'usage : le nom complet s'il existe, sinon le pseudo.
  String get displayName => fullName.isEmpty ? pseudo : fullName;

  /// Pseudo préfixé, tel qu'il s'affiche à l'écran.
  String get pseudoHandle => '@$pseudo';

  /// Champs destinés à un `insert`/`update` sur `profiles`.
  ///
  /// `createdAt` et `lastSeenAt` sont gérés côté base et volontairement omis.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'pseudo': pseudo,
    'first_name': firstName,
    'last_name': lastName,
    'avatar_url': avatarUrl,
    'avatar_preset': avatarPreset,
    'bio': bio,
    // Les **deux** colonnes, toujours ensemble : la contrainte de la base
    // refuse une moitié de date, et les omettre à l'écriture laisserait une
    // ancienne valeur en place sans que rien ne le dise.
    ...(anniversaire?.versLigne ?? Anniversaire.versLigneVide),
    if (timezone != null) 'timezone': timezone,
  };

  Profile copyWith({
    String? pseudo,
    String? firstName,
    String? lastName,
    String? avatarUrl,
    String? bio,
    Anniversaire? anniversaire,
    String? timezone,
  }) {
    return Profile(
      id: id,
      pseudo: pseudo ?? this.pseudo,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      // Ne sert qu'à *poser* une date : l'effacer passe par le dépôt, qui
      // écrit les deux colonnes à `null`. Un `copyWith` ne sait pas dire la
      // différence entre « inchangé » et « vidé », et prétendre le contraire
      // ici donnerait un effacement qui ne s'écrit pas.
      anniversaire: anniversaire ?? this.anniversaire,
      timezone: timezone ?? this.timezone,
      createdAt: createdAt,
      lastSeenAt: lastSeenAt,
    );
  }

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Profile && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
