import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<void> removeMember({required String groupId, required String userId});

  Future<void> promoteToAdmin({
    required String groupId,
    required String userId,
  });

  Future<LeaveOutcome> leaveGroup(String groupId);

  // — Invitations par lien —

  Future<List<GroupInviteLink>> fetchInviteLinks(String groupId);

  Future<GroupInviteLink> createInviteLink({
    required String groupId,
    int? maxUses,
  });

  Future<void> revokeInviteLink(String linkId);

  /// Aperçu public d'un lien, accessible sans session.
  Future<GroupInvitePreview> previewInvite(String token);

  Future<JoinOutcome> joinByToken(String token);

  // — Invitations nominatives —

  Future<List<GroupInvitation>> fetchInvitations();

  Future<String> invite({required String groupId, required String userId});

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

      final Map<String, int> counts = await _memberCounts(
        rows
            .map(
              (Map<String, dynamic> r) =>
                  (r['groups'] as Map<String, dynamic>)['id'] as String,
            )
            .toList(),
      );

      final List<Group> groups = rows.map((Map<String, dynamic> row) {
        final Map<String, dynamic> groupRow =
            row['groups'] as Map<String, dynamic>;
        return Group.fromRow(
          groupRow,
          myRole: GroupRole.fromDb(row['role'] as String?),
          memberCount: counts[groupRow['id'] as String] ?? 0,
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

  /// Effectif de chaque groupe, en une requête plutôt qu'une par carte.
  Future<Map<String, int>> _memberCounts(List<String> groupIds) async {
    if (groupIds.isEmpty) return const <String, int>{};

    final List<Map<String, dynamic>> rows = await _client
        .from('group_members')
        .select('group_id')
        .inFilter('group_id', groupIds)
        .or(_activeMembership);

    final Map<String, int> counts = <String, int>{};
    for (final Map<String, dynamic> row in rows) {
      final String id = row['group_id'] as String;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
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

      final Map<String, int> counts = await _memberCounts(<String>[groupId]);

      return Group.fromRow(
        row,
        myRole: GroupRole.fromDb(membership?['role'] as String?),
        memberCount: counts[groupId] ?? 0,
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
      final Map<String, dynamic> created = await _client
          .from('groups')
          .insert(<String, dynamic>{
            'name': name.trim(),
            'description': ?_trimmedOrNull(description),
            'is_private': isPrivate,
            'created_by': userId,
          })
          .select()
          .single();

      final String groupId = created['id'] as String;

      // L'auteur devient administrateur : sans cette ligne, il ne serait même
      // pas membre de son propre groupe.
      await _client.from('group_members').insert(<String, dynamic>{
        'group_id': groupId,
        'user_id': userId,
        'role': GroupRole.admin.dbValue,
      });

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
  Future<void> removeMember({
    required String groupId,
    required String userId,
  }) async {
    try {
      await _client
          .from('group_members')
          .delete()
          .eq('group_id', groupId)
          .eq('user_id', userId);
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<void> promoteToAdmin({
    required String groupId,
    required String userId,
  }) async {
    try {
      await _client
          .from('group_members')
          .update(<String, dynamic>{'role': GroupRole.admin.dbValue})
          .eq('group_id', groupId)
          .eq('user_id', userId);
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
  Future<String> invite({
    required String groupId,
    required String userId,
  }) async {
    try {
      final Object? result = await _client.rpc<Object?>(
        'inviter_dans_groupe',
        params: <String, dynamic>{'p_group_id': groupId, 'p_invitee': userId},
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
