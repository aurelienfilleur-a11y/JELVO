import 'pont_navigateur.dart';

/// Talon des plateformes sans page web : machine virtuelle des tests, et
/// cibles Android et iOS natives.
///
/// Il ne feint rien et n'a rien à feindre. La couleur de la barre d'état y est
/// posée par `SystemUiOverlayStyle`, depuis `AppTheme`, et l'écran de
/// lancement par la plateforme — ni l'un ni l'autre ne passe par une page.
class PontNavigateurTalon implements PontNavigateur {
  const PontNavigateurTalon();

  @override
  void appliquerApparence(String mot) {}

  @override
  void applicationPrete() {}
}

PontNavigateur creerPont() => const PontNavigateurTalon();
