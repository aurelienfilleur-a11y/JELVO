/// Ce que la suppression d'un compte a produit.
///
/// Trois issues, et pas un booléen : l'écran doit distinguer un mot de passe
/// refusé — qui se corrige en retapant — d'un échec serveur, qui ne se corrige
/// pas en insistant. Un booléen aurait forcé à les confondre, ou à inventer un
/// second canal pour la nuance.
///
/// **Un modèle ne choisit pas ses mots** : il dit ce que la chose est, l'écran
/// en tire la phrase, dans la langue de l'appareil.
enum ResultatSuppression {
  /// Le compte est supprimé et la session fermée.
  supprime,

  /// Le mot de passe donné n'est pas celui du compte. Rien n'a été touché.
  motDePasseIncorrect,

  /// La base a refusé, ou le retrait des fichiers n'a pas abouti. Le compte
  /// est intact : la personne peut réessayer.
  echec,
}
