import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/avatar_stack.dart';
import 'group_member.dart';

/// Couleur d'identité d'un groupe.
///
/// `groups` ne porte ni couleur ni icône : l'accent est dérivé de l'identifiant
/// plutôt que stocké. Deux appareils affichent ainsi le même groupe de la même
/// couleur, sans colonne supplémentaire ni tirage aléatoire.
enum GroupAccent {
  violet(AppColors.primary),
  indigo(AppColors.primaryDark),
  green(AppColors.success),
  amber(AppColors.warning),
  red(AppColors.danger),
  midnight(AppColors.midnight);

  const GroupAccent(this.color);

  final Color color;

  static GroupAccent forId(String id) =>
      GroupAccent.values[_stableHash(id) % GroupAccent.values.length];
}

/// Icônes possibles, choisies elles aussi d'après l'identifiant.
const List<IconData> _groupIcons = <IconData>[
  Icons.groups_rounded,
  Icons.home_rounded,
  Icons.terrain_rounded,
  Icons.luggage_rounded,
  Icons.apartment_rounded,
  Icons.celebration_rounded,
];

/// Somme de contrôle stable d'une chaîne.
///
/// `String.hashCode` varie d'une exécution à l'autre en Dart : il ne peut pas
/// servir à choisir une couleur qui doit rester la même entre deux lancements.
int _stableHash(String value) {
  int hash = 0;
  for (final int unit in value.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hash;
}

/// Un groupe partagé : famille, colocation, amis, voyage…
@immutable
class Group {
  const Group({
    required this.id,
    required this.name,
    this.description,
    this.photoUrl,
    this.isPrivate = true,
    this.createdBy,
    this.createdAt,
    this.myRole = GroupRole.member,
    this.memberCount = 0,
    this.memberPreviews = const <AvatarData>[],
  });

  factory Group.fromRow(
    Map<String, dynamic> row, {
    GroupRole myRole = GroupRole.member,
    int memberCount = 0,
    List<AvatarData> memberPreviews = const <AvatarData>[],
  }) {
    return Group(
      id: row['id'] as String,
      name: (row['name'] as String?) ?? 'Groupe',
      description: row['description'] as String?,
      photoUrl: row['photo_url'] as String?,
      isPrivate: (row['is_private'] as bool?) ?? true,
      createdBy: row['created_by'] as String?,
      createdAt: DateTime.tryParse((row['created_at'] as String?) ?? ''),
      myRole: myRole,
      memberCount: memberCount,
      memberPreviews: memberPreviews,
    );
  }

  final String id;
  final String name;
  final String? description;
  final String? photoUrl;
  final bool isPrivate;
  final String? createdBy;
  final DateTime? createdAt;

  /// Rôle de l'utilisateur courant dans ce groupe.
  final GroupRole myRole;

  final int memberCount;

  /// Quelques membres, de quoi peupler la rangée d'avatars de la liste.
  ///
  /// **Quatre au plus, et c'est voulu** : au-delà, `AvatarStack` bascule sur
  /// « +N », et `memberCount` dit déjà le reste. Ils viennent de
  /// `mes_groupes_apercu`, qui les rend pour tous les groupes en une lecture —
  /// un appel à `membres_du_groupe` par carte aurait coûté une requête par
  /// ligne de la liste.
  final List<AvatarData> memberPreviews;

  /// Combien de membres la rangée d'avatars ne montre pas.
  int get hiddenMemberCount {
    final int reste = memberCount - memberPreviews.length;
    return reste > 0 ? reste : 0;
  }

  bool get isAdmin => myRole == GroupRole.admin;

  GroupAccent get accent => GroupAccent.forId(id);

  IconData get icon => _groupIcons[_stableHash(id) % _groupIcons.length];

  String get memberLabel => '$memberCount membre${memberCount > 1 ? 's' : ''}';

  Group copyWith({
    String? name,
    String? description,
    String? photoUrl,
    bool? isPrivate,
    GroupRole? myRole,
    int? memberCount,
    List<AvatarData>? memberPreviews,
  }) {
    return Group(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      photoUrl: photoUrl ?? this.photoUrl,
      isPrivate: isPrivate ?? this.isPrivate,
      createdBy: createdBy,
      createdAt: createdAt,
      myRole: myRole ?? this.myRole,
      memberCount: memberCount ?? this.memberCount,
      memberPreviews: memberPreviews ?? this.memberPreviews,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Group && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
