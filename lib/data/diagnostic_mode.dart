import 'package:flutter/foundation.dart';

import 'app_config.dart';

/// Mode diagnostic : accole l'erreur technique brute au message français et la
/// consigne dans la console.
///
/// **Activable à l'exécution, par l'URL** — c'est tout l'objet de cette classe.
/// Le drapeau de compilation `JELVO_DIAGNOSTIC` reste la valeur par défaut,
/// mais il imposait une nouvelle livraison pour voir une seule erreur serveur,
/// ce qui a coûté plusieurs jours. Le paramètre d'URL rend le diagnostic
/// accessible sans passer par le dépôt :
///
/// ```
/// https://…/JELVO/?diag=1#/
/// https://…/JELVO/#/groupes/<id>?diag=1
/// ```
///
/// Les deux formes fonctionnent. La première est à préférer : l'application
/// n'appelant pas `usePathUrlStrategy()`, GoRouter réécrit le fragment à chaque
/// navigation et emporterait un paramètre qui y serait collé — alors que ce qui
/// précède le `#` survit à toute la session, rechargement compris.
///
/// La lecture n'a lieu **qu'au démarrage**, dans `main()`. L'état est donc
/// stable pour toute la session, quelle que soit la navigation ensuite ; pour
/// en sortir, recharger la page sans le paramètre.
abstract final class DiagnosticMode {
  /// Nom du paramètre d'URL.
  static const String parametre = 'diag';

  static bool _actif = AppConfig.diagnosticErrors;

  /// Vrai si l'erreur technique doit être affichée.
  static bool get isActive => _actif;

  /// Lit le paramètre dans l'URL de démarrage.
  ///
  /// [url] n'est là que pour les tests : en production c'est `Uri.base`, qui
  /// porte l'adresse de la page sur le web et une URI de fichier ailleurs —
  /// sans paramètre, donc sans effet sur mobile.
  static void lireDepuisUrl([Uri? url]) {
    final bool? demande = _parametreDe(url ?? Uri.base);
    if (demande != null) _actif = demande;

    if (_actif) {
      debugPrint(
        '[jelvo:diagnostic] Mode diagnostic ACTIF : les erreurs techniques '
        'brutes sont affichées. Rechargez sans « ?$parametre=1 » pour le '
        'désactiver.',
      );
    }
  }

  /// Force l'état — réservé aux tests, qui doivent pouvoir le remettre à zéro.
  @visibleForTesting
  static void definirPourTest({required bool actif}) => _actif = actif;

  /// Valeur demandée par [url], ou `null` si le paramètre est absent.
  ///
  /// Distinguer « absent » de « faux » importe : un paramètre absent doit
  /// laisser la valeur de compilation en place, pas l'écraser.
  static bool? _parametreDe(Uri url) {
    if (url.queryParameters.containsKey(parametre)) {
      return _estVrai(url.queryParameters[parametre]);
    }

    // Sans stratégie par chemin, la route vit après le `#` : un paramètre collé
    // à la route s'y trouve donc aussi.
    final String fragment = url.fragment;
    if (fragment.isEmpty) return null;

    final Uri route = Uri.tryParse(fragment) ?? Uri();
    if (!route.queryParameters.containsKey(parametre)) return null;
    return _estVrai(route.queryParameters[parametre]);
  }

  /// `?diag` nu vaut « oui » : c'est ce que l'on tape le plus naturellement.
  static bool _estVrai(String? valeur) {
    final String v = (valeur ?? '').trim().toLowerCase();
    return v.isEmpty || v == '1' || v == 'true' || v == 'oui' || v == 'vrai';
  }
}
