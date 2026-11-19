import 'package:flutter/material.dart' show ThemeMode;

import 'apparence_navigateur_stub.dart'
    if (dart.library.js_interop) 'apparence_navigateur_web.dart';
import 'theme_storage.dart';

/// Tient la page web d'accord avec l'apparence choisie.
///
/// **Ce que la page décide, et que Flutter ne peut pas décider** : la couleur
/// du bandeau de la barre d'état et le fond posé avant le démarrage. Les deux
/// sont lus par le navigateur *avant* qu'une ligne de Dart ne tourne —
/// `web/index.html` les règle donc lui-même, depuis le réglage enregistré sur
/// l'appareil. Sans cela, l'application s'ouvrirait sur un écran blanc pour
/// basculer en sombre à la première image.
///
/// Reste ce que la page ne peut pas savoir : qu'on vient de changer de
/// réglage. C'est le seul objet de cette fonction, appelée depuis `JelvoApp`.
///
/// **La règle n'est pas réimplémentée ici.** La page expose
/// `jelvoAppliquerApparence(mot)` et l'on ne fait que lui passer le mot : une
/// seconde implémentation en Dart aurait fini par diverger de la première, et
/// la divergence se serait vue — en clignotement, sur l'écran de quelqu'un.
///
/// Hors du web, c'est un talon : il n'y a ni page ni barre d'état de
/// navigateur à régler, et `ThemeMode` suffit.
void appliquerApparenceAuNavigateur(ThemeMode mode) =>
    appliquerApparenceDuNavigateur(ThemeStorage.jeton(mode));
