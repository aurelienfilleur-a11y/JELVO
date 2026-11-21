import 'dart:ui';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'session_persistence.dart';

/// Se souvient de la langue choisie, ou de l'absence de choix.
///
/// **Ce réglage vit sur l'appareil, pas sur le compte** — exactement comme
/// l'apparence, et pour la même raison : un même compte peut être ouvert sur
/// un téléphone acheté en Espagne et sur l'ordinateur d'un bureau français.
/// Un réglage de compte imposerait la même langue aux deux. La brique est
/// celle de `ThemeStorage` et de « Se souvenir de moi » : un `LocalStorage` de
/// gotrue détourné, sous la clé `jelvo-langue`.
///
/// Il est lu dans `main()` **avant `runApp`**. Un démarrage qui s'ouvrirait en
/// français pour basculer en espagnol à la première image serait le même
/// clignotement que celui du thème, et il ne se rattrape pas après coup.
///
/// **Contrairement à `ThemeStorage`, `web/index.html` n'a rien à lire ici.**
/// Le fond de la page et le bandeau de la barre d'état sont décidés avant que
/// Flutter démarre ; la langue, elle, ne se voit qu'une fois qu'il y a du
/// texte à l'écran — c'est-à-dire après. Il n'y a donc **aucun contrat
/// recopié** de ce côté, et rien à tenir d'accord.
class LanguageStorage {
  LanguageStorage({LocalStorage? stockage})
    : _stockage =
          stockage ?? SharedPreferencesLocalStorage(persistSessionKey: cle);

  static const String cle = 'jelvo-langue';

  /// Les quatre langues, **dans l'ordre où les paramètres les proposent** :
  /// le français d'abord parce que c'est la langue de référence du projet,
  /// puis l'ordre alphabétique de leur nom dans leur propre langue.
  static const List<Locale> languesPrisesEnCharge = <Locale>[
    Locale('fr'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
  ];

  /// La langue servie quand celle du téléphone n'est pas des quatre.
  ///
  /// **L'anglais, et non le français**, bien que le français soit la langue de
  /// référence : quelqu'un dont le téléphone est en japonais a plus de chances
  /// de lire l'anglais. C'est la consigne produit, et c'est aussi le défaut
  /// qu'on attend d'une application.
  static const Locale langueParDefaut = Locale('en');

  final LocalStorage _stockage;

  Locale? _choix;

  /// La langue choisie, ou `null` pour « celle du téléphone ».
  ///
  /// **`null` par défaut** : tant que personne n'a choisi, suivre le téléphone
  /// est le comportement le moins surprenant — même règle que `ThemeMode.system`.
  Locale? get choix => _choix;

  Future<void> initialize() async {
    await _stockage.initialize();
    _choix = depuisJeton(await _stockage.accessToken());
  }

  Future<void> enregistrer(Locale? langue) async {
    _choix = langue;
    await _stockage.persistSession(jeton(langue));
  }

  /// Un **code de langue**, pas un index : un rang se décalerait le jour où
  /// une cinquième langue s'ajouterait, et l'appareil se réveillerait dans une
  /// langue qu'il n'a jamais choisie. C'est la leçon des trois mots
  /// d'apparence, appliquée avant d'en avoir payé le prix.
  static String jeton(Locale? langue) => langue?.languageCode ?? 'systeme';

  static Locale? depuisJeton(String? jeton) {
    if (jeton == null) return null;
    for (final Locale langue in languesPrisesEnCharge) {
      if (langue.languageCode == jeton) return langue;
    }
    // `systeme`, une valeur absente, ou un stockage abîmé : on suit le
    // téléphone plutôt que de lever. Une langue inconnue ne doit pas empêcher
    // l'application de s'ouvrir.
    return null;
  }

  /// La langue à servir, parmi les quatre, pour une liste de langues
  /// préférées — celle que le système annonce.
  ///
  /// **La correspondance se fait sur le code de langue seul.** Un téléphone
  /// réglé en `es_MX` doit obtenir l'espagnol : exiger la région reviendrait à
  /// servir l'anglais à tout le Mexique pour une variante que Jelvo ne
  /// distingue pas.
  static Locale resoudre(List<Locale>? preferees) {
    for (final Locale preferee in preferees ?? const <Locale>[]) {
      for (final Locale connue in languesPrisesEnCharge) {
        if (preferee.languageCode == connue.languageCode) return connue;
      }
    }
    return langueParDefaut;
  }
}

/// Stockage qui ne retient rien, pour les tests et les harnais où `main()`
/// n'a pas tourné.
class EphemeralLanguageStorage extends LanguageStorage {
  EphemeralLanguageStorage({Locale? langue})
    : super(stockage: const EphemeralSessionStorage()) {
    _choix = langue;
  }
}
