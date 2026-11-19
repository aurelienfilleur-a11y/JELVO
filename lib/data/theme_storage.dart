import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'session_persistence.dart';

/// Se souvient de l'apparence choisie : claire, sombre, ou celle du téléphone.
///
/// **Ce réglage ne vit pas en base, et c'est un choix.** `profiles` pourrait
/// le porter — mais l'apparence dépend de l'écran qu'on a sous les yeux :
/// sombre le soir sur le téléphone, clair sur l'ordinateur du bureau. Un
/// réglage de compte imposerait le même aux deux. C'est la même raison que
/// « Se souvenir de moi », et la même brique : un `LocalStorage` de gotrue
/// détourné, sous la clé `jelvo-apparence`.
///
/// Il est lu dans `main()` **avant `runApp`**. Sans cela, l'application
/// s'ouvrirait en clair puis basculerait en sombre à la première image : c'est
/// exactement le clignotement qu'on veut éviter, et le seul moyen de ne pas
/// l'avoir est de connaître la valeur avant le premier rendu.
///
/// **Sur le web, `web/index.html` lit cette même clé, plus tôt encore** : le
/// fond de la page et la couleur du bandeau de la barre d'état sont posés
/// avant que Flutter démarre, et « avant `runApp` » est déjà trop tard pour
/// eux. Le stockage de gotrue n'emprunte pas `shared_preferences` sur le web :
/// il écrit dans `localStorage` sous la clé telle quelle, sans préfixe ni
/// encodage — ce qui est précisément ce qui rend cette lecture possible.
class ThemeStorage {
  ThemeStorage({LocalStorage? stockage})
    : _stockage =
          stockage ?? SharedPreferencesLocalStorage(persistSessionKey: cle);

  /// La clé de stockage, partagée avec `web/index.html`.
  static const String cle = 'jelvo-apparence';

  final LocalStorage _stockage;

  ThemeMode _mode = ThemeMode.system;

  /// L'apparence retenue. **`system` par défaut** : tant que personne n'a
  /// choisi, suivre le téléphone est le comportement le moins surprenant.
  ThemeMode get mode => _mode;

  Future<void> initialize() async {
    await _stockage.initialize();
    _mode = _depuisJeton(await _stockage.accessToken());
  }

  Future<void> enregistrer(ThemeMode mode) async {
    _mode = mode;
    await _stockage.persistSession(jeton(mode));
  }

  /// Un mot, pas un index : un `ThemeMode.values[i]` se décalerait le jour où
  /// Flutter ajouterait une valeur, et l'appareil se réveillerait dans une
  /// apparence qu'il n'a jamais choisie.
  ///
  /// **Ces trois mots sont un contrat partagé avec `web/index.html`**, qui lit
  /// la même clé de `localStorage` pour poser le fond et le bandeau avant que
  /// Flutter démarre. En renommer un ici sans l'y renommer ferait retomber le
  /// démarrage sur « suivre le téléphone », donc réapparaître le clignotement
  /// — un défaut muet. `test/launch_screen_test.dart` confronte les deux.
  static String jeton(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'clair',
    ThemeMode.dark => 'sombre',
    ThemeMode.system => 'systeme',
  };

  static ThemeMode _depuisJeton(String? jeton) => switch (jeton) {
    'clair' => ThemeMode.light,
    'sombre' => ThemeMode.dark,
    // Une valeur absente ou inconnue retombe sur le téléphone plutôt que de
    // lever : un stockage corrompu ne doit pas empêcher l'application de
    // s'ouvrir.
    _ => ThemeMode.system,
  };
}

/// Stockage qui ne retient rien, pour les tests et les harnais où `main()`
/// n'a pas tourné.
class EphemeralThemeStorage extends ThemeStorage {
  EphemeralThemeStorage({ThemeMode mode = ThemeMode.system})
    : super(stockage: const EphemeralSessionStorage()) {
    _mode = mode;
  }
}
