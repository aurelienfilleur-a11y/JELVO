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
    List<GroupInvitationDetail>? invitationDetails,
    this.previewStatus = InviteLinkStatus.valide,
    this.joinOutcome = JoinOutcome.rejoint,
    this.previewMembershipExpiresAt,
  }) : _invitationDetails = List<GroupInvitationDetail>.of(
         invitationDetails ?? <GroupInvitationDetail>[],
       ),
       _groups = List<Group>.of(groups ?? demoGroups),
       _members = List<GroupMember>.of(members ?? demoMembers),
       _invitations = List<GroupInvitation>.of(
         invitations ?? <GroupInvitation>[],
       );

  final List<Group> _groups;
  final List<GroupMember> _members;
  final List<GroupInvitation> _invitations;
  final List<GroupInviteLink> _links = <GroupInviteLink>[];

  /// Détails imposés, pour éprouver les états dégradés — acceptée, refusée,
  /// expirée, groupe supprimé. Sans entrée, le détail est dérivé de
  /// l'invitation en attente du même identifiant.
  final List<GroupInvitationDetail> _invitationDetails;

  /// État renvoyé par l'aperçu d'un lien, pour éprouver la page publique.
  final InviteLinkStatus previewStatus;

  /// Résultat renvoyé par une adhésion.
  final JoinOutcome joinOutcome;

  /// Terme annoncé par l'aperçu public d'un lien, pour éprouver que la page
  /// le dit **avant** d'accepter.
  final DateTime? previewMembershipExpiresAt;

  /// Dernier appel reçu, pour les assertions.
  String? lastJoinedToken;
  String? lastLeftGroupId;
  String? lastDeletedGroupId;
  String? lastPromotedUserId;
  String? lastDemotedUserId;
  String? lastRemovedUserId;
  String? lastInvitedUserId;

  /// Terme réglé sur une adhésion existante. `lastTerm` seul ne suffirait pas
  /// à distinguer « rendu permanent » de « jamais appelé », les deux valant
  /// `null` — d'où le drapeau.
  String? lastTermUserId;
  DateTime? lastTerm;
  bool termSet = false;

  /// Mot d'état imposé, pour éprouver un refus de la base.
  String? termOutcome;

  /// Terme demandé à la dernière invitation, nominative ou par lien.
  DateTime? lastInvitedTerm;
  DateTime? lastLinkTerm;

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
  Future<String> setMembershipTerm({
    required String groupId,
    required String userId,
    required DateTime? expiresAt,
  }) async {
    lastTermUserId = userId;
    lastTerm = expiresAt;
    termSet = true;

    if (termOutcome != null) return termOutcome!;

    // Le membre est mis à jour pour de bon : la liste se relit après coup, et
    // un faux dépôt qui ne changerait rien laisserait passer un écran qui
    // n'affiche pas ce qu'il vient d'enregistrer.
    final int index = _members.indexWhere(
      (GroupMember m) => m.userId == userId,
    );
    if (index == -1) return 'non_membre';
    final GroupMember avant = _members[index];
    _members[index] = GroupMember(
      userId: avant.userId,
      role: avant.role,
      joinedAt: avant.joinedAt,
      expiresAt: expiresAt,
      pseudo: avant.pseudo,
      firstName: avant.firstName,
      lastName: avant.lastName,
      avatarUrl: avant.avatarUrl,
    );
    return expiresAt == null ? 'terme_retire' : 'terme_defini';
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
    DateTime? membershipExpiresAt,
  }) async {
    lastLinkTerm = membershipExpiresAt;
    final GroupInviteLink link = GroupInviteLink(
      id: 'l${_links.length + 1}',
      groupId: groupId,
      token: 'jeton-test-${_links.length + 1}',
      expiresAt: DateTime(2030),
      maxUses: maxUses,
      membershipExpiresAt: membershipExpiresAt,
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
    return GroupInvitePreview(
      status: InviteLinkStatus.valide,
      groupId: 'g2',
      name: 'Vacances en Corse',
      description: 'Billets, location et programme du séjour',
      memberCount: 4,
      membershipExpiresAt: previewMembershipExpiresAt,
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
  Future<GroupInvitationDetail> fetchInvitation(String invitationId) async {
    for (final GroupInvitationDetail detail in _invitationDetails) {
      if (detail.id == invitationId) return detail;
    }
    for (final GroupInvitation invitation in _invitations) {
      if (invitation.id != invitationId) continue;
      return GroupInvitationDetail(
        status: InvitationScreenStatus.valide,
        id: invitation.id,
        groupId: invitation.groupId,
        groupName: invitation.groupName,
        description: invitation.description,
        photoUrl: invitation.photoUrl,
        senderName: invitation.senderName,
        senderAvatarUrl: invitation.senderAvatarUrl,
        memberCount: invitation.memberCount,
        members: invitation.memberNames
            .map((String n) => InvitationMember(name: n))
            .toList(),
        createdAt: invitation.createdAt,
        expiresAt: invitation.expiresAt,
        membershipExpiresAt: invitation.membershipExpiresAt,
      );
    }
    return const GroupInvitationDetail(
      status: InvitationScreenStatus.introuvable,
    );
  }

  @override
  Future<String> invite({
    required String groupId,
    required String userId,
    DateTime? membershipExpiresAt,
  }) async {
    lastInvitedUserId = userId;
    lastInvitedTerm = membershipExpiresAt;
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
