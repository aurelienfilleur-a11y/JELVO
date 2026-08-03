import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/creation_kind.dart';

/// Type d'élément sélectionné dans l'écran de création.
///
/// L'état est conservé dans un provider plutôt que dans le `State` de l'écran :
/// l'écran étant empilé puis dépilé, cela permettra plus tard de restaurer un
/// brouillon abandonné.
final NotifierProvider<SelectedCreationKind, CreationKind>
selectedCreationKindProvider =
    NotifierProvider<SelectedCreationKind, CreationKind>(
      SelectedCreationKind.new,
    );

class SelectedCreationKind extends Notifier<CreationKind> {
  @override
  CreationKind build() => CreationKind.event;

  void select(CreationKind kind) => state = kind;
}
