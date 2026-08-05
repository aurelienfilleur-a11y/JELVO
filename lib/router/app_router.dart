import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/core.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/reset_password_screen.dart';
import '../features/auth/screens/signup_credentials_screen.dart';
import '../features/auth/screens/signup_identity_screen.dart';
import '../features/auth/screens/verify_email_screen.dart';
import '../features/calendar/screens/calendar_screen.dart';
import '../features/contacts/screens/contacts_screen.dart';
import '../features/create/screens/create_screen.dart';
import '../features/groups/screens/groups_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/profile/screens/settings_screen.dart';
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
    // Rejoue la redirection à chaque connexion, déconnexion ou restauration de
    // session : GoRouter ne sait pas observer un provider tout seul.
    refreshListenable: ref.watch(authRefreshProvider),
    redirect: (BuildContext context, GoRouterState state) {
      final AuthStatus status = ref.read(authStatusProvider);
      final String location = state.matchedLocation;
      final bool isPublic = AppRoutes.publicPaths.contains(location);

      if (status == AuthStatus.signedOut) {
        return isPublic ? null : AppRoutes.loginPath;
      }
      // Connecté : les écrans d'authentification n'ont plus lieu d'être.
      return isPublic ? AppRoutes.homePath : null;
    },
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

      GoRoute(
        path: AppRoutes.profilePath,
        name: AppRoutes.profile,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsPath,
        name: AppRoutes.settings,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const SettingsScreen(),
      ),

      // Parcours d'authentification : hors du shell, donc sans barre de
      // navigation. L'inscription est une pile, pour que le retour arrière
      // revienne à l'étape précédente sans perdre la saisie.
      GoRoute(
        path: AppRoutes.loginPath,
        name: AppRoutes.login,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signUpPath,
        name: AppRoutes.signUp,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const SignUpCredentialsScreen(),
      ),
      GoRoute(
        path: AppRoutes.signUpIdentityPath,
        name: AppRoutes.signUpIdentity,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const SignUpIdentityScreen(),
      ),
      GoRoute(
        path: AppRoutes.verifyEmailPath,
        name: AppRoutes.verifyEmail,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const VerifyEmailScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPasswordPath,
        name: AppRoutes.forgotPassword,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPasswordPath,
        name: AppRoutes.resetPassword,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const ResetPasswordScreen(),
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
