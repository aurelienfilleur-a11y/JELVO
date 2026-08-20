import 'dart:typed_data';

import 'package:jelvo/features/groups/models/group.dart';
import 'package:jelvo/features/groups/models/group_invite.dart';
import 'package:jelvo/features/groups/models/group_member.dart';
import 'package:jelvo/features/groups/repository/group_repository.dart';

/// Dépôt de groupes en mémoire, pour les tests de widget.
///
/// Reproduit les règles que le SQL applique en production — rôles, départ du
/// dernier admin, états d'un lien — pour que les écrans soient exercés sans
/// Supabase.
class FakeGroupRepository implements GroupRepository {
  FakeGroupRepository({
    List<Group>? groups,
    List<GroupMember>? members,
    List<GroupInvitation>? invitations,
    this.previewStatus = InviteLinkStatus.valide,
    this.joinOutcome = JoinOutcome.rejoint,
  }) : _groups = List<Group>.of(groups ?? demoGroups),
       _members = List<GroupMember>.of(members ?? demoMembers),
       _invitations = List<GroupInvitation>.of(
         invitations ?? <GroupInvitation>[],
       );

  final List<Group> _groups;
  final List<GroupMember> _members;
  final List<GroupInvitation> _invitations;
  final List<GroupInviteLink> _links = <GroupInviteLink>[];

  /// État renvoyé par l'aperçu d'un lien, pour éprouver la page publique.
  final InviteLinkStatus previewStatus;

  /// Résultat renvoyé par une adhésion.
  final JoinOutcome joinOutcome;

  /// Dernier appel reçu, pour les assertions.
  String? lastJoinedToken;
  String? lastLeftGroupId;
  String? lastDeletedGroupId;
  String? lastPromotedUserId;
  String? lastDemotedUserId;
  String? lastRemovedUserId;
  String? lastInvitedUserId;

  /// Tous les identifiants invités, dans l'ordre : la création d'un groupe en
  /// invite plusieurs d'un coup, et `lastInvitedUserId` n'en garderait qu'un.
  final List<String> invitedUserIds = <String>[];

  /// Identifiants pour lesquels l'invitation ne partira pas, afin d'éprouver
  /// l'échec partiel.
  final Set<String> refuseInvitationsPour = <String>{};
  String? lastCreatedName;

  static const List<Group> demoGroups = <Group>[
    Group(
      id: 'g1',
      name: 'Famille Rousseau',
      description: 'Anniversaires, vacances et rendez-vous médicaux',
      myRole: GroupRole.admin,
      memberCount: 3,
    ),
    Group(
      id: 'g2',
      name: 'Vacances en Corse',
      description: 'Billets, location et programme du séjour',
      memberCount: 4,
    ),
  ];

  static const List<GroupMember> demoMembers = <GroupMember>[
    GroupMember(
      userId: 'utilisateur-test',
      role: GroupRole.admin,
      pseudo: 'camille.rousseau',
      firstName: 'Camille',
      lastName: 'Rousseau',
    ),
    GroupMember(
      userId: 'u2',
      role: GroupRole.member,
      pseudo: 'lea.marchand',
      firstName: 'Léa',
      lastName: 'Marchand',
    ),
  ];

  @override
  Future<List<Group>> fetchMyGroups() async => List<Group>.of(_groups);

  @override
  Future<Group?> fetchGroup(String groupId) async {
    for (final Group group in _groups) {
      if (group.id == groupId) return group;
    }
    return null;
  }

  @override
  Future<List<GroupMember>> fetchMembers(String groupId) async =>
      List<GroupMember>.of(_members);

  @override
  Future<Group> createGroup({
    required String name,
    String? description,
    Uint8List? photoBytes,
    String? photoExtension,
    bool isPrivate = true,
  }) async {
    lastCreatedName = name;
    final Group group = Group(
      id: 'g${_groups.length + 1}',
      name: name,
      description: description,
      isPrivate: isPrivate,
      myRole: GroupRole.admin,
      memberCount: 1,
    );
    _groups.add(group);
    return group;
  }

  @override
  Future<void> updateGroup({
    required String groupId,
    required String name,
    String? description,
    Uint8List? photoBytes,
    String? photoExtension,
  }) async {
    final int index = _groups.indexWhere((Group g) => g.id == groupId);
    if (index == -1) return;
    _groups[index] = _groups[index].copyWith(
      name: name,
      description: description,
    );
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    lastDeletedGroupId = groupId;
    _groups.removeWhere((Group g) => g.id == groupId);
  }

  @override
  Future<String> removeMember({
    required String groupId,
    required String userId,
  }) async {
    lastRemovedUserId = userId;
    _members.removeWhere((GroupMember m) => m.userId == userId);
    return 'retire';
  }

  @override
  Future<String> promoteToAdmin({
    required String groupId,
    required String userId,
  }) async {
    lastPromotedUserId = userId;
    return 'promu';
  }

  @override
  Future<String> demoteToMember({
    required String groupId,
    required String userId,
  }) async {
    lastDemotedUserId = userId;
    return 'retrograde';
  }

  @override
  Future<LeaveOutcome> leaveGroup(String groupId) async {
    lastLeftGroupId = groupId;
    _groups.removeWhere((Group g) => g.id == groupId);
    return LeaveOutcome.parti;
  }

  @override
  Future<List<GroupInviteLink>> fetchInviteLinks(String groupId) async =>
      _links.where((GroupInviteLink l) => l.groupId == groupId).toList();

  @override
  Future<GroupInviteLink> createInviteLink({
    required String groupId,
    int? maxUses,
  }) async {
    final GroupInviteLink link = GroupInviteLink(
      id: 'l${_links.length + 1}',
      groupId: groupId,
      token: 'jeton-test-${_links.length + 1}',
      expiresAt: DateTime(2030),
      maxUses: maxUses,
    );
    _links.add(link);
    return link;
  }

  @override
  Future<void> revokeInviteLink(String linkId) async =>
      _links.removeWhere((GroupInviteLink l) => l.id == linkId);

  @override
  Future<GroupInvitePreview> previewInvite(String token) async {
    if (previewStatus != InviteLinkStatus.valide) {
      return GroupInvitePreview(status: previewStatus);
    }
    return const GroupInvitePreview(
      status: InviteLinkStatus.valide,
      groupId: 'g2',
      name: 'Vacances en Corse',
      description: 'Billets, location et programme du séjour',
      memberCount: 4,
    );
  }

  @override
  Future<JoinOutcome> joinByToken(String token) async {
    lastJoinedToken = token;
    return joinOutcome;
  }

  @override
  Future<List<GroupInvitation>> fetchInvitations() async =>
      List<GroupInvitation>.of(_invitations);

  @override
  Future<String> invite({
    required String groupId,
    required String userId,
  }) async {
    lastInvitedUserId = userId;
    invitedUserIds.add(userId);
    if (refuseInvitationsPour.contains(userId)) return 'deja_membre';
    return 'invite';
  }

  @override
  Future<JoinOutcome> acceptInvitation(String invitationId) async {
    _invitations.removeWhere((GroupInvitation i) => i.id == invitationId);
    return JoinOutcome.rejoint;
  }

  @override
  Future<void> declineInvitation(String invitationId) async =>
      _invitations.removeWhere((GroupInvitation i) => i.id == invitationId);
}
