import 'package:flutter/material.dart';

/// Couleur d'identité d'une personne qui parle dans une conversation.
///
/// **Même mécanisme que `GroupAccent`** — une somme de contrôle stable de
/// l'identifiant, sans colonne en base ni tirage aléatoire : deux appareils
/// donnent la même couleur à la même personne, et elle ne change pas d'un
/// lancement à l'autre.
///
/// **La palette, en revanche, n'est pas celle des groupes.** Celle-ci sert des
/// aplats et des vignettes ; ici il s'agit de texte de 13 px sur fond clair, et
/// trois de ses six teintes n'y sont pas lisibles — `warning` tombe à 1,9:1,
/// `success` à 3,1:1, `danger` à 3,7:1, là où un texte courant demande 4,5:1.
///
/// Les huit teintes ci-dessous sont les mêmes familles, assombries jusqu'à
/// passer ce seuil sur le fond `#F7F7FB` de l'application. Le rapport mesuré
/// est en commentaire de chaque valeur : il se recalcule si l'on y touche.
enum SpeakerAccent {
  violet(Color(0xFF5B2EFF)), // 5,99:1 — c'est `AppColors.primary` inchangé
  indigo(Color(0xFF3D1DB8)), // 9,51:1 — `AppColors.primaryDark` inchangé
  vert(Color(0xFF15734B)), //   5,48:1
  ambre(Color(0xFF8A5A00)), //  5,55:1
  rouge(Color(0xFFB3282C)), //  6,03:1
  cyan(Color(0xFF0F6E7A)), //   5,56:1
  rose(Color(0xFFA62A6E)), //   6,18:1
  brun(Color(0xFF6B4423)); //   7,94:1

  const SpeakerAccent(this.color);

  final Color color;

  static SpeakerAccent forId(String id) =>
      SpeakerAccent.values[_stableHash(id) % SpeakerAccent.values.length];

  /// La couleur d'une personne, directement.
  static Color colorFor(String id) => forId(id).color;
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
