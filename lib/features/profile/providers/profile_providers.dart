import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/supabase_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/profile.dart';
import '../repository/profile_repository.dart';

final Provider<ProfileRepository> profileRepositoryProvider =
    Provider<ProfileRepository>(
      (Ref ref) => SupabaseProfileRepository(ref.watch(supabaseClientProvider)),
    );

/// Profil de l'utilisateur connecté.
///
/// Renvoie `null` tant qu'aucune session n'est ouverte, ou si la ligne
/// `profiles` n'a pas encore été créée.
final FutureProvider<Profile?> currentProfileProvider =
    FutureProvider<Profile?>((Ref ref) async {
      final String? userId = ref.watch(currentUserIdProvider);
      if (userId == null) return null;
      return ref.watch(profileRepositoryProvider).fetchProfile(userId);
    });

/// Écritures sur le profil, exposées aux écrans.
final Provider<ProfileActions> profileActionsProvider =
    Provider<ProfileActions>((Ref ref) => ProfileActions(ref));

class ProfileActions {
  const ProfileActions(this._ref);

  final Ref _ref;

  String get _userId {
    final String? id = _ref.read(currentUserIdProvider);
    if (id == null) {
      throw StateError('Aucune session ouverte : profil inaccessible.');
    }
    return id;
  }

  Future<void> save({
    required String firstName,
    required String lastName,
    required String bio,
  }) async {
    await _ref
        .read(profileRepositoryProvider)
        .updateProfile(
          userId: _userId,
          firstName: firstName,
          lastName: lastName,
          bio: bio,
        );
    _ref.invalidate(currentProfileProvider);
  }

  Future<void> changeAvatar(Uint8List bytes, String fileExtension) async {
    await _ref
        .read(profileRepositoryProvider)
        .updateAvatar(
          userId: _userId,
          bytes: bytes,
          fileExtension: fileExtension,
        );
    _ref.invalidate(currentProfileProvider);
  }
}
