import 'push_service.dart';

/// Talon des plateformes sans navigateur : machine virtuelle des tests, et
/// cibles Android et iOS natives.
///
/// Il ne feint rien. Web Push n'existe pas là, et l'écran de réglages doit le
/// dire plutôt que d'offrir un bouton qui échouerait.
class PushServiceStub implements PushService {
  const PushServiceStub();

  @override
  Future<PushStatus> status() async => PushStatus.nonSupporte;

  @override
  Future<PushSubscriptionData?> subscribe() async => null;

  @override
  Future<PushSubscriptionData?> currentSubscription() async => null;

  @override
  Future<String?> unsubscribe() async => null;
}

PushService creerServicePushImpl() => const PushServiceStub();
