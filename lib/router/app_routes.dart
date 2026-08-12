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

  /// Détail d'un groupe, dans l'onglet Groupes : la barre reste visible.
  static const String groupDetail = 'groupDetail';
  static const String groupDetailPath = '/groupes/:id';

  /// Conversation du groupe. Empilée sur le navigateur racine : le clavier et
  /// la barre de saisie ont besoin de toute la hauteur, et la barre de
  /// navigation n'a rien à faire au-dessus d'un fil de discussion.
  static const String groupChat = 'groupChat';
  static const String groupChatPath = '/groupes/:id/discussion';

  /// Création et modification, empilées sur le navigateur racine.
  static const String groupCreate = 'groupCreate';
  static const String groupCreatePath = '/groupes/nouveau';

  static const String groupEdit = 'groupEdit';
  static const String groupEditPath = '/groupes/:id/modifier';

  /// Invitations nominatives reçues.
  static const String invitations = 'invitations';
  static const String invitationsPath = '/invitations';

  static const String invitation = 'invitation';
  static const String invitationPath = '/invitations/:id';

  /// Page publique d'un lien de partage : accessible sans session.
  static const String joinGroup = 'joinGroup';
  static const String joinGroupPath = '/rejoindre/:jeton';

  static String joinGroupLocation(String token) => '/rejoindre/$token';

  static const String calendar = 'calendar';
  static const String calendarPath = '/calendrier';

  /// Détail d'un événement, empilé sur le navigateur racine : il s'ouvre
  /// depuis l'accueil, le calendrier, un groupe ou une notification, donc
  /// depuis n'importe quel onglet.
  static const String eventDetail = 'eventDetail';
  static const String eventDetailPath = '/evenements/:id';

  /// Liste des tâches et détail d'une tâche. Les tâches n'ont pas d'onglet :
  /// elles vivent dans l'accueil et dans les groupes, et la liste complète
  /// s'ouvre depuis le récapitulatif de l'accueil.
  static const String tasks = 'tasks';
  static const String tasksPath = '/taches';

  static const String taskDetail = 'taskDetail';
  static const String taskDetailPath = '/taches/:id';

  static const String contacts = 'contacts';
  static const String contactsPath = '/contacts';

  /// Recherche par pseudo et ajout d'un contact.
  static const String addContact = 'addContact';
  static const String addContactPath = '/contacts/ajouter';

  /// Scanner de QR code.
  static const String scanContact = 'scanContact';
  static const String scanContactPath = '/contacts/scanner';

  /// QR code personnel, ouvert depuis le profil.
  static const String myQrCode = 'myQrCode';
  static const String myQrCodePath = '/profil/qr';

  /// Écran de création, ouvert par le bouton central « + ».
  /// Empilé au-dessus du shell, il masque donc la barre de navigation.
  static const String create = 'create';
  static const String createPath = '/creer';

  /// Paramètres d'URL de `/creer` : type pré-sélectionné (`event`, `task`,
  /// `group`) et groupe de rattachement.
  ///
  /// Ils passent par l'URL et non par `extra` pour que le lien reste
  /// rechargeable sur le web — un `extra` disparaît au rafraîchissement.
  static const String createKindParam = 'type';
  static const String createGroupParam = 'groupe';

  // Profil et réglages, empilés sur le navigateur racine.
  static const String profile = 'profile';
  static const String profilePath = '/profil';

  /// Saisie de ses disponibilités, ouverte depuis le profil.
  static const String availability = 'availability';
  static const String availabilityPath = '/disponibilites';

  static const String settings = 'settings';
  static const String settingsPath = '/parametres';

  /// Boîte de notifications, ouverte par la cloche de l'accueil.
  static const String notifications = 'notifications';
  static const String notificationsPath = '/notifications';

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

  /// Préfixes publics à chemin variable.
  ///
  /// `publicPaths` compare des chemins exacts ; un lien d'invitation porte un
  /// jeton, il lui faut donc une comparaison par préfixe.
  static const List<String> publicPrefixes = <String>['/rejoindre/'];

  /// Vrai si [location] est accessible sans session.
  static bool isPublic(String location) {
    if (publicPaths.contains(location)) return true;
    return publicPrefixes.any(location.startsWith);
  }

  /// Identifiant du groupe affiché par [location], ou `null` si l'écran
  /// courant n'est pas celui d'un groupe.
  ///
  /// Sert au bouton « + » de la barre, qui doit se régler sur l'écran
  /// réellement affiché et non sur l'onglet actif : depuis `/groupes/<id>`,
  /// l'onglet reste « Groupes » alors que l'action attendue a changé.
  static String? groupIdIn(String location) {
    const String prefixe = '$groupsPath/';
    if (!location.startsWith(prefixe)) return null;

    final String reste = location.substring(prefixe.length);
    final int barre = reste.indexOf('/');
    final String id = barre == -1 ? reste : reste.substring(0, barre);

    if (id.isEmpty) return null;
    // « /groupes/nouveau » est l'écran de création : ce n'est pas un groupe.
    return '$groupsPath/$id' == groupCreatePath ? null : id;
  }
}
