import 'dart:js_interop';

// Interopérabilité déclarée à la main plutôt qu'en tirant `package:web` :
// `dart:js_interop` est fourni par le SDK et n'ajoute aucune dépendance au
// projet. Même choix que `push_service_web.dart`.

/// La fonction que pose `web/index.html`.
///
/// Déclarée **nullable** à dessein : si la page était remplacée par une autre
/// — un gabarit régénéré, un hébergement qui sert son propre `index.html` —,
/// le symbole serait simplement absent. Mieux vaut alors une apparence qui ne
/// suit plus le réglage qu'une exception au premier changement de thème.
@JS('jelvoAppliquerApparence')
external JSFunction? get _appliquer;

void appliquerApparenceDuNavigateur(String mot) {
  _appliquer?.callAsFunction(null, mot.toJS);
}
