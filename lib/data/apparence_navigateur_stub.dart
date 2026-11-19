/// Talon des plateformes sans navigateur : machine virtuelle des tests, et
/// cibles Android et iOS natives.
///
/// Il ne feint rien et n'a rien à feindre. La couleur de la barre d'état y est
/// posée par `SystemUiOverlayStyle`, depuis `AppTheme`, et le lancement par le
/// `launch_screen` natif — ni l'un ni l'autre ne passe par une page web.
void appliquerApparenceDuNavigateur(String mot) {}
