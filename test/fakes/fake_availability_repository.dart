import 'package:jelvo/features/availability/models/availability.dart';
import 'package:jelvo/features/availability/repository/availability_repository.dart';

/// Dépôt de disponibilités en mémoire, pour les tests de widget.
class FakeAvailabilityRepository implements AvailabilityRepository {
  FakeAvailabilityRepository({
    List<AvailabilitySlot>? slots,
    Map<String, PeerAvailability>? peers,
  }) : _slots = List<AvailabilitySlot>.of(slots ?? demoSlots()),
       _peers = peers ?? demoPeers;

  final List<AvailabilitySlot> _slots;
  final Map<String, PeerAvailability> _peers;

  /// Dernier appel reçu, pour les assertions.
  String? lastRemovedId;
  AvailabilityKind? lastSavedKind;
  DateTime? lastAskedAt;
  List<String>? lastAskedUsers;

  /// Le lundi 3 août 2026 est la date figée des tests : un créneau récurrent
  /// ce jour-là, et une exception le lendemain.
  static List<AvailabilitySlot> demoSlots() => <AvailabilitySlot>[
    const AvailabilitySlot(
      id: 'd1',
      kind: AvailabilityKind.recurring,
      status: AvailabilityStatus.available,
      start: 9 * 60,
      end: 12 * 60,
      weekday: DateTime.monday,
    ),
    AvailabilitySlot(
      id: 'd2',
      kind: AvailabilityKind.exception,
      status: AvailabilityStatus.unavailable,
      start: 8 * 60,
      end: 18 * 60,
      onDate: DateTime(2026, 8, 4),
    ),
  ];

  static const Map<String, PeerAvailability> demoPeers =
      <String, PeerAvailability>{
        'u2': PeerAvailability.available,
        'u3': PeerAvailability.unavailable,
      };

  @override
  Future<List<AvailabilitySlot>> fetchMine() async =>
      List<AvailabilitySlot>.of(_slots);

  @override
  Future<AvailabilitySlot> save({
    String? id,
    required AvailabilityKind kind,
    required AvailabilityStatus status,
    required int start,
    required int end,
    int? weekday,
    DateTime? onDate,
  }) async {
    lastSavedKind = kind;
    final AvailabilitySlot slot = AvailabilitySlot(
      id: id ?? 'd${_slots.length + 1}',
      kind: kind,
      status: status,
      start: start,
      end: end,
      weekday: weekday,
      onDate: onDate,
    );
    _slots
      ..removeWhere((AvailabilitySlot s) => s.id == slot.id)
      ..add(slot);
    return slot;
  }

  @override
  Future<bool> remove(String id) async {
    lastRemovedId = id;
    final int avant = _slots.length;
    _slots.removeWhere((AvailabilitySlot s) => s.id == id);
    return _slots.length < avant;
  }

  @override
  Future<Map<String, PeerAvailability>> statusesAt({
    required List<String> userIds,
    required DateTime at,
  }) async {
    lastAskedAt = at;
    lastAskedUsers = List<String>.of(userIds);
    return <String, PeerAvailability>{
      for (final String id in userIds)
        if (_peers.containsKey(id)) id: _peers[id]!,
    };
  }
}
