/// Catalogue des avatars prédéfinis embarqués dans l'application.
///
/// **Cette liste est générée** par `tool/lister_avatars.py`, et
/// `test/avatar_catalog_test.dart` la confronte au contenu réel de
/// `assets/avatars/`. Un fichier ajouté ou retiré sans régénérer la liste
/// fait donc échouer les tests plutôt que de produire une case vide dans la
/// galerie.
///
/// **La numérotation comporte des trous** — `p1_10`, `p2_08` et `p2_12`
/// n'existent pas. Rien ne doit donc reconstruire un identifiant à partir
/// d'un intervalle : 93 fichiers, pas 96.
library;

/// Identifiants des avatars, dans l'ordre d'affichage de la galerie.
const List<String> avatarsPredefinis = <String>[
  'p1_01',
  'p1_02',
  'p1_03',
  'p1_04',
  'p1_05',
  'p1_06',
  'p1_07',
  'p1_08',
  'p1_09',
  'p1_11',
  'p1_12',
  'p1_13',
  'p1_14',
  'p1_15',
  'p1_16',
  'p1_17',
  'p1_18',
  'p1_19',
  'p1_20',
  'p1_21',
  'p1_22',
  'p1_23',
  'p1_24',
  'p2_01',
  'p2_02',
  'p2_03',
  'p2_04',
  'p2_05',
  'p2_06',
  'p2_07',
  'p2_09',
  'p2_10',
  'p2_11',
  'p2_13',
  'p2_14',
  'p2_15',
  'p2_16',
  'p2_17',
  'p2_18',
  'p2_19',
  'p2_20',
  'p2_21',
  'p2_22',
  'p2_23',
  'p2_24',
  'p3_01',
  'p3_02',
  'p3_03',
  'p3_04',
  'p3_05',
  'p3_06',
  'p3_07',
  'p3_08',
  'p3_09',
  'p3_10',
  'p3_11',
  'p3_12',
  'p3_13',
  'p3_14',
  'p3_15',
  'p3_16',
  'p3_17',
  'p3_18',
  'p3_19',
  'p3_20',
  'p3_21',
  'p3_22',
  'p3_23',
  'p3_24',
  'p4_01',
  'p4_02',
  'p4_03',
  'p4_04',
  'p4_05',
  'p4_06',
  'p4_07',
  'p4_08',
  'p4_09',
  'p4_10',
  'p4_11',
  'p4_12',
  'p4_13',
  'p4_14',
  'p4_15',
  'p4_16',
  'p4_17',
  'p4_18',
  'p4_19',
  'p4_20',
  'p4_21',
  'p4_22',
  'p4_23',
  'p4_24',
];

/// Chemin d'asset d'un avatar prédéfini.
String cheminAvatar(String id) => 'assets/avatars/$id.png';

/// Préfixe qui distingue un avatar prédéfini d'une photo téléversée dans la
/// valeur d'avatar renvoyée par les fonctions SQL de lecture.
///
/// Les fonctions renvoient `coalesce('preset:' || avatar_preset, avatar_url)`
/// dans le champ `avatar_url` qu'elles exposaient déjà : **aucune signature
/// n'a changé**, et tous les écrans continuent de lire un seul champ.
const String prefixeAvatarPredefini = 'preset:';

/// Extrait l'identifiant d'une valeur d'avatar, ou `null` si c'en est une
/// photo — ou rien du tout.
String? idAvatarPredefini(String? valeur) {
  if (valeur == null || !valeur.startsWith(prefixeAvatarPredefini)) return null;
  final String id = valeur.substring(prefixeAvatarPredefini.length);
  return avatarsPredefinis.contains(id) ? id : null;
}
