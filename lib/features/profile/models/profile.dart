import 'package:flutter/foundation.dart';

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
    this.bio,
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
      bio: map['bio'] as String?,
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
  final String? bio;
  final String? timezone;
  final DateTime? createdAt;
  final DateTime? lastSeenAt;

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
    'bio': bio,
    if (timezone != null) 'timezone': timezone,
  };

  Profile copyWith({
    String? pseudo,
    String? firstName,
    String? lastName,
    String? avatarUrl,
    String? bio,
    String? timezone,
  }) {
    return Profile(
      id: id,
      pseudo: pseudo ?? this.pseudo,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
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
