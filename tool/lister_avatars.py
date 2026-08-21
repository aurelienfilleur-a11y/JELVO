#!/usr/bin/env python3
"""Régénère le catalogue Dart des avatars prédéfinis.

    python3 tool/lister_avatars.py

À relancer après tout ajout ou retrait de fichier dans `assets/avatars/`.
`test/avatar_catalog_test.dart` confronte la liste au contenu réel du
dossier : oublier de relancer fait échouer les tests, pas apparaître une
case vide dans la galerie.
"""

import glob
import os

DOSSIER = 'assets/avatars'
CIBLE = 'lib/features/profile/models/avatar_catalog.dart'

EN_TETE = """/// Catalogue des avatars prédéfinis embarqués dans l'application.
///
/// **Cette liste est générée** par `tool/lister_avatars.py`, et
/// `test/avatar_catalog_test.dart` la confronte au contenu réel de
/// `assets/avatars/`. Un fichier ajouté ou retiré sans régénérer la liste
/// fait donc échouer les tests plutôt que de produire une case vide dans la
/// galerie.
///
/// **La numérotation comporte des trous** — `p1_10`, `p2_08` et `p2_12`
/// n'existent pas. Rien ne doit donc reconstruire un identifiant à partir
/// d'un intervalle : {n} fichiers, pas 96.
library;

/// Identifiants des avatars, dans l'ordre d'affichage de la galerie.
const List<String> avatarsPredefinis = <String>[
{corps}
];

/// Chemin d'asset d'un avatar prédéfini.
String cheminAvatar(String id) => '{dossier}/$id.png';

/// Préfixe qui distingue un avatar prédéfini d'une photo téléversée dans la
/// valeur d'avatar renvoyée par les fonctions SQL de lecture.
///
/// Les fonctions renvoient `coalesce('preset:' || avatar_preset, avatar_url)`
/// dans le champ `avatar_url` qu'elles exposaient déjà : **aucune signature
/// n'a changé**, et tous les écrans continuent de lire un seul champ.
const String prefixeAvatarPredefini = 'preset:';

/// Extrait l'identifiant d'une valeur d'avatar, ou `null` si c'en est une
/// photo — ou rien du tout.
String? idAvatarPredefini(String? valeur) {{
  if (valeur == null || !valeur.startsWith(prefixeAvatarPredefini)) return null;
  final String id = valeur.substring(prefixeAvatarPredefini.length);
  return avatarsPredefinis.contains(id) ? id : null;
}}
"""


def main() -> None:
    ids = sorted(
        os.path.basename(f)[:-4] for f in glob.glob(f'{DOSSIER}/*.png')
    )
    if not ids:
        raise SystemExit(f'Aucun PNG dans {DOSSIER} : rien à générer.')

    lignes = [
        '  ' + ' '.join(f"'{x}'," for x in ids[i:i + 6])
        for i in range(0, len(ids), 6)
    ]
    open(CIBLE, 'w').write(
        EN_TETE.format(n=len(ids), corps='\n'.join(lignes), dossier=DOSSIER)
    )
    print(f'{CIBLE} : {len(ids)} identifiants')


if __name__ == '__main__':
    main()
