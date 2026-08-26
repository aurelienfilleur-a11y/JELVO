import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/supabase_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../../calendar/models/calendar_event.dart';
import '../../calendar/providers/calendar_providers.dart';
import '../../groups/providers/group_providers.dart';
import '../../tasks/models/task.dart';
import '../../tasks/providers/task_providers.dart';
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

/// Les trois chiffres de la carte « Mes statistiques ».
///
/// **Aucun n'est inventé** : les trois se lisent sur des listes que
/// l'application charge déjà.
@immutable
class ProfileStats {
  const ProfileStats({
    required this.groups,
    required this.events,
    required this.completedTasks,
  });

  /// Groupes dont l'adhésion est active. Exact.
  final int groups;

  /// Événements visibles dans l'agenda — ceux de ses groupes et ses
  /// rendez-vous personnels, passés comme à venir. `mon_agenda` est appelée
  /// sans bornes de dates, donc rien n'est tronqué.
  final int events;

  /// Tâches terminées **visibles**, et non « terminées par moi » : `tasks` ne
  /// porte pas de `completed_by`, seulement `completed_at`. Le libellé dit
  /// donc « Tâches terminées », pas « réalisées » — attribuer l'action à
  /// quelqu'un serait inventer ce que la base ne sait pas.
  final int completedTasks;
}

/// Agrège les trois compteurs depuis les listes déjà chargées.
///
/// Le profil ne connaît ainsi aucun dépôt de plus : il lit les mêmes
/// providers que les écrans qui affichent ces listes, et un chiffre ne peut
/// donc pas contredire ce qu'on voit ailleurs.
final Provider<ProfileStats> profileStatsProvider = Provider<ProfileStats>((
  Ref ref,
) {
  final List<CalendarEvent> evenements =
      ref.watch(eventsProvider).value ?? const <CalendarEvent>[];
  final List<Task> taches = ref.watch(tasksProvider).value ?? const <Task>[];

  return ProfileStats(
    groups: ref.watch(activeGroupsProvider).length,
    events: evenements.length,
    completedTasks: taches.where((Task t) => t.isDone).length,
  );
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

  /// Enregistre les seuls prénom et nom, en conservant la bio.
  ///
  /// Symétrique de [saveBio] : depuis que les deux se modifient à des endroits
  /// différents, chaque écriture doit relire ce qu'elle ne touche pas. Le
  /// faire ici plutôt que dans l'écran rend l'oubli impossible.
  Future<void> saveNames({
    required String firstName,
    required String lastName,
  }) async {
    final Profile? profil = await _ref.read(currentProfileProvider.future);
    await save(
      firstName: firstName,
      lastName: lastName,
      bio: profil?.bio ?? '',
    );
  }

  /// Enregistre la seule bio, en conservant le prénom et le nom.
  ///
  /// La bio se modifie **sur place**, sur la ligne où elle se lit ; l'écran de
  /// modification ne porte plus qu'elle-mêmes prénom et nom. Le widget qui
  /// appelle ceci ne connaît donc que la bio, et n'a pas à traîner les deux
  /// autres champs pour ne pas les écraser.
  Future<void> saveBio(String bio) async {
    final Profile? profil = await _ref.read(currentProfileProvider.future);
    if (profil == null) {
      throw StateError('Aucun profil chargé : la bio ne peut pas être écrite.');
    }
    await save(
      firstName: profil.firstName,
      lastName: profil.lastName,
      bio: bio,
    );
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

  /// Choisit un avatar prédéfini. La photo éventuelle est effacée dans la
  /// même écriture — le dernier choisi l'emporte.
  Future<void> choisirAvatar(String avatarId) async {
    await _ref
        .read(profileRepositoryProvider)
        .choisirAvatarPredefini(userId: _userId, avatarId: avatarId);
    _ref.invalidate(currentProfileProvider);
  }

  /// Retour aux initiales.
  Future<void> effacerAvatar() async {
    await _ref.read(profileRepositoryProvider).effacerAvatar(_userId);
    _ref.invalidate(currentProfileProvider);
  }
}
