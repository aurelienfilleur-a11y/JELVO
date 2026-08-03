import 'package:flutter/foundation.dart';

/// Lien entre l'utilisateur et un contact.
enum ContactRelation {
  friend('Ami'),
  family('Famille'),
  work('Travail'),
  other('Autre');

  const ContactRelation(this.label);

  final String label;
}

/// Une personne du carnet d'adresses Jelvo.
///
/// Les groupes et les événements ne stockent que des identifiants de contact ;
/// la résolution vers un [Contact] se fait dans les providers, ce qui évite de
/// dupliquer nom et avatar dans plusieurs collections.
@immutable
class Contact {
  const Contact({
    required this.id,
    required this.fullName,
    this.email,
    this.phone,
    this.avatarUrl,
    this.relation = ContactRelation.friend,
    this.isFavorite = false,
    this.sharesCalendar = false,
  });

  final String id;
  final String fullName;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final ContactRelation relation;
  final bool isFavorite;

  /// Le contact a accepté de partager ses disponibilités.
  final bool sharesCalendar;

  /// Prénom, utilisé dans les listes compactes.
  String get firstName => fullName.split(' ').first;

  Contact copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? avatarUrl,
    ContactRelation? relation,
    bool? isFavorite,
    bool? sharesCalendar,
  }) {
    return Contact(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      relation: relation ?? this.relation,
      isFavorite: isFavorite ?? this.isFavorite,
      sharesCalendar: sharesCalendar ?? this.sharesCalendar,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Contact && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
