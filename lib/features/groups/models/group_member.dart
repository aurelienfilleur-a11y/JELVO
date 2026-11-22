import 'package:flutter/foundation.dart';

import '../../../l10n/app_localizations.dart';

/// Rôle d'une personne dans un groupe.
///
/// Reflète le type `member_role` de la base, qui ne connaît que ces deux
/// valeurs.
///
/// **Il ne porte plus de libellé.** Il en portait deux en `const` — « Admin »
/// et « Membre » —, donc en français dans les quatre langues ; et personne ne
/// les lisait, la pastille d'administrateur de `MemberTile` passant déjà par
/// l'ARB. Un champ mort qui ment est pire qu'un champ absent.
enum GroupRole {
  admin,
  member;

  static GroupRole fromDb(String? value) =>
      value == 'admin' ? GroupRole.admin : GroupRole.member;

  String get dbValue => name;
}

/// Un membre d'un groupe, profil compris.
@immutable
class GroupMember {
  const GroupMember({
    required this.userId,
    required this.role,
    this.joinedAt,
    this.expiresAt,
    this.pseudo,
    this.firstName,
    this.lastName,
    this.avatarUrl,
  });

  factory GroupMember.fromRow(Map<String, dynamic> row) {
    return GroupMember(
      userId: row['user_id'] as String,
      role: GroupRole.fromDb(row['role'] as String?),
      joinedAt: DateTime.tryParse((row['joined_at'] as String?) ?? ''),
      expiresAt: DateTime.tryParse((row['expires_at'] as String?) ?? ''),
      pseudo: row['pseudo'] as String?,
      firstName: row['first_name'] as String?,
      lastName: row['last_name'] as String?,
      avatarUrl: row['avatar_url'] as String?,
    );
  }

  final String userId;
  final GroupRole role;
  final DateTime? joinedAt;

  /// Terme d'une adhésion temporaire ; `null` signifie « sans terme ».
  ///
  /// L'interface de réglage n'existe pas encore, mais la lecture filtre déjà
  /// les adhésions échues : une valeur passée ne doit jamais atteindre l'écran.
  final DateTime? expiresAt;

  final String? pseudo;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;

  bool get isAdmin => role == GroupRole.admin;

  bool get isTemporary => expiresAt != null;

  bool isActive(DateTime now) => expiresAt == null || expiresAt!.isAfter(now);

  /// Nom affiché, avec repli sur le pseudo puis sur un libellé neutre : un
  /// profil peut n'avoir jamais été complété.
  ///
  /// **Prend l'`AppTexts`**, comme `TaskAssignee.displayName` : le repli était
  /// « Membre » en dur, et c'est un mot — un modèle ne choisit pas ses mots.
  String displayName(AppTexts t) {
    final String full = <String?>[
      firstName,
      lastName,
    ].whereType<String>().where((String p) => p.isNotEmpty).join(' ');
    if (full.isNotEmpty) return full;
    if (pseudo != null && pseudo!.isNotEmpty) return '@$pseudo';
    return t.coreMembre;
  }

  String shortName(AppTexts t) {
    final String? first = firstName;
    if (first != null && first.isNotEmpty) return first;
    return displayName(t);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GroupMember && other.userId == userId);

  @override
  int get hashCode => userId.hashCode;
}
