import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/core.dart';
import '../features/calendar/screens/calendar_screen.dart';
import '../features/contacts/screens/contacts_screen.dart';
import '../features/create/screens/create_screen.dart';
import '../features/groups/screens/groups_screen.dart';
import '../features/home/screens/home_screen.dart';
import 'app_routes.dart';
import 'app_shell.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// Routeur de l'application.
///
/// Exposé via Riverpod pour que des redirections futures (authentification,
/// onboarding) puissent observer d'autres providers sans réécrire le graphe.
final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.homePath,
    debugLogDiagnostics: false,
    routes: <RouteBase>[
      // Les quatre onglets vivent dans un IndexedStack : chacun garde son état.
      StatefulShellRoute.indexedStack(
        builder:
            (
              BuildContext context,
              GoRouterState state,
              StatefulNavigationShell navigationShell,
            ) => AppShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.homePath,
                name: AppRoutes.home,
                builder: (BuildContext context, GoRouterState state) =>
                    const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.groupsPath,
                name: AppRoutes.groups,
                builder: (BuildContext context, GoRouterState state) =>
                    const GroupsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.calendarPath,
                name: AppRoutes.calendar,
                builder: (BuildContext context, GoRouterState state) =>
                    const CalendarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.contactsPath,
                name: AppRoutes.contacts,
                builder: (BuildContext context, GoRouterState state) =>
                    const ContactsScreen(),
              ),
            ],
          ),
        ],
      ),

      // Empilé sur le navigateur racine : l'écran de création couvre la barre
      // de navigation, comme une modale plein écran.
      GoRoute(
        path: AppRoutes.createPath,
        name: AppRoutes.create,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const CreateScreen(),
      ),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) =>
        _RouteErrorScreen(location: state.uri.toString()),
  );

  ref.onDispose(router.dispose);
  return router;
});

/// Page affichée pour une URL inconnue — cas réel sur le web, où l'utilisateur
/// peut saisir n'importe quel chemin.
class _RouteErrorScreen extends StatelessWidget {
  const _RouteErrorScreen({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: EmptyState(
          icon: Icons.explore_off_rounded,
          title: 'Page introuvable',
          message: 'Aucun écran ne correspond à « $location ».',
          actionLabel: "Revenir à l'accueil",
          onActionPressed: () => context.goNamed(AppRoutes.home),
        ),
      ),
    );
  }
}
