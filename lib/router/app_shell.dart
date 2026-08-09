import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/core.dart';
import '../features/groups/widgets/group_creation_sheet.dart';
import '../features/notifications/providers/notification_providers.dart';
import 'app_bottom_nav.dart';
import 'app_routes.dart';

/// Coque de l'application : contenu de l'onglet actif + barre inférieure.
///
/// Adossée à un `StatefulShellRoute.indexedStack`, chaque onglet conserve son
/// propre historique et sa position de défilement lors des changements
/// d'onglet.
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.location,
  });

  final StatefulNavigationShell navigationShell;

  /// Chemin réellement affiché, `/groupes/<id>` compris.
  ///
  /// L'index de l'onglet ne suffit pas : une branche peut empiler plusieurs
  /// écrans sans en changer.
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _CreateAction action = _createAction(
      location,
      navigationShell.currentIndex,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: navigationShell,
      bottomNavigationBar: AppBottomNav(
        currentIndex: navigationShell.currentIndex,
        badges: ref.watch(unreadByTabProvider),
        onDestinationSelected: (int index) => navigationShell.goBranch(
          index,
          // Re-toucher l'onglet actif ramène à sa racine, comportement attendu
          // sur iOS comme sur Android.
          initialLocation: index == navigationShell.currentIndex,
        ),
        createLabel: action.label,
        onCreatePressed: () => action.open(context),
      ),
    );
  }

  /// Ce que crée le bouton central, selon l'écran affiché.
  ///
  /// Le « + » n'est pas un onglet mais une action : la faire dépendre du
  /// contexte évite de demander à chaque fois ce que l'on veut créer, alors que
  /// l'écran ouvert le dit déjà.
  ///
  /// La route prime sur l'onglet, et c'est tout l'objet de [location] : depuis
  /// l'écran d'un groupe on reste dans l'onglet « Groupes », mais proposer d'y
  /// créer un groupe de plus n'a aucun sens. Ce que l'on veut y ajouter, c'est
  /// un événement ou une tâche — d'où la feuille de choix.
  static _CreateAction _createAction(String location, int index) {
    final String? groupId = AppRoutes.groupIdIn(location);
    if (groupId != null) {
      return _CreateAction(
        label: 'Ajouter au groupe',
        open: (BuildContext context) =>
            ouvrirFeuilleDeCreation(context, groupId: groupId),
      );
    }

    return switch (index) {
      // Accueil et Groupes mènent tous deux à la création de groupe : c'est
      // l'objet principal de l'application.
      0 || 1 => _CreateAction(
        label: 'Nouveau groupe',
        open: (BuildContext context) =>
            context.pushNamed(AppRoutes.groupCreate),
      ),
      2 => _CreateAction(
        label: 'Nouvel événement',
        open: (BuildContext context) => context.pushNamed(AppRoutes.create),
      ),
      _ => _CreateAction(
        label: 'Ajouter un contact',
        open: (BuildContext context) => context.pushNamed(AppRoutes.addContact),
      ),
    };
  }
}

/// Action du bouton central : ce qu'elle ouvre, et le libellé qui l'annonce
/// en infobulle comme aux lecteurs d'écran.
class _CreateAction {
  const _CreateAction({required this.label, required this.open});

  final String label;
  final void Function(BuildContext context) open;
}
