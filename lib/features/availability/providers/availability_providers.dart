import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/supabase_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/availability.dart';
import '../repository/availability_repository.dart';

/// Dépôt des disponibilités. Surchargé dans les tests par un faux dépôt.
final Provider<AvailabilityRepository> availabilityRepositoryProvider =
    Provider<AvailabilityRepository>(
      (Ref ref) =>
          SupabaseAvailabilityRepository(ref.watch(supabaseClientProvider)),
    );

/// Ses propres créneaux.
final AsyncNotifierProvider<AvailabilityNotifier, List<AvailabilitySlot>>
myAvailabilityProvider =
    AsyncNotifierProvider<AvailabilityNotifier, List<AvailabilitySlot>>(
      AvailabilityNotifier.new,
    );

class AvailabilityNotifier extends AsyncNotifier<List<AvailabilitySlot>> {
  @override
  Future<List<AvailabilitySlot>> build() {
    ref.watch(authStatusProvider);
    return ref.watch(availabilityRepositoryProvider).fetchMine();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(availabilityRepositoryProvider).fetchMine(),
    );
  }
}

/// Créneaux récurrents, groupés par jour de la semaine.
final Provider<Map<int, List<AvailabilitySlot>>> recurringByWeekdayProvider =
    Provider<Map<int, List<AvailabilitySlot>>>((Ref ref) {
      final Map<int, List<AvailabilitySlot>> parJour =
          <int, List<AvailabilitySlot>>{};
      for (final AvailabilitySlot slot
          in ref.watch(myAvailabilityProvider).value ??
              const <AvailabilitySlot>[]) {
        if (slot.kind != AvailabilityKind.recurring) continue;
        final int jour = slot.weekday ?? 1;
        (parJour[jour] ??= <AvailabilitySlot>[]).add(slot);
      }
      for (final List<AvailabilitySlot> creneaux in parJour.values) {
        creneaux.sort(
          (AvailabilitySlot a, AvailabilitySlot b) =>
              a.start.compareTo(b.start),
        );
      }
      return parJour;
    });

/// Créneaux exceptionnels, du plus proche au plus lointain.
final Provider<List<AvailabilitySlot>>
exceptionSlotsProvider = Provider<List<AvailabilitySlot>>((Ref ref) {
  final List<AvailabilitySlot> exceptions =
      (ref.watch(myAvailabilityProvider).value ?? const <AvailabilitySlot>[])
          .where((AvailabilitySlot s) => s.kind == AvailabilityKind.exception)
          .toList();
  exceptions.sort((AvailabilitySlot a, AvailabilitySlot b) {
    final int jours = (a.onDate ?? DateTime(2100)).compareTo(
      b.onDate ?? DateTime(2100),
    );
    return jours != 0 ? jours : a.start.compareTo(b.start);
  });
  return exceptions;
});

/// Créneaux qui s'appliquent à une journée donnée, dans l'ordre des heures.
///
/// Une exception posée ce jour-là **remplace** la règle hebdomadaire : c'est
/// tout l'objet d'une exception, et les cumuler ferait apparaître deux fois la
/// même journée.
final slotsForDayProvider = Provider.family<List<AvailabilitySlot>, DateTime>((
  Ref ref,
  DateTime jour,
) {
  final List<AvailabilitySlot> tous =
      ref.watch(myAvailabilityProvider).value ?? const <AvailabilitySlot>[];

  bool memeJour(DateTime? a) =>
      a != null &&
      a.year == jour.year &&
      a.month == jour.month &&
      a.day == jour.day;

  final List<AvailabilitySlot> exceptions = tous
      .where(
        (AvailabilitySlot s) =>
            s.kind == AvailabilityKind.exception && memeJour(s.onDate),
      )
      .toList();

  final List<AvailabilitySlot> retenus = exceptions.isNotEmpty
      ? exceptions
      : tous
            .where(
              (AvailabilitySlot s) =>
                  s.kind == AvailabilityKind.recurring &&
                  s.weekday == jour.weekday,
            )
            .toList();

  retenus.sort(
    (AvailabilitySlot a, AvailabilitySlot b) => a.start.compareTo(b.start),
  );
  return retenus;
});

/// Temps déclaré disponible sur une journée donnée, en minutes.
final availableMinutesForDayProvider = Provider.family<int, DateTime>(
  (Ref ref, DateTime jour) => ref
      .watch(slotsForDayProvider(jour))
      .where((AvailabilitySlot s) => s.status == AvailabilityStatus.available)
      .fold<int>(
        0,
        (int total, AvailabilitySlot s) => total + (s.end - s.start),
      ),
);

/// Statuts de plusieurs personnes à un instant donné, pour l'écran de
/// création d'événement. `autoDispose` : la question ne vaut que le temps du
/// formulaire.
final peerAvailabilityProvider = FutureProvider.autoDispose
    .family<Map<String, PeerAvailability>, ({List<String> users, DateTime at})>(
      (Ref ref, ({List<String> users, DateTime at}) argument) => ref
          .watch(availabilityRepositoryProvider)
          .statusesAt(userIds: argument.users, at: argument.at),
    );

/// Écritures. Les widgets ne touchent jamais au dépôt.
final Provider<AvailabilityActions> availabilityActionsProvider =
    Provider<AvailabilityActions>(AvailabilityActions.new);

class AvailabilityActions {
  const AvailabilityActions(this._ref);

  final Ref _ref;

  Future<void> save({
    String? id,
    required AvailabilityKind kind,
    required AvailabilityStatus status,
    required int start,
    required int end,
    int? weekday,
    DateTime? onDate,
  }) async {
    await _ref
        .read(availabilityRepositoryProvider)
        .save(
          id: id,
          kind: kind,
          status: status,
          start: start,
          end: end,
          weekday: weekday,
          onDate: onDate,
        );
    await _refresh();
  }

  /// Renvoie faux si rien n'a été retiré — la fonction SQL le dit, et c'est
  /// elle qui fait foi, non l'absence d'exception.
  Future<bool> remove(String id) async {
    final bool retire = await _ref
        .read(availabilityRepositoryProvider)
        .remove(id);
    if (retire) await _refresh();
    return retire;
  }

  Future<void> _refresh() =>
      _ref.read(myAvailabilityProvider.notifier).refresh();
}
