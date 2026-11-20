import 'package:jelvo/data/pont_navigateur.dart';

/// Pont de test : il retient ce qu'on lui dit, au lieu de parler à une page.
///
/// C'est la raison d'être de l'interface. Sur la machine virtuelle, le vrai
/// pont est un talon muet : sans ce faux, rien ne distinguerait « le crochet
/// s'est déclenché » de « le crochet n'existe plus », et un crochet muet ne
/// se constate qu'à l'usage, sur l'appareil de quelqu'un.
class FakePontNavigateur implements PontNavigateur {
  final List<String> apparences = <String>[];
  int pretsAnnonces = 0;

  bool get aAnnonceLaPreparation => pretsAnnonces > 0;

  @override
  void appliquerApparence(String mot) => apparences.add(mot);

  @override
  void applicationPrete() => pretsAnnonces += 1;
}
