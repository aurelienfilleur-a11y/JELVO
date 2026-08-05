import 'package:flutter/foundation.dart';

/// État d'une relation, reflétant le type `contact_status` de la base.
///
/// L'énumération SQL ne connaît que ces deux valeurs : refuser une demande
/// supprime la ligne plutôt que de la marquer.
enum ContactStatus {
  pending,
  accepted;

  static ContactStatus fromDb(String? value) =>
      value == 'accepted' ? ContactStatus.accepted : ContactStatus.pending;
}

/// Sens d'une demande, du point de vue de l'utilisateur connecté.
enum ContactDirection {
  /// L'utilisateur a envoyé la demande.
  outgoing,

  /// L'utilisateur l'a reçue : lui seul peut l'accepter.
  incoming;

  static ContactDirection fromDb(String? value) => value == 'entrant'
      ? ContactDirection.incoming
      : ContactDirection.outgoing;
}

/// Une personne du carnet, vue depuis le compte connecté.
///
/// L'identifiant est celui de l'autre personne : `contacts` n'a pas de clé
/// propre, la relation étant identifiée par le couple demandeur / destinataire.
@immutable
class Contact {
  const Contact({
    required this.id,
    this.pseudo,
    this.firstName,
    this.lastName,
    this.avatarUrl,
    this.status = ContactStatus.accepted,
    this.direction = ContactDirection.outgoing,
    this.isFavorite = false,
    this.createdAt,
  });

  factory Contact.fromRow(Map<String, dynamic> row) {
    return Contact(
      id: row['autre_id'] as String,
      pseudo: row['pseudo'] as String?,
      firstName: row['first_name'] as String?,
      lastName: row['last_name'] as String?,
      avatarUrl: row['avatar_url'] as String?,
      status: ContactStatus.fromDb(row['statut'] as String?),
      direction: ContactDirection.fromDb(row['sens'] as String?),
      isFavorite: (row['favori'] as bool?) ?? false,
      createdAt: DateTime.tryParse((row['created_at'] as String?) ?? ''),
    );
  }

  final String id;
  final String? pseudo;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;
  final ContactStatus status;
  final ContactDirection direction;
  final bool isFavorite;
  final DateTime? createdAt;

  bool get isAccepted => status == ContactStatus.accepted;

  bool get isIncomingRequest =>
      status == ContactStatus.pending && direction == ContactDirection.incoming;

  bool get isOutgoingRequest =>
      status == ContactStatus.pending && direction == ContactDirection.outgoing;

  /// Nom complet, avec repli sur le pseudo : un profil peut n'avoir jamais été
  /// complété.
  String get fullName {
    final String full = <String?>[
      firstName,
      lastName,
    ].whereType<String>().where((String p) => p.isNotEmpty).join(' ');
    if (full.isNotEmpty) return full;
    if (pseudo != null && pseudo!.isNotEmpty) return '@$pseudo';
    return 'Contact';
  }

  String get shortName {
    final String? first = firstName;
    if (first != null && first.isNotEmpty) return first;
    return fullName;
  }

  String get pseudoHandle => pseudo == null ? '' : '@$pseudo';

  /// Clé de tri alphabétique, insensible à la casse et aux accents manquants.
  String get sortKey => fullName.toLowerCase();

  Contact copyWith({ContactStatus? status, bool? isFavorite}) {
    return Contact(
      id: id,
      pseudo: pseudo,
      firstName: firstName,
      lastName: lastName,
      avatarUrl: avatarUrl,
      status: status ?? this.status,
      direction: direction,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Contact && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// Résultat de recherche de profil, avant toute mise en relation.
@immutable
class ProfileSummary {
  const ProfileSummary({
    required this.id,
    required this.pseudo,
    this.firstName,
    this.lastName,
    this.avatarUrl,
  });

  factory ProfileSummary.fromRow(Map<String, dynamic> row) {
    return ProfileSummary(
      id: row['id'] as String,
      pseudo: (row['pseudo'] as String?) ?? '',
      firstName: row['first_name'] as String?,
      lastName: row['last_name'] as String?,
      avatarUrl: row['avatar_url'] as String?,
    );
  }

  final String id;
  final String pseudo;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;

  String get fullName {
    final String full = <String?>[
      firstName,
      lastName,
    ].whereType<String>().where((String p) => p.isNotEmpty).join(' ');
    return full.isEmpty ? '@$pseudo' : full;
  }

  String get pseudoHandle => '@$pseudo';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ProfileSummary && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
