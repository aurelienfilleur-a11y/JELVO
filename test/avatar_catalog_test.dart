import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jelvo/core/core.dart';
import 'package:jelvo/features/profile/models/avatar_catalog.dart';

/// Garde-fou du catalogue, sans widget.
///
/// La liste Dart est **générée** par `tool/lister_avatars.py`. Rien ne
/// garantit qu'on pense à la régénérer après avoir ajouté ou retiré un
/// fichier : ce test le garantit à sa place, en confrontant la liste au
/// contenu réel du dossier.
void main() {
  group('Catalogue des avatars', () {
    test('la liste correspond exactement aux fichiers embarqués', () {
      final List<String> surDisque =
          Directory('assets/avatars')
              .listSync()
              .whereType<File>()
              .map((File f) => f.uri.pathSegments.last)
              .where((String n) => n.endsWith('.png'))
              .map((String n) => n.substring(0, n.length - 4))
              .toList()
            ..sort();

      expect(
        avatarsPredefinis,
        surDisque,
        reason:
            'Le catalogue a divergé du dossier. Relancez '
            'python3 tool/lister_avatars.py',
      );
    });

    test('la numérotation comporte les trous connus', () {
      // 93 fichiers, pas 96 : rien ne doit reconstruire un identifiant à
      // partir d'un intervalle.
      expect(avatarsPredefinis, hasLength(93));
      for (final String absent in <String>['p1_10', 'p2_08', 'p2_12']) {
        expect(avatarsPredefinis, isNot(contains(absent)));
      }
    });

    test('chaque identifiant a bien son fichier', () {
      for (final String id in avatarsPredefinis) {
        expect(
          File(cheminAvatar(id)).existsSync(),
          isTrue,
          reason: 'fichier manquant pour $id',
        );
      }
    });
  });

  group('Résolution d’une valeur d’avatar', () {
    test('un préfixe « preset: » désigne un asset', () {
      expect(
        AvatarData.assetPourAvatar('preset:p2_07'),
        'assets/avatars/p2_07.png',
      );
    });

    test('une URL reste une URL', () {
      expect(
        AvatarData.assetPourAvatar('https://exemple.test/photo.jpg'),
        isNull,
      );
      expect(AvatarData.assetPourAvatar(null), isNull);
    });

    test('un préfixe nu ne produit pas un chemin bancal', () {
      // Sans cette garde, « preset: » donnerait « assets/avatars/.png ».
      expect(AvatarData.assetPourAvatar('preset:'), isNull);
    });

    test('un identifiant inconnu donne un chemin, pas une exception', () {
      // Le noyau ne connaît pas le catalogue : c'est le rendu qui retombe
      // sur les initiales quand le fichier n'existe pas.
      expect(
        AvatarData.assetPourAvatar('preset:inexistant'),
        'assets/avatars/inexistant.png',
      );
      expect(idAvatarPredefini('preset:inexistant'), isNull);
    });

    test('idAvatarPredefini ne retient que les identifiants du catalogue', () {
      expect(
        idAvatarPredefini('preset:${avatarsPredefinis.first}'),
        avatarsPredefinis.first,
      );
      expect(idAvatarPredefini('https://exemple.test/p.png'), isNull);
    });
  });
}
