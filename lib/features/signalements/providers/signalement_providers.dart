import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/supabase_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/blocage.dart';
import '../models/signalement.dart';
import '../repository/signalement_repository.dart';

/// Dépôt des signalements. Surchargé dans les tests par un faux dépôt.
final Provider<SignalementRepository> signalementRepositoryProvider =
    Provider<SignalementRepository>(
      (Ref ref) =>
          SupabaseSignalementRepository(ref.watch(supabaseClientProvider)),
    );

/// Vrai si l'utilisateur peut lire la file de modération.
///
/// **Ce provider décide d'un affichage, jamais d'un droit.** La règle est
/// tenue par la base : les trois fonctions de modération appellent
/// `est_moderateur()` dans leur corps, et la table n'a aucun privilège. Le
/// cacher ici n'est donc pas la sécurité, c'est la politesse — ne pas
/// montrer une ligne qui ne mènerait nulle part.
final FutureProvider<bool> estModerateurProvider = FutureProvider<bool>((
  Ref ref,
) {
  ref.watch(authStatusProvider);
  return ref.watch(signalementRepositoryProvider).estModerateur();
});

/// La file de modération. `false` : ce qui reste à traiter ; `true` : l'archive.
final signalementsProvider =
    AsyncNotifierProvider.family<SignalementsNotifier, List<Signalement>, bool>(
      SignalementsNotifier.new,
    );

/// L'argument passe par le constructeur, comme `ConversationNotifier` : c'est
/// la forme que Riverpod 3 impose à une famille ici.
class SignalementsNotifier extends AsyncNotifier<List<Signalement>> {
  SignalementsNotifier(this.traites);

  final bool traites;

  @override
  Future<List<Signalement>> build() {
    ref.watch(authStatusProvider);
    return ref
        .watch(signalementRepositoryProvider)
        .fetchSignalements(traites: traites);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref
          .read(signalementRepositoryProvider)
          .fetchSignalements(traites: traites),
    );
  }
}

/// Les personnes que l'on a bloquées.
///
/// Lu par l'écran de la liste **et** par le sélecteur d'assignés, qui les
/// écarte de ses candidats : le déclencheur `refuser_si_bloque` lèverait, et
/// mieux vaut ne pas proposer le geste que de l'offrir pour obtenir un refus.
final AsyncNotifierProvider<BloquesNotifier, List<PersonneBloquee>>
bloquesProvider = AsyncNotifierProvider<BloquesNotifier, List<PersonneBloquee>>(
  BloquesNotifier.new,
);

class BloquesNotifier extends AsyncNotifier<List<PersonneBloquee>> {
  @override
  Future<List<PersonneBloquee>> build() {
    ref.watch(authStatusProvider);
    return ref.watch(signalementRepositoryProvider).fetchBloques();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(signalementRepositoryProvider).fetchBloques(),
    );
  }
}

/// Les identifiants bloqués, pour un filtrage en mémoire.
final Provider<Set<String>> idsBloquesProvider = Provider<Set<String>>((
  Ref ref,
) {
  final List<PersonneBloquee> liste =
      ref.watch(bloquesProvider).value ?? const <PersonneBloquee>[];
  return liste.map((PersonneBloquee p) => p.userId).toSet();
});

/// Les écritures passent par un objet d'actions, jamais par le dépôt depuis
/// un widget.
final Provider<SignalementActions> signalementActionsProvider =
    Provider<SignalementActions>(SignalementActions.new);

class SignalementActions {
  const SignalementActions(this._ref);

  final Ref _ref;

  SignalementRepository get _repo => _ref.read(signalementRepositoryProvider);

  Future<SignalementOutcome> signaler({
    required SignalementCible cible,
    required String cibleId,
    required SignalementMotif motif,
    String? commentaire,
  }) {
    return _repo.signaler(
      cible: cible,
      cibleId: cibleId,
      motif: motif,
      commentaire: commentaire,
    );
  }

  /// **Les deux onglets sont relus**, et pas seulement celui qu'on regarde :
  /// traiter fait passer la ligne de l'un à l'autre, et ne rafraîchir que la
  /// file laisserait l'archive en retard jusqu'à la prochaine ouverture.
  Future<SignalementOutcome> traiter({
    required String id,
    String? note,
    bool traite = true,
  }) async {
    final SignalementOutcome issue = await _repo.traiter(
      id: id,
      note: note,
      traite: traite,
    );
    if (issue.isSuccess) await _relireLesDeux();
    return issue;
  }

  Future<SignalementOutcome> supprimerMessage(String signalementId) async {
    final SignalementOutcome issue = await _repo.supprimerMessage(
      signalementId,
    );
    // Relu même sur « deja_supprime » : si le message était déjà parti, c'est
    // justement l'état affiché qui était en retard.
    await _relireLesDeux();
    return issue;
  }

  /// Bloquer **relit le profil et la liste** : la relation change, et sans
  /// relecture l'écran continuerait d'offrir « Bloquer » à quelqu'un qu'on
  /// vient de bloquer. La règle est celle du profil consultable, étendue ici.
  Future<BlocageOutcome> bloquer(String userId) async {
    final BlocageOutcome issue = await _repo.bloquer(userId);
    if (issue.isSuccess) await _ref.read(bloquesProvider.notifier).refresh();
    return issue;
  }

  Future<BlocageOutcome> debloquer(String userId) async {
    final BlocageOutcome issue = await _repo.debloquer(userId);
    if (issue.isSuccess) await _ref.read(bloquesProvider.notifier).refresh();
    return issue;
  }

  Future<void> _relireLesDeux() async {
    await _ref.read(signalementsProvider(false).notifier).refresh();
    await _ref.read(signalementsProvider(true).notifier).refresh();
  }
}
