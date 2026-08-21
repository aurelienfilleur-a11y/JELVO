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
  /// Choisit un avatar prédéfini, et **efface la photo** dans la même
  /// écriture.
  ///
  /// Un profil a une photo **ou** un avatar prédéfini, jamais les deux : le
  /// dernier choisi l'emporte. Les deux colonnes sont donc écrites ensemble,
  /// ce qui rend la règle atomique — un déclencheur ferait la même chose de
  /// façon moins lisible, et il n'y a qu'un seul écrivain.
  Future<Profile> choisirAvatarPredefini({
    required String userId,
    required String avatarId,
  });

  /// Revient aux initiales : ni photo, ni avatar prédéfini.
  Future<Profile> effacerAvatar(String userId);

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
          // `avatar_preset` est vidé dans la **même** écriture : sans cela,
          // la lecture préférerait l'avatar prédéfini et la photo qu'on vient
          // de téléverser resterait invisible.
          .update(<String, dynamic>{'avatar_url': url, 'avatar_preset': null})
          .eq('id', userId)
          .select()
          .single();
      return Profile.fromMap(row);
    } catch (error) {
      throw AuthFailure.from(error);
    }
  }

  @override
  Future<Profile> choisirAvatarPredefini({
    required String userId,
    required String avatarId,
  }) async {
    try {
      final Map<String, dynamic> row = await _client
          .from('profiles')
          .update(<String, dynamic>{
            'avatar_preset': avatarId,
            'avatar_url': null,
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
  Future<Profile> effacerAvatar(String userId) async {
    try {
      final Map<String, dynamic> row = await _client
          .from('profiles')
          .update(<String, dynamic>{'avatar_preset': null, 'avatar_url': null})
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
