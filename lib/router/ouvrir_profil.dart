import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'app_routes.dart';

/// Ouvrir le profil de quelqu'un, d'où qu'on vienne.
///
/// Cinq endroits y mènent — une conversation, les membres d'un groupe, les
/// convives d'un événement, les assignés d'une tâche, le carnet — et un
/// sixième s'ajoutera. L'appel vit donc ici plutôt que recopié cinq fois :
/// c'est la même raison qui fait passer la navigation par `goNamed` et jamais
/// par une chaîne littérale.
extension OuvrirProfil on BuildContext {
  /// Empile le profil de [userId] par-dessus l'écran courant.
  ///
  /// `push` et non `go` : on revient d'où l'on vient. Depuis une conversation,
  /// `go` remplacerait la pile et le retour ramènerait dans un onglet.
  void ouvrirProfilDe(String userId) {
    if (userId.isEmpty) return;
    pushNamed(
      AppRoutes.publicProfile,
      pathParameters: <String, String>{'id': userId},
    );
  }
}
