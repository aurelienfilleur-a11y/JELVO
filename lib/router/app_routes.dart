/// Chemins et noms de routes de l'application.
///
/// Les écrans naviguent avec `context.goNamed(AppRoutes.groups)` plutôt qu'avec
/// des chaînes littérales, ce qui rend un renommage de chemin sans risque.
abstract final class AppRoutes {
  // Onglets de la barre inférieure.
  static const String home = 'home';
  static const String homePath = '/';

  static const String groups = 'groups';
  static const String groupsPath = '/groupes';

  static const String calendar = 'calendar';
  static const String calendarPath = '/calendrier';

  static const String contacts = 'contacts';
  static const String contactsPath = '/contacts';

  /// Écran de création, ouvert par le bouton central « + ».
  /// Empilé au-dessus du shell, il masque donc la barre de navigation.
  static const String create = 'create';
  static const String createPath = '/creer';

  // Profil et réglages, empilés sur le navigateur racine.
  static const String profile = 'profile';
  static const String profilePath = '/profil';

  static const String settings = 'settings';
  static const String settingsPath = '/parametres';

  // Parcours d'authentification, hors du shell : la barre de navigation ne
  // doit pas apparaître tant que l'utilisateur n'est pas connecté.
  static const String login = 'login';
  static const String loginPath = '/connexion';

  static const String signUp = 'signUp';
  static const String signUpPath = '/inscription';

  static const String signUpIdentity = 'signUpIdentity';
  static const String signUpIdentityPath = '/inscription/profil';

  static const String verifyEmail = 'verifyEmail';
  static const String verifyEmailPath = '/inscription/verification';

  static const String forgotPassword = 'forgotPassword';
  static const String forgotPasswordPath = '/mot-de-passe-oublie';

  static const String resetPassword = 'resetPassword';
  static const String resetPasswordPath = '/mot-de-passe-oublie/nouveau';

  /// Routes accessibles sans session.
  static const Set<String> publicPaths = <String>{
    loginPath,
    signUpPath,
    signUpIdentityPath,
    verifyEmailPath,
    forgotPasswordPath,
    resetPasswordPath,
  };
}
