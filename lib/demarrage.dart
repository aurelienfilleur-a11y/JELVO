import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/data_providers.dart';
import 'features/auth/providers/auth_providers.dart';
import 'features/calendar/providers/calendar_providers.dart';
import 'features/groups/providers/group_providers.dart';
import 'features/profile/providers/profile_providers.dart';
import 'features/tasks/providers/task_providers.dart';

/// Quand l'application est **prête à être vue**.
///
/// Ce n'est pas la même chose que « la première image est peinte », et c'est
/// toute la raison de ce fichier. La destination, elle, est connue avant le
/// premier `build` : la redirection de GoRouter est synchrone, et aucune route
/// par défaut n'est construite en attendant. Ce qui manque à la première
/// image, ce n'est pas la route — c'est le **contenu**.
///
/// Or `ref.watch(x).value ?? const []` rend une liste vide pendant le
/// chargement, si bien qu'un écran en cours de lecture est indiscernable d'un
/// écran vide : l'accueil s'affiche avec « Aucun groupe pour le moment » et
/// « Journée libre », puis se remplit. C'est l'écran de passage qu'on voyait,
/// et il ne ressemblait pas à l'accueil — il ressemblait à un compte neuf.
///
/// **Une erreur vaut un contenu.** Ce qu'on attend, c'est que la lecture ait
/// répondu, pas qu'elle ait réussi : retenir l'écran de lancement jusqu'au
/// succès laisserait quelqu'un hors ligne devant un logo, sans jamais rien
/// lui dire.
final Provider<bool> applicationPreteProvider = Provider<bool>((Ref ref) {
  // Sans session, le premier écran est la bienvenue ou la connexion : ils ne
  // lisent rien, ils sont prêts tout de suite.
  if (ref.watch(authStatusProvider) == AuthStatus.signedOut) return true;

  // Les quatre lectures dont l'accueil tire ce qu'il montre. La liste est
  // explicite plutôt que devinée : y ajouter un provider, c'est retenir
  // l'écran de lancement plus longtemps, et cela doit être un choix.
  final List<AsyncValue<Object?>> lectures = <AsyncValue<Object?>>[
    ref.watch(currentProfileProvider),
    ref.watch(myGroupsProvider),
    ref.watch(eventsProvider),
    ref.watch(tasksProvider),
  ];
  return lectures.every((AsyncValue<Object?> v) => v.hasValue || v.hasError);
});

/// Dit à la page de retirer l'écran de lancement, une fois seulement.
///
/// **Il ne construit rien** : il laisse passer son enfant tel quel, et c'est
/// ce qui l'isole. Observer l'état de préparation depuis `JelvoApp`
/// reconstruirait `MaterialApp.router` à chaque lecture qui se termine ;
/// ici l'enfant est la *même* instance d'un appel à l'autre, et Flutter ne le
/// reconstruit donc pas.
class SignalDeDemarrage extends ConsumerWidget {
  const SignalDeDemarrage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Appelé depuis `build` plutôt que par `ref.listen` parce que l'état peut
    // être **déjà** vrai au premier passage — sans session, il l'est toujours
    // — et qu'un écouteur ne se déclenche qu'au changement. La page encaisse
    // les appels répétés : elle ne retire son voile qu'une fois.
    if (ref.watch(applicationPreteProvider)) {
      ref.read(pontNavigateurProvider).applicationPrete();
    }
    return child;
  }
}
