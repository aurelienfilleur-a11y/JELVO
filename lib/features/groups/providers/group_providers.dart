import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/data_providers.dart';
import '../../../data/supabase_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../../calendar/models/calendar_event.dart';
import '../../calendar/providers/calendar_providers.dart';
import '../../tasks/models/task.dart';
import '../../tasks/providers/task_providers.dart';
import '../models/group.dart';
import '../models/group_invite.dart';
import '../models/group_member.dart';
import '../repository/group_repository.dart';

/// Dépôt des groupes. Surchargé dans les tests par un faux dépôt.
final Provider<GroupRepository> groupRepositoryProvider =
    Provider<GroupRepository>(
      (Ref ref) => SupabaseGroupRepository(ref.watch(supabaseClientProvider)),
    );

/// Groupes de l'utilisateur connecté.
///
/// Un `AsyncNotifier` plutôt qu'un `StreamProvider` : les écritures passent par
/// `groupActionsProvider`, qui rafraîchit explicitement la liste. Cela évite
/// d'ouvrir un canal temps réel dont l'application n'a pas encore besoin.
final AsyncNotifierProvider<MyGroupsNotifier, List<Group>> myGroupsProvider =
    AsyncNotifierProvider<MyGroupsNotifier, List<Group>>(MyGroupsNotifier.new);

class MyGroupsNotifier extends AsyncNotifier<List<Group>> {
  @override
  Future<List<Group>> build() {
    // Se recharge à la connexion comme à la déconnexion : les groupes d'une
    // session ne doivent pas survivre à la suivante.
    ref.watch(authStatusProvider);
    return ref.watch(groupRepositoryProvider).fetchMyGroups();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(groupRepositoryProvider).fetchMyGroups(),
    );
  }
}

/// Liste prête à afficher, vide tant que le chargement n'a pas abouti.
final Provider<List<Group>> activeGroupsProvider = Provider<List<Group>>(
  (Ref ref) => ref.watch(myGroupsProvider).value ?? const <Group>[],
);

/// Un groupe de la liste, ou `null`.
///
/// Renvoie `null` sans erreur pour un identifiant inconnu : les données de
/// démonstration des tâches et des événements citent encore des groupes qui
/// n'existent pas côté Supabase.
// Riverpod 3 n'exporte pas les types `*Family` : on laisse l'inférence faire.
final groupByIdProvider = Provider.family<Group?, String>((Ref ref, String id) {
  for (final Group group in ref.watch(activeGroupsProvider)) {
    if (group.id == id) return group;
  }
  return null;
});

/// Détail d'un groupe, rechargé à chaque ouverture de l'écran.
final groupDetailProvider = FutureProvider.autoDispose.family<Group?, String>((
  Ref ref,
  String id,
) {
  ref.watch(myGroupsProvider);
  return ref.watch(groupRepositoryProvider).fetchGroup(id);
});

/// Membres d'un groupe, avec leur profil et leur rôle.
final groupMembersProvider = FutureProvider.autoDispose
    .family<List<GroupMember>, String>((Ref ref, String id) {
      ref.watch(myGroupsProvider);
      return ref.watch(groupRepositoryProvider).fetchMembers(id);
    });

/// Liens de partage d'un groupe.
final groupInviteLinksProvider = FutureProvider.autoDispose
    .family<List<GroupInviteLink>, String>(
      (Ref ref, String id) =>
          ref.watch(groupRepositoryProvider).fetchInviteLinks(id),
    );

/// Invitations nominatives reçues et encore en attente.
final AsyncNotifierProvider<InvitationsNotifier, List<GroupInvitation>>
invitationsProvider =
    AsyncNotifierProvider<InvitationsNotifier, List<GroupInvitation>>(
      InvitationsNotifier.new,
    );

class InvitationsNotifier extends AsyncNotifier<List<GroupInvitation>> {
  @override
  Future<List<GroupInvitation>> build() {
    ref.watch(authStatusProvider);
    return ref.watch(groupRepositoryProvider).fetchInvitations();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(groupRepositoryProvider).fetchInvitations(),
    );
  }
}

/// Une invitation nominative précise, dans l'état où elle se trouve.
///
/// `autoDispose` : l'écran d'une invitation ne se garde pas d'une visite à
/// l'autre — l'état qui compte est celui de l'instant où on l'ouvre.
final invitationDetailProvider = FutureProvider.autoDispose
    .family<GroupInvitationDetail, String>(
      (Ref ref, String id) =>
          ref.watch(groupRepositoryProvider).fetchInvitation(id),
    );

