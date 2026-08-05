import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/app_config.dart';
import '../../auth/models/auth_failure.dart';
import '../models/profile.dart';

abstract interface class ProfileRepository {
  /// Profil d'un utilisateur, ou `null` si la ligne n'existe pas encore.
  Future<Profile?> fetchProfile(String userId);

  /// Met à jour les champs modifiables du profil.
  Future<Profile> updateProfile({
    required String userId,
    required String firstName,
    required String lastName,
    required String bio,
  });

  /// Remplace la photo de profil et renvoie le profil à jour.
  Future<Profile> updateAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileExtension,
  });
}

class SupabaseProfileRepository implements ProfileRepository {
  const SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Profile?> fetchProfile(String userId) async {
    try {
      final Map<String, dynamic>? row = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return row == null ? null : Profile.fromMap(row);
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<Profile> updateProfile({
    required String userId,
    required String firstName,
    required String lastName,
    required String bio,
  }) async {
    try {
      final Map<String, dynamic> row = await _client
          .from('profiles')
          .update(<String, dynamic>{
            'first_name': firstName,
            'last_name': lastName,
            // Une bio vidée redevient nulle plutôt qu'une chaîne vide.
            'bio': bio.isEmpty ? null : bio,
          })
          .eq('id', userId)
          .select()
          .single();
      return Profile.fromMap(row);
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<Profile> updateAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final String path =
        '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
    try {
      await _client.storage
          .from(AppConfig.avatarsBucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: _contentTypeFor(fileExtension),
            ),
          );
      final String url = _client.storage
          .from(AppConfig.avatarsBucket)
          .getPublicUrl(path);

      final Map<String, dynamic> row = await _client
          .from('profiles')
          .update(<String, dynamic>{'avatar_url': url})
          .eq('id', userId)
          .select()
          .single();
      return Profile.fromMap(row);
    } catch (error) {
      throw AuthFailure.from(error);
    }
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
