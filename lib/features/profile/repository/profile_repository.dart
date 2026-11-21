import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/app_config.dart';
import '../../auth/models/auth_failure.dart';
import '../models/anniversaire.dart';
import '../models/profil_consultable.dart';
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

  /// Pose ou efface l'anniversaire — `null` pour l'effacer.
  ///
  /// Une écriture à part, et non un paramètre d'[updateProfile], pour la
  /// raison qui vaut déjà pour la bio : les deux se modifient à des endroits
  /// différents, et une écriture conjointe obligerait chaque appelant à
  /// relire ce qu'il ne touche pas.
  Future<Profile> definirAnniversaire({
    required String userId,
    required Anniversaire? anniversaire,
  });

  /// Le profil de quelqu'un d'autre, ou `null` si l'identifiant est inconnu.
  ///
  /// **Passe par `profil_consultable` et jamais par `profiles`.** Depuis la
  /// tranche 7, `profiles_select` vaut `id = auth.uid() or
  /// has_social_link(id)` : une lecture directe ne rendrait rien pour une
  /// personne hors de ses contacts et de ses groupes, et l'écran se
  /// présenterait vide. C'est la fonction, et non cet appel, qui décide de ce
  /// qui sort — les statistiques et la disponibilité arrivent à `null` dès
  /// qu'on n'est pas un contact accepté.
  Future<ProfilConsultable?> fetchProfilConsultable(String userId);

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
  Future<ProfilConsultable?> fetchProfilConsultable(String userId) async {
    try {
      final List<dynamic> rows = await _client.rpc(
        'profil_consultable',
        params: <String, dynamic>{'p_user_id': userId},
      );
      // Zéro ligne signifie « cet identifiant n'existe pas », et c'est le seul
      // état dégradé d'un profil. `invitation_par_id` rend au contraire
      // toujours une ligne, parce qu'une invitation en a quatre à distinguer.
      if (rows.isEmpty) return null;
      return ProfilConsultable.depuisLigne(rows.first as Map<String, dynamic>);
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
  Future<Profile> definirAnniversaire({
    required String userId,
    required Anniversaire? anniversaire,
  }) async {
    try {
      final Map<String, dynamic> row = await _client
          .from('profiles')
          // Les deux colonnes dans la **même** écriture : la contrainte de la
          // base refuse une moitié de date, et c'est elle qui garantit qu'on
          // ne puisse pas afficher un « 12 » sans mois.
          .update(anniversaire?.versLigne ?? Anniversaire.versLigneVide)
          .eq('id', userId)
          // Le `select()` relit la ligne : l'écriture passe par un `grant` de
          // colonnes, et une colonne oubliée côté SQL ne toucherait aucune
          // ligne sans lever — PostgREST répondrait 200.
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
    // texte-en-dur-autorise: chemin dans le bucket, pas une phrase.
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