/// Aperçu public d'un lien d'invitation, lisible sans session.
final groupInvitePreviewProvider = FutureProvider.autoDispose
    .family<GroupInvitePreview, String>(
      (Ref ref, String token) =>
          ref.watch(groupRepositoryProvider).previewInvite(token),
    );

/// Jeton d'invitation mis de côté le temps d'une inscription.
///
/// Quelqu'un qui ouvre un lien sans compte passe par l'inscription ; le jeton
/// doit survivre à ce détour pour que le groupe soit rejoint à l'arrivée.
final NotifierProvider<PendingInviteToken, String?> pendingInviteTokenProvider =
    NotifierProvider<PendingInviteToken, String?>(PendingInviteToken.new);

class PendingInviteToken extends Notifier<String?> {
  @override
  String? build() => null;

  void remember(String token) => state = token;

  void clear() => state = null;
}

/// Écritures sur les groupes. Les widgets ne touchent jamais au dépôt.
final Provider<GroupActions> groupActionsProvider = Provider<GroupActions>(
  GroupActions.new,
);

class GroupActions {
  const GroupActions(this._ref);

  final Ref _ref;

  GroupRepository get _repository => _ref.read(groupRepositoryProvider);

  Future<Group> create({
    required String name,
    String? description,
    Uint8List? photoBytes,
    String? photoExtension,
    bool isPrivate = true,
  }) async {
    final Group group = await _repository.createGroup(
      name: name,
      description: description,
      photoBytes: photoBytes,
      photoExtension: photoExtension,
      isPrivate: isPrivate,
    );
    await _refreshGroups();
    return group;
  }

  Future<void> update({
    required String groupId,
    required String name,
    String? description,
    Uint8List? photoBytes,
    String? photoExtension,
  }) async {
    await _repository.updateGroup(
      groupId: groupId,
      name: name,
      description: description,
      photoBytes: photoBytes,
      photoExtension: photoExtension,
    );
    await _refreshGroups();
    _ref.invalidate(groupDetailProvider(groupId));
  }

  Future<void> delete(String groupId) async {
    await _repository.deleteGroup(groupId);
    await _refreshGroups();
  }

  Future<MemberOutcome> removeMember({
    required String groupId,
    required String userId,
  }) => _administrer(
    groupId,
    () => _repository.removeMember(groupId: groupId, userId: userId),
  );

  Future<MemberOutcome> promote({
    required String groupId,
    required String userId,
  }) => _administrer(
    groupId,
    () => _repository.promoteToAdmin(groupId: groupId, userId: userId),
  );

  Future<MemberOutcome> demote({
    required String groupId,
    required String userId,
  }) => _administrer(
    groupId,
    () => _repository.demoteToMember(groupId: groupId, userId: userId),
  );

  /// Prolonge, écourte, ou rend permanente une adhésion.
  ///
  /// [expiresAt] à `null` retire le terme. Une seule méthode pour les trois
  /// gestes, parce que la base n'en connaît qu'un : poser une valeur.
  Future<MemberOutcome> setMembershipTerm({
    required String groupId,
    required String userId,
    required DateTime? expiresAt,
  }) => _administrer(
    groupId,
    () => _repository.setMembershipTerm(
      groupId: groupId,
      userId: userId,
      expiresAt: expiresAt,
    ),
  );

  /// Rafraîchit la liste des membres, et le groupe lui-même : mon propre rôle
  /// a pu changer, et avec lui l'accès aux actions d'administration.
  Future<MemberOutcome> _administrer(
    String groupId,
    Future<String> Function() action,
  ) async {
    final MemberOutcome outcome = MemberOutcome.fromDb(await action());
    if (outcome.isSuccess) {
      _ref.invalidate(groupMembersProvider(groupId));
      _ref.invalidate(groupDetailProvider(groupId));
      await _refreshGroups();
    }
    return outcome;
  }

  Future<LeaveOutcome> leave(String groupId) async {
    final LeaveOutcome outcome = await _repository.leaveGroup(groupId);
    await _refreshGroups();
    return outcome;
  }

  Future<GroupInviteLink> createInviteLink({
    required String groupId,
    int? maxUses,
    DateTime? membershipExpiresAt,
  }) async {
    final GroupInviteLink link = await _repository.createInviteLink(
      groupId: groupId,
      maxUses: maxUses,
      membershipExpiresAt: membershipExpiresAt,
    );
    _ref.invalidate(groupInviteLinksProvider(groupId));
    return link;
  }

