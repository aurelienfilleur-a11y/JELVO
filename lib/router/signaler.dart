import 'package:flutter/widgets.dart';

import '../features/signalements/models/signalement.dart';
import '../features/signalements/widgets/report_sheet.dart';

/// Ouvrir la feuille de signalement, d'où qu'on vienne.
///
/// **Elle vit ici pour la même raison que `ouvrirProfilDe`** : trois features
/// l'appellent — une conversation, un écran de groupe, un profil —, et *une
/// feature ne lit jamais les widgets d'une autre*. `router/` est la couche
/// qui connaît déjà toutes les features ; les trois appelants n'importent donc
/// que ce fichier.
///
/// `ReportSheet` n'a pas pu monter dans `core/widgets` comme `CoverBanner` :
/// il écrit, donc il lit un provider de la feature, et `core` ne connaît
/// aucune feature. Lui passer un rappel à la place aurait recopié le câblage
/// aux trois sites d'appel.
extension Signaler on BuildContext {
  /// Signaler un message, par son identifiant. [nomVise] titre la feuille.
  Future<void> signalerMessage(String messageId, {String? nomVise}) {
    if (messageId.isEmpty) return Future<void>.value();
    return ReportSheet.ouvrir(
      this,
      cible: SignalementCible.message,
      cibleId: messageId,
      nomVise: nomVise,
    );
  }

  Future<void> signalerGroupe(String groupId, {String? nomVise}) {
    if (groupId.isEmpty) return Future<void>.value();
    return ReportSheet.ouvrir(
      this,
      cible: SignalementCible.group,
      cibleId: groupId,
      nomVise: nomVise,
    );
  }

  Future<void> signalerProfil(String userId, {String? nomVise}) {
    if (userId.isEmpty) return Future<void>.value();
    return ReportSheet.ouvrir(
      this,
      cible: SignalementCible.profile,
      cibleId: userId,
      nomVise: nomVise,
    );
  }
}
