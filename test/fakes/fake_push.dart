import 'package:jelvo/features/notifications/push/push_service.dart';
import 'package:jelvo/features/notifications/repository/push_repository.dart';

/// Navigateur simulé.
///
/// Le vrai service parle à `Notification`, `ServiceWorker` et `PushManager` —
/// trois API que le harnais de test n'a pas. Ce qui est éprouvé ici, c'est donc
/// que **l'écran réagit correctement à chaque état**, pas que le navigateur se
/// comporte comme prévu : cela ne se vérifie que sur un vrai appareil.
class FakePushService implements PushService {
  FakePushService({
    this.statut = PushStatus.aAutoriser,
    this.autorisationAccordee = true,
  });

  PushStatus statut;

  /// Ce que répondra la boîte de dialogue du navigateur.
  bool autorisationAccordee;

  int abonnements = 0;
  int desabonnements = 0;

  static const PushSubscriptionData abonnementDemo = PushSubscriptionData(
    endpoint: 'https://push.exemple.test/abc',
    p256dh: 'cle-publique',
    auth: 'secret',
  );

  @override
  Future<PushStatus> status() async => statut;

  @override
  Future<PushSubscriptionData?> subscribe() async {
    abonnements++;
    if (!autorisationAccordee) {
      statut = PushStatus.refuse;
      return null;
    }
    statut = PushStatus.actif;
    return abonnementDemo;
  }

  @override
  Future<PushSubscriptionData?> currentSubscription() async =>
      statut == PushStatus.actif ? abonnementDemo : null;

  @override
  Future<String?> unsubscribe() async {
    desabonnements++;
    if (statut != PushStatus.actif) return null;
    statut = PushStatus.aAutoriser;
    return abonnementDemo.endpoint;
  }
}

/// Préférences et abonnements en mémoire.
class FakePushRepository implements PushRepository {
  FakePushRepository({List<NotificationPreference>? preferences})
    : _preferences = List<NotificationPreference>.of(
        preferences ?? demoPreferences(),
      );

  final List<NotificationPreference> _preferences;

  String? lastRegisteredEndpoint;
  String? lastForgottenEndpoint;
  String? lastToggledType;
  bool? lastToggledValue;
  int registrations = 0;

  /// Les sept types renvoyés par `types_de_notification()`, tous activés :
  /// le modèle est un opt-out. L'ordre et les libellés reprennent ceux du
  /// SQL — un écart ici ferait passer un test que la vraie liste échouerait.
  static List<NotificationPreference> demoPreferences() =>
      <NotificationPreference>[
        const NotificationPreference(
          type: 'chat_message',
          label: 'Nouveaux messages',
          description: 'Quand quelqu’un écrit dans un de vos groupes',
          enabled: true,
        ),
        const NotificationPreference(
          type: 'group_invitation',
          label: 'Invitations à un groupe',
          description: 'Quand on vous invite dans un groupe',
          enabled: true,
        ),
        const NotificationPreference(
          type: 'event_invitation',
          label: 'Invitations à un événement',
          description: 'Quand on vous convie à un événement',
          enabled: true,
        ),
        const NotificationPreference(
          type: 'task_assigned',
          label: 'Tâches assignées',
          description: 'Quand une tâche vous est confiée',
          enabled: true,
        ),
        const NotificationPreference(
          type: 'reminder',
          label: 'Rappels',
          description: 'Avant une tâche ou un événement',
          enabled: true,
        ),
        const NotificationPreference(
          type: 'event_response',
          label: 'Réponses aux événements',
          description:
              'Quand quelqu’un répond à un événement que vous organisez',
          enabled: true,
        ),
        const NotificationPreference(
          type: 'event_changed',
          label: 'Changements de date',
          description: 'Quand un événement auquel vous participez est déplacé',
          enabled: true,
        ),
      ];

  @override
  Future<List<NotificationPreference>> fetchPreferences() async =>
      List<NotificationPreference>.of(_preferences);

  @override
  Future<void> setPreference({
    required String type,
    required bool enabled,
  }) async {
    lastToggledType = type;
    lastToggledValue = enabled;
    final int index = _preferences.indexWhere(
      (NotificationPreference p) => p.type == type,
    );
    if (index != -1) {
      _preferences[index] = _preferences[index].copyWith(enabled: enabled);
    }
  }

  @override
  Future<void> registerSubscription({
    required String endpoint,
    required String p256dh,
    required String auth,
  }) async {
    registrations++;
    lastRegisteredEndpoint = endpoint;
  }

  @override
  Future<void> forgetSubscription(String endpoint) async {
    lastForgottenEndpoint = endpoint;
  }
}

/// Dépôt qui refuse toute écriture, pour éprouver le retour en arrière de
/// l'interrupteur optimiste.
class FailingPushRepository extends FakePushRepository {
  @override
  Future<void> setPreference({
    required String type,
    required bool enabled,
  }) async {
    throw Exception('réseau indisponible');
  }
}