  Future<void> revokeInviteLink({
    required String groupId,
    required String linkId,
  }) async {
    await _repository.revokeInviteLink(linkId);
    _ref.invalidate(groupInviteLinksProvider(groupId));
  }

  Future<JoinOutcome> joinByToken(String token) async {
    final JoinOutcome outcome = await _repository.joinByToken(token);
    if (outcome.isSuccess) await _refreshGroups();
    return outcome;
  }

  /// Rejoint le groupe dont le jeton attendait la fin de l'inscription.
  ///
  /// Sans jeton en attente, ne fait rien : c'est le cas d'une inscription
  /// ordinaire.
  Future<JoinOutcome?> joinPendingInvite() async {
    final String? token = _ref.read(pendingInviteTokenProvider);
    if (token == null) return null;

    _ref.read(pendingInviteTokenProvider.notifier).clear();
    return joinByToken(token);
  }

  Future<String> invite({
    required String groupId,
    required String userId,
    DateTime? membershipExpiresAt,
  }) => _repository.invite(
    groupId: groupId,
    userId: userId,
    membershipExpiresAt: membershipExpiresAt,
  );

  /// Invite plusieurs personnes, et renvoie **combien n'ont pas reçu leur
  /// invitation**.
  ///
  /// Les invitations sont indépendantes : une adresse qui échoue ne doit pas
  /// empêcher les suivantes de partir. Elles sont donc toutes tentées, et
  /// l'appelant décide quoi dire du reste — jamais de lever, car cette
  /// méthode est appelée **après** la création du groupe, et un groupe créé
  /// ne doit pas paraître perdu parce qu'une invitation a échoué.
  Future<int> inviteAll({
    required String groupId,
    required Iterable<String> userIds,
    DateTime? membershipExpiresAt,
  }) async {
    int echecs = 0;
    for (final String userId in userIds) {
      try {
        final String issue = await invite(
          groupId: groupId,
          userId: userId,
          membershipExpiresAt: membershipExpiresAt,
        );
        if (issue != 'invite') echecs++;
      } catch (_) {
        echecs++;
      }
    }
    return echecs;
  }

  Future<JoinOutcome> acceptInvitation(String invitationId) async {
    final JoinOutcome outcome = await _repository.acceptInvitation(
      invitationId,
    );
    await _ref.read(invitationsProvider.notifier).refresh();
    if (outcome.isSuccess) await _refreshGroups();
    return outcome;
  }

  Future<void> declineInvitation(String invitationId) async {
    await _repository.declineInvitation(invitationId);
    await _ref.read(invitationsProvider.notifier).refresh();
  }

  Future<void> _refreshGroups() =>
      _ref.read(myGroupsProvider.notifier).refresh();
}

/// Les deux compteurs de l'écran d'un groupe.
///
/// **Les deux se calculent proprement, et sans aucune lecture de plus.**
/// `mes_taches` et `mon_agenda` sont déjà chargées sans bornes de dates, et
/// portent `group_id` : il n'y a qu'à filtrer.
///
/// - **tâches en retard** — `completed_at is null` et `due_at` dépassée. C'est
///   `Task.isOverdue`, qui dérive de `completed_at`, seule source du statut
///   d'une tâche : rien ne peut se contredire ;
/// - **événements à venir** — ceux dont la **fin** est encore devant nous. La
///   fin plutôt que le début, sans quoi un événement commencé ce matin et qui
///   dure jusqu'à ce soir serait déjà compté comme passé.
///
/// Les deux ne comptent que ce que l'utilisateur voit : `mes_taches` et
/// `mon_agenda` sont `security definer` et filtrent déjà les adhésions échues.
@immutable
class GroupStats {
  const GroupStats({
    required this.tachesEnRetard,
    required this.evenementsAVenir,
  });

  final int tachesEnRetard;
  final int evenementsAVenir;
}

final groupStatsProvider = Provider.family<GroupStats, String>((
  Ref ref,
  String groupId,
) {
  final DateTime now = ref.watch(nowProvider);
  return GroupStats(
    tachesEnRetard: ref
        .watch(tasksForGroupProvider(groupId))
        .where((Task t) => t.isOverdue(now))
        .length,
    evenementsAVenir: ref
        .watch(eventsForGroupProvider(groupId))
        .where((CalendarEvent e) => e.end.isAfter(now))
        .length,
  );
});
