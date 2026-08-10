import 'package:jelvo/features/notifications/models/app_notification.dart';
import 'package:jelvo/features/notifications/repository/notification_repository.dart';

/// Boîte de notifications en mémoire, pour les tests de widget.
class FakeNotificationRepository implements NotificationRepository {
  FakeNotificationRepository({List<AppNotification>? notifications})
    : _notifications = List<AppNotification>.of(
        notifications ?? demoNotifications,
      );

  final List<AppNotification> _notifications;

  /// Dernier appel reçu, pour les assertions.
  String? lastReadId;
  int markAllReadCount = 0;

  /// Nombre de relectures. Une action qui referme une notification côté base
  /// doit relire la boîte : sans cela, la ligne resterait à l'écran.
  int fetchCount = 0;

  static final List<AppNotification> demoNotifications = <AppNotification>[
    AppNotification(
      id: 'n1',
      type: NotificationType.groupInvitation,
      payload: const <String, dynamic>{
        'invitation_id': 'i1',
        'group_id': 'g2',
        'group_name': 'Vacances en Corse',
        'inviter_name': 'Léa Marchand',
      },
      createdAt: DateTime(2026, 8, 3, 8),
    ),
    AppNotification(
      id: 'n2',
      type: NotificationType.contactRequest,
      payload: const <String, dynamic>{
        'requester_id': 'u4',
        'pseudo': 'noah.delacroix',
        'name': 'Noah Delacroix',
      },
      createdAt: DateTime(2026, 8, 2, 19),
    ),
    AppNotification(
      id: 'n3',
      type: NotificationType.contactRequest,
      payload: const <String, dynamic>{
        'requester_id': 'u5',
        'name': 'Sarah Nguyen',
      },
      readAt: DateTime(2026, 8, 2),
      createdAt: DateTime(2026, 8, 1, 10),
    ),
  ];

  @override
  Future<List<AppNotification>> fetchNotifications() async {
    fetchCount++;
    return List<AppNotification>.of(_notifications);
  }

  @override
  Future<void> markRead(String id) async {
    lastReadId = id;
    final int index = _notifications.indexWhere(
      (AppNotification n) => n.id == id,
    );
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(
        readAt: DateTime(2026, 8, 3, 9),
      );
    }
  }

  @override
  Future<void> markAllRead() async {
    markAllReadCount++;
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(
        readAt: _notifications[i].readAt ?? DateTime(2026, 8, 3, 9),
      );
    }
  }
}
