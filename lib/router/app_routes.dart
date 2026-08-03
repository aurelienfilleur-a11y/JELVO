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
}
