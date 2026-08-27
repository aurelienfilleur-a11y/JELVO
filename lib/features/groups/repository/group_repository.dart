import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/avatar_stack.dart';
import '../../../data/app_config.dart';
import '../../auth/models/auth_failure.dart';
import '../models/group.dart';
import '../models/group_invite.dart';
import '../models/group_member.dart';

/// Accès aux groupes, à leurs membres et à leurs invitations.
///
/// L'interface est séparée de l'implémentation pour que les tests de widget
/// puissent la surcharger sans réseau ni `Supabase.initialize`.
abstract interface class GroupRepository {
  /// Groupes dont l'utilisateur est membre, hors groupes supprimés.
  Future<List<Group>> fetchMyGroups();

  Future<Group?> fetchGroup(String groupId);

  Future<List<GroupMember>> fetchMembers(String groupId);

  Future<Group> createGroup({
    required String name,
    String? description,
    Uint8List? photoBytes,
    String? photoExtension,
    bool isPrivate,
  });

  Future<void> updateGroup({
    required String groupId,
    required String name,
    String? description,
    Uint8List? photoBytes,
    String? photoExtension,
  });

  /// Suppression douce : la ligne reste, `deleted_at` est renseigné.
  Future<void> deleteGroup(String groupId);

  /// Administration des membres.
  ///
  /// Les trois passent par des fonctions SQL et renvoient un **mot d'état** —
  /// `retire`, `promu`, `dernier_admin`, `non_admin`… — et non `void`.
  ///
  /// L'écriture directe dans `group_members` par PostgREST ne convenait pas :
  /// quand les politiques ne couvrent pas le cas, la requête ne touche aucune
  /// ligne et le serveur répond **200 sans erreur**. L'écran annonçait donc une
  /// promotion qui n'avait pas eu lieu. Voir
  /// `supabase/tranche3b_details_et_administration.sql`.
  Future<String> removeMember({
    required String groupId,
    required String userId,
  });

  Future<String> promoteToAdmin({
    required String groupId,
    required String userId,
  });

  Future<String> demoteToMember({
    required String groupId,
    required String userId,
  });

  /// Pose, déplace ou retire le terme d'une adhésion.
  ///
  /// Prolonger, écourter et rendre permanent sont **la même écriture** :
  /// poser une date, ou poser `null`. Trois méthodes diraient trois fois la
  /// même chose, et la troisième finirait par diverger.
  Future<String> setMembershipTerm({
    required String groupId,
    required String userId,
    required DateTime? expiresAt,
  });

  Future<LeaveOutcome> leaveGroup(String groupId);

  // — Invitations par lien —

  Future<List<GroupInviteLink>> fetchInviteLinks(String groupId);

  Future<GroupInviteLink> createInviteLink({
    required String groupId,
    int? maxUses,
    DateTime? membershipExpiresAt,
  });

  Future<void> revokeInviteLink(String linkId);

  /// Aperçu public d'un lien, accessible sans session.
  Future<GroupInvitePreview> previewInvite(String token);

  Future<JoinOutcome> joinByToken(String token);

  // — Invitations nominatives —

  Future<List<GroupInvitation>> fetchInvitations();

  /// Une invitation précise, **quel que soit son état**.
  ///
  /// [fetchInvitations] ne renvoie que celles qui sont en attente : l'écran
  /// d'une invitation acceptée, refusée ou expirée n'y trouverait rien, et ne
  /// pourrait dire que « introuvable » pour quatre situations différentes.
  Future<GroupInvitationDetail> fetchInvitation(String invitationId);

  Future<String> invite({
    required String groupId,
    required String userId,
    DateTime? membershipExpiresAt,
  });

  Future<JoinOutcome> acceptInvitation(String invitationId);

  Future<void> declineInvitation(String invitationId);
}

