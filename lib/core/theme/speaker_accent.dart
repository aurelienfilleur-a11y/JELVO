import 'package:flutter/material.dart';

import 'jelvo_colors.dart';

/// Couleur d'identité d'une personne qui parle dans une conversation.
///
/// **Même mécanisme que `GroupAccent`** — une somme de contrôle stable de
/// l'identifiant, sans colonne en base ni tirage aléatoire : deux appareils
/// donnent la même couleur à la même personne, et elle ne change pas d'un
/// lancement à l'autre. Elle ne change pas non plus d'un thème à l'autre :
/// c'est le **rang** qui est stable, pas la valeur, et la teinte du rang 3
/// reste « le vert » des deux côtés.
///
/// **La palette n'est pas celle des groupes.** Celle-là sert des aplats et des
/// vignettes ; ici il s'agit de texte de 13, et trois des six teintes de
/// groupe n'y sont pas lisibles — `warning` tombe à 1,9:1, `success` à 3,1:1,
/// `danger` à 3,7:1, là où un texte courant demande 4,5:1.
///
/// Les huit teintes vivent dans `JelvoColors.speakerAccents` : assombries sur
/// fond clair (5,48 à 9,51:1), éclaircies sur fond sombre (6,19 à 10,10:1).
enum SpeakerAccent {
  violet,
  indigo,
  vert,
  ambre,
  rouge,
  cyan,
  rose,
  brun;

  static SpeakerAccent forId(String id) =>
      SpeakerAccent.values[_stableHash(id) % SpeakerAccent.values.length];

  Color color(JelvoColors couleurs) => couleurs.speakerAccents[index];

  /// La couleur d'une personne, directement.
  static Color colorFor(String id, JelvoColors couleurs) =>
      forId(id).color(couleurs);
}

/// Somme de contrôle stable d'une chaîne.
///
/// `String.hashCode` varie d'une exécution à l'autre en Dart : il ne peut pas
/// servir à choisir une couleur qui doit rester la même entre deux lancements.
/// Volontairement identique à celle de `GroupAccent` — deux implémentations
/// auraient fini par diverger.
int _stableHash(String value) {
  int hash = 0;
  for (final int unit in value.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hash;
}
