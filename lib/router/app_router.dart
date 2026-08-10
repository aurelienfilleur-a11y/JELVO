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
import '../features/calendar/screens/event_detail_screen.dart';
import '../features/contacts/screens/add_contact_screen.dart';
import '../features/contacts/screens/contacts_screen.dart';
import '../features/contacts/screens/my_qr_code_screen.dart';
import '../features/contacts/screens/scan_contact_screen.dart';
import '../features/create/models/creation_kind.dart';
import '../features/create/screens/create_screen.dart';
import '../features/groups/screens/group_detail_screen.dart';
import '../features/groups/screens/group_form_screen.dart';
import '../features/groups/screens/groups_screen.dart';
import '../features/groups/screens/invitation_screen.dart';
import '../features/groups/screens/join_group_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/profile/screens/settings_screen.dart';
import '../features/tasks/screens/task_detail_screen.dart';
import '../features/tasks/screens/tasks_screen.dart';
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

      if (status == AuthStatus.signedOut) {
        return AppRoutes.isPublic(location) ? null : AppRoutes.loginPath;
      }
      // Connecté : seuls les écrans d'authentification n'ont plus lieu d'être.
      // Un lien d'invitation, lui, reste ouvrable avec une session — c'est même
      // le cas courant quand un membre teste son propre lien.
      return AppRoutes.publicPaths.contains(location)
          ? AppRoutes.homePath
          : null;
    },
    routes: <RouteBase>[
      // Les quatre onglets vivent dans un IndexedStack : chacun garde son état.
      StatefulShellRoute.indexedStack(
        builder:
            (
              BuildContext context,
              GoRouterState state,
              StatefulNavigationShell navigationShell,
            ) => AppShell(
              navigationShell: navigationShell,
              // `state.uri` porte l'emplacement complet, y compris l'écran
              // empilé dans la branche active — c'est ce dont le bouton « + »
              // a besoin pour être vraiment contextuel.
              location: state.uri.path,
            ),
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
                routes: <RouteBase>[
                  // Déclaré avant `:id`, sinon « nouveau » serait pris pour un
                  // identifiant de groupe.
                  GoRoute(
                    path: 'nouveau',
                    name: AppRoutes.groupCreate,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (BuildContext context, GoRouterState state) =>
                        const GroupFormScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    name: AppRoutes.groupDetail,
                    builder: (BuildContext context, GoRouterState state) =>
                        GroupDetailScreen(
                          groupId: state.pathParameters['id'] ?? '',
                        ),
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'modifier',
                        name: AppRoutes.groupEdit,
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (BuildContext context, GoRouterState state) =>
                            GroupFormScreen(
                              groupId: state.pathParameters['id'],
                            ),
                      ),
                    ],
                  ),
                ],
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
                routes: <RouteBase>[
                  GoRoute(
                    path: 'ajouter',
                    name: AppRoutes.addContact,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (BuildContext context, GoRouterState state) =>
                        const AddContactScreen(),
                  ),
                  GoRoute(
                    path: 'scanner',
                    name: AppRoutes.scanContact,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (BuildContext context, GoRouterState state) =>
                        const ScanContactScreen(),
                  ),
                ],
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
        builder: (BuildContext context, GoRouterState state) {
          final Map<String, String> parametres = state.uri.queryParameters;
          return CreateScreen(
            groupId: parametres[AppRoutes.createGroupParam],
            kind: CreationKind.fromParam(parametres[AppRoutes.createKindParam]),
          );
        },
      ),

      // Détails, empilés sur le navigateur racine : ils s'ouvrent depuis
      // n'importe quel onglet et depuis les notifications.
      GoRoute(
        path: AppRoutes.tasksPath,
        name: AppRoutes.tasks,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const TasksScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: ':id',
            name: AppRoutes.taskDetail,
            parentNavigatorKey: _rootNavigatorKey,
            builder: (BuildContext context, GoRouterState state) =>
                TaskDetailScreen(taskId: state.pathParameters['id'] ?? ''),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.eventDetailPath,
        name: AppRoutes.eventDetail,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            EventDetailScreen(eventId: state.pathParameters['id'] ?? ''),
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
      GoRoute(
        path: AppRoutes.notificationsPath,
        name: AppRoutes.notifications,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.myQrCodePath,
        name: AppRoutes.myQrCode,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const MyQrCodeScreen(),
      ),

      GoRoute(
        path: AppRoutes.invitationsPath,
        name: AppRoutes.invitations,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const InvitationsScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: ':id',
            name: AppRoutes.invitation,
            parentNavigatorKey: _rootNavigatorKey,
            builder: (BuildContext context, GoRouterState state) =>
                InvitationScreen(
                  invitationId: state.pathParameters['id'] ?? '',
                ),
          ),
        ],
      ),

      // Page publique d'un lien de partage : elle doit s'ouvrir sans session,
      // c'est toute la raison d'être du lien.
      GoRoute(
        path: AppRoutes.joinGroupPath,
        name: AppRoutes.joinGroup,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            JoinGroupScreen(token: state.pathParameters['jeton'] ?? ''),
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