class SupabaseGroupRepository implements GroupRepository {
  const SupabaseGroupRepository(this._client);

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  /// Filtre PostgREST des adhésions encore actives.
  ///
  /// `expires_at` est nullable et prépare l'adhésion temporaire : `null`
  /// signifie « sans terme ». Toute lecture de `group_members` doit l'écarter
  /// une fois la date passée, sans quoi un membre expiré resterait visible.
  static String get _activeMembership =>
      'expires_at.is.null,expires_at.gt.${DateTime.now().toUtc().toIso8601String()}';

  @override
  Future<List<Group>> fetchMyGroups() async {
    final String? userId = _userId;
    if (userId == null) return const <Group>[];

    try {
      // `!inner` restreint aux lignes dont le groupe existe encore : un groupe
      // supprimé en douceur ne doit plus apparaître nulle part. `expires_at`
      // écarte les adhésions temporaires arrivées à terme.
      final List<Map<String, dynamic>> rows = await _client
          .from('group_members')
          .select(
            'role, joined_at, expires_at, '
            'groups!inner(id, name, description, photo_url, is_private, '
            'created_by, created_at, deleted_at)',
          )
          .eq('user_id', userId)
          .isFilter('groups.deleted_at', null)
          .or(_activeMembership);

      if (rows.isEmpty) return const <Group>[];

      final Map<String, _GroupPreview> apercus = await _memberPreviews();

      final List<Group> groups = rows.map((Map<String, dynamic> row) {
        final Map<String, dynamic> groupRow =
            row['groups'] as Map<String, dynamic>;
        final _GroupPreview? apercu = apercus[groupRow['id'] as String];
        return Group.fromRow(
          groupRow,
          myRole: GroupRole.fromDb(row['role'] as String?),
          memberCount: apercu?.count ?? 0,
          memberPreviews: apercu?.avatars ?? const <AvatarData>[],
        );
      }).toList();

      groups.sort(
        (Group a, Group b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return groups;
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  /// Effectif **et aperçu des membres** de chaque groupe, en une requête
  /// plutôt qu'une par carte.
  ///
  /// La rangée d'avatars de la liste demande des profils, que RLS ne donne pas
  /// forcément pour autrui : d'où `mes_groupes_apercu`, `security definer`,
  /// plutôt qu'une jointure PostgREST qui rendrait des profils partiellement
  /// nuls sans le dire. Elle remplace l'ancien comptage sans ajouter de
  /// requête.
  Future<Map<String, _GroupPreview>> _memberPreviews() async {
    final List<dynamic> rows =
        await _client.rpc('mes_groupes_apercu') as List<dynamic>;

    final Map<String, _GroupPreview> apercus = <String, _GroupPreview>{};
    for (final dynamic brut in rows) {
      final Map<String, dynamic> row = brut as Map<String, dynamic>;
      final List<dynamic> membres =
          (row['membres'] as List<dynamic>?) ?? const <dynamic>[];
      apercus[row['group_id'] as String] = _GroupPreview(
        count: (row['nombre_membres'] as num?)?.toInt() ?? 0,
        avatars: <AvatarData>[
          for (final dynamic m in membres)
            AvatarData(
              name: _nomAffiche(m as Map<String, dynamic>),
              imageUrl: m['avatar_url'] as String?,
            ),
        ],
      );
    }
    return apercus;
  }

  /// Effectif d'un seul groupe, pour son écran de détail.
  ///
  /// Il ne passe pas par `mes_groupes_apercu` : celle-ci rend tous les groupes,
  /// et l'écran de détail charge de toute façon la liste complète de ses
  /// membres juste après.
  Future<int> _memberCount(String groupId) async {
    final List<Map<String, dynamic>> rows = await _client
        .from('group_members')
        .select('user_id')
        .eq('group_id', groupId)
        .or(_activeMembership);
    return rows.length;
  }

  /// De quoi tirer des initiales : prénom et nom, à défaut le pseudo.
  static String _nomAffiche(Map<String, dynamic> row) {
    final String complet = <String?>[
      row['first_name'] as String?,
      row['last_name'] as String?,
    ].whereType<String>().where((String s) => s.isNotEmpty).join(' ');
    if (complet.isNotEmpty) return complet;
    return (row['pseudo'] as String?) ?? '?';
  }

  @override
  Future<Group?> fetchGroup(String groupId) async {
    final String? userId = _userId;
    if (userId == null) return null;

    try {
      final Map<String, dynamic>? row = await _client
          .from('groups')
          .select(
            'id, name, description, photo_url, is_private, created_by, '
            'created_at, deleted_at',
          )
          .eq('id', groupId)
          .isFilter('deleted_at', null)
          .maybeSingle();
      if (row == null) return null;

      final Map<String, dynamic>? membership = await _client
          .from('group_members')
          .select('role')
          .eq('group_id', groupId)
          .eq('user_id', userId)
          .or(_activeMembership)
          .maybeSingle();

      return Group.fromRow(
        row,
        myRole: GroupRole.fromDb(membership?['role'] as String?),
        memberCount: await _memberCount(groupId),
      );
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<List<GroupMember>> fetchMembers(String groupId) async {
    try {
      final List<Map<String, dynamic>> rows = await _client
          .rpc<dynamic>(
            'membres_du_groupe',
            params: <String, dynamic>{'p_group_id': groupId},
          )
          .then(_asRows);

      // `membres_du_groupe` écarte déjà les adhésions échues ; le second filtre
      // couvre l'écart entre l'heure du serveur et celle de l'appareil.
      final DateTime now = DateTime.now();
      return rows
          .map(GroupMember.fromRow)
          .where((GroupMember m) => m.isActive(now))
          .toList();
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<Group> createGroup({
    required String name,
    String? description,
    Uint8List? photoBytes,
    String? photoExtension,
    bool isPrivate = true,
  }) async {
    final String? userId = _userId;
    if (userId == null) {
      throw const AuthFailure(
        'Votre session a expiré. Reconnectez-vous.',
        kind: AuthFailureKind.sessionExpired,
      );
    }

    try {
      // Création par fonction plutôt que par `insert(...).select()` : la
      // politique de lecture de `groups` exige d'être membre, et PostgreSQL
      // applique les politiques SELECT au `returning` d'une insertion. Le
      // créateur n'étant pas encore membre à cet instant, la relecture échouait
      // en 42501. `creer_groupe` insère le groupe et l'adhésion admin dans la
      // même transaction ; voir supabase/correctif_creation_groupe.sql.
      final Object? result = await _client.rpc<Object?>(
        'creer_groupe',
        params: <String, dynamic>{
          'p_name': name.trim(),
          'p_description': _trimmedOrNull(description),
          'p_is_private': isPrivate,
        },
      );

      final List<Map<String, dynamic>> rows = _asRows(result);
      if (rows.isEmpty) {
        throw const AuthFailure(
          'Le groupe n’a pas pu être créé. Réessayez dans un instant.',
        );
      }
      final Map<String, dynamic> created = rows.first;
      final String groupId = created['id'] as String;

      String? photoUrl;
      if (photoBytes != null) {
        photoUrl = await _uploadPhoto(
          groupId: groupId,
          bytes: photoBytes,
          fileExtension: photoExtension ?? 'jpg',
        );
        await _client
            .from('groups')
            .update(<String, dynamic>{'photo_url': photoUrl})
            .eq('id', groupId);
      }

      return Group.fromRow(
        <String, dynamic>{...created, 'photo_url': photoUrl},
        myRole: GroupRole.admin,
        memberCount: 1,
      );
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<void> updateGroup({
    required String groupId,
    required String name,
    String? description,
    Uint8List? photoBytes,
    String? photoExtension,
  }) async {
    try {
      String? photoUrl;
      if (photoBytes != null) {
        photoUrl = await _uploadPhoto(
          groupId: groupId,
          bytes: photoBytes,
          fileExtension: photoExtension ?? 'jpg',
        );
      }

      await _client
          .from('groups')
          .update(<String, dynamic>{
            'name': name.trim(),
            'description': _trimmedOrNull(description),
            'photo_url': ?photoUrl,
          })
          .eq('id', groupId);
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    try {
      await _client
          .from('groups')
          .update(<String, dynamic>{
            'deleted_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', groupId);
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<String> removeMember({
    required String groupId,
    required String userId,
  }) => _administrer('retirer_membre', groupId: groupId, userId: userId);

  @override
  Future<String> promoteToAdmin({
    required String groupId,
    required String userId,
  }) => _administrer('promouvoir_membre', groupId: groupId, userId: userId);

  @override
  Future<String> demoteToMember({
    required String groupId,
    required String userId,
  }) => _administrer('retrograder_membre', groupId: groupId, userId: userId);

  @override
  Future<String> setMembershipTerm({
    required String groupId,
    required String userId,
    required DateTime? expiresAt,
  }) async {
    try {
      final Object? result = await _client.rpc<Object?>(
        'definir_terme_adhesion',
        params: <String, dynamic>{
          'p_group_id': groupId,
          'p_user_id': userId,
          // `null` explicite, et non une clé absente : c'est lui qui rend
          // l'adhésion permanente.
          'p_expires_at': expiresAt?.toUtc().toIso8601String(),
        },
      );
      return (result as String?) ?? 'inconnu';
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  Future<String> _administrer(
    String fonction, {
    required String groupId,
    required String userId,
  }) async {
    try {
      final Object? result = await _client.rpc<Object?>(
        fonction,
        params: <String, dynamic>{'p_group_id': groupId, 'p_user_id': userId},
      );
      return (result as String?) ?? 'inconnu';
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<LeaveOutcome> leaveGroup(String groupId) async {
    try {
      // Départ, promotion éventuelle et suppression éventuelle tiennent dans
      // une seule transaction côté base : voir `quitter_groupe`.
      final Object? result = await _client.rpc<Object?>(
        'quitter_groupe',
        params: <String, dynamic>{'p_group_id': groupId},
      );
      return LeaveOutcome.fromDb(result as String?);
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<List<GroupInviteLink>> fetchInviteLinks(String groupId) async {
    try {
      final List<Map<String, dynamic>> rows = await _client
          .from('group_invite_links')
          .select()
          .eq('group_id', groupId)
          .order('created_at', ascending: false);
      return rows.map(GroupInviteLink.fromRow).toList();
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<GroupInviteLink> createInviteLink({
    required String groupId,
    int? maxUses,
    DateTime? membershipExpiresAt,
  }) async {
    final String? userId = _userId;
    if (userId == null) {
      throw const AuthFailure(
        'Votre session a expiré. Reconnectez-vous.',
        kind: AuthFailureKind.sessionExpired,
      );
    }

    try {
      final Map<String, dynamic> row = await _client
          .from('group_invite_links')
          .insert(<String, dynamic>{
            'group_id': groupId,
            'created_by': userId,
            'token': _newToken(),
            'max_uses': ?maxUses,
            'expires_at': DateTime.now()
                .toUtc()
                .add(AppConfig.inviteLinkLifetime)
                .toIso8601String(),
            // Deux dates, deux portées : `expires_at` borne la validité du
            // lien, celle-ci le terme de l'adhésion qu'il accorde.
            'membership_expires_at': ?membershipExpiresAt
                ?.toUtc()
                .toIso8601String(),
          })
          .select()
          .single();
      return GroupInviteLink.fromRow(row);
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<void> revokeInviteLink(String linkId) async {
    try {
      await _client
          .from('group_invite_links')
          .update(<String, dynamic>{
            'revoked_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', linkId);
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<GroupInvitePreview> previewInvite(String token) async {
    try {
      final List<Map<String, dynamic>> rows = await _client
          .rpc<dynamic>(
            'apercu_groupe_par_jeton',
            params: <String, dynamic>{'jeton': token},
          )
          .then(_asRows);

      if (rows.isEmpty) {
        return const GroupInvitePreview(status: InviteLinkStatus.invalide);
      }
      return GroupInvitePreview.fromRow(rows.first);
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<JoinOutcome> joinByToken(String token) async {
    try {
      final Object? result = await _client.rpc<Object?>(
        'rejoindre_groupe_par_jeton',
        params: <String, dynamic>{'jeton': token},
      );
      return JoinOutcome.fromDb(result as String?);
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<List<GroupInvitation>> fetchInvitations() async {
    if (_userId == null) return const <GroupInvitation>[];
    try {
      final List<Map<String, dynamic>> rows = await _client
          .rpc<dynamic>('mes_invitations')
          .then(_asRows);
      return rows.map(GroupInvitation.fromRow).toList();
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<GroupInvitationDetail> fetchInvitation(String invitationId) async {
    if (_userId == null) {
      return const GroupInvitationDetail(
        status: InvitationScreenStatus.introuvable,
      );
    }
    try {
      final List<Map<String, dynamic>> rows = await _client
          .rpc<dynamic>(
            'invitation_par_id',
            params: <String, dynamic>{'p_invitation': invitationId},
          )
          .then(_asRows);
      // La fonction rend toujours une ligne, `introuvable` comprise : une
      // liste vide ne peut donc venir que d'une lecture qui a mal tourné.
      if (rows.isEmpty) {
        return const GroupInvitationDetail(
          status: InvitationScreenStatus.introuvable,
        );
      }
      return GroupInvitationDetail.fromRow(rows.first);
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<String> invite({
    required String groupId,
    required String userId,
    DateTime? membershipExpiresAt,
  }) async {
    try {
      final Object? result = await _client.rpc<Object?>(
        'inviter_dans_groupe',
        params: <String, dynamic>{
          'p_group_id': groupId,
          'p_invitee': userId,
          'p_membership_expires_at': membershipExpiresAt
              ?.toUtc()
              .toIso8601String(),
        },
      );
      return (result as String?) ?? 'non_membre';
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<JoinOutcome> acceptInvitation(String invitationId) async {
    try {
      final Object? result = await _client.rpc<Object?>(
        'accepter_invitation',
        params: <String, dynamic>{'p_invitation_id': invitationId},
      );
      return JoinOutcome.fromDb(result as String?);
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<void> declineInvitation(String invitationId) async {
    try {
      await _client.rpc<Object?>(
        'refuser_invitation',
        params: <String, dynamic>{'p_invitation_id': invitationId},
      );
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  Future<String> _uploadPhoto({
    required String groupId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final String path =
        '$groupId/photo_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
    await _client.storage
        .from(AppConfig.groupPhotosBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: _contentTypeFor(fileExtension),
          ),
        );
    return _client.storage.from(AppConfig.groupPhotosBucket).getPublicUrl(path);
  }

  /// Jeton d'invitation : 16 octets tirés d'un générateur cryptographique,
  /// encodés sans caractère à échapper dans une URL.
  static String _newToken() {
    final Random random = Random.secure();
    final Uint8List bytes = Uint8List.fromList(
      List<int>.generate(
        AppConfig.inviteTokenBytes,
        (_) => random.nextInt(256),
      ),
    );
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static String? _trimmedOrNull(String? value) {
    final String trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Normalise le retour d'un `rpc` renvoyant un ensemble de lignes.
  static List<Map<String, dynamic>> _asRows(Object? result) {
    if (result is List) {
      return result.whereType<Map<String, dynamic>>().toList();
    }
    if (result is Map<String, dynamic>) return <Map<String, dynamic>>[result];
    return const <Map<String, dynamic>>[];
  }

  static String _contentTypeFor(String extension) =>
      switch (extension.toLowerCase()) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        'heic' => 'image/heic',
        _ => 'image/jpeg',
      };
}

/// Ce que `mes_groupes_apercu` rend pour un groupe.
class _GroupPreview {
  const _GroupPreview({required this.count, required this.avatars});

  final int count;
  final List<AvatarData> avatars;
}
