import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/core.dart';
import '../features/notifications/providers/notification_providers.dart';
import 'app_bottom_nav.dart';
import 'app_routes.dart';

/// Coque de l'application : contenu de l'onglet actif + barre inférieure.
///
/// Adossée à un `StatefulShellRoute.indexedStack`, chaque onglet conserve son
/// propre historique et sa position de défilement lors des changements
/// d'onglet.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        createLabel: _createAction(navigationShell.currentIndex).label,
        onCreatePressed: () => context.pushNamed(
          _createAction(navigationShell.currentIndex).routeName,
        ),
      ),
    );
  }

  /// Ce que crée le bouton central, selon l'onglet ouvert.
  ///
  /// Le « + » n'est pas un onglet mais une action : la faire dépendre du
  /// contexte évite de demander à chaque fois ce que l'on veut créer, alors que
  /// l'écran ouvert le dit déjà.
  static _CreateAction _createAction(int index) => switch (index) {
    // Accueil et Groupes mènent tous deux à la création de groupe : c'est
    // l'objet principal de l'application.
    0 || 1 => const _CreateAction(AppRoutes.groupCreate, 'Nouveau groupe'),
    2 => const _CreateAction(AppRoutes.create, 'Nouvel événement'),
    _ => const _CreateAction(AppRoutes.addContact, 'Ajouter un contact'),
  };
}

/// Destination du bouton central et libellé lu par les lecteurs d'écran.
class _CreateAction {
  const _CreateAction(this.routeName, this.label);

  final String routeName;
  final String label;
}
