import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/core.dart';
import 'app_bottom_nav.dart';
import 'app_routes.dart';

/// Coque de l'application : contenu de l'onglet actif + barre inférieure.
///
/// Adossée à un `StatefulShellRoute.indexedStack`, chaque onglet conserve son
/// propre historique et sa position de défilement lors des changements
/// d'onglet.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: navigationShell,
      bottomNavigationBar: AppBottomNav(
        currentIndex: navigationShell.currentIndex,
        onDestinationSelected: (int index) => navigationShell.goBranch(
          index,
          // Re-toucher l'onglet actif ramène à sa racine, comportement attendu
          // sur iOS comme sur Android.
          initialLocation: index == navigationShell.currentIndex,
        ),
        onCreatePressed: () => context.pushNamed(AppRoutes.create),
      ),
    );
  }
}
