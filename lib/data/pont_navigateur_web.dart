import 'dart:js_interop';

import 'pont_navigateur.dart';

// Interopérabilité déclarée à la main plutôt qu'en tirant `package:web` :
// `dart:js_interop` est fourni par le SDK et n'ajoute aucune dépendance au
// projet. Même choix que `push_service_web.dart`.

/// Les deux fonctions que pose `web/index.html`.
///
/// Déclarées **nullables** à dessein : si la page était remplacée par une
/// autre — un gabarit régénéré, un hébergement qui sert son propre
/// `index.html` —, les symboles seraient simplement absents. Mieux vaut alors
/// une apparence qui ne suit plus le réglage qu'une exception au premier
/// changement de thème.
@JS('jelvoAppliquerApparence')
external JSFunction? get _appliquerApparence;

@JS('jelvoApplicationPrete')
external JSFunction? get _applicationPrete;

class PontNavigateurWeb implements PontNavigateur {
  const PontNavigateurWeb();

  @override
  void appliquerApparence(String mot) {
    _appliquerApparence?.callAsFunction(null, mot.toJS);
  }

  @override
  void applicationPrete() {
    _applicationPrete?.callAsFunction(null);
  }
}

PontNavigateur creerPont() => const PontNavigateurWeb();
