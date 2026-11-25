import 'package:go_router/go_router.dart';

import 'screens/activities_hub_screen.dart';
import 'state/auth_model.dart';
import 'screens/journal_screen.dart';
import 'screens/login_screen.dart';
import 'screens/nature_sounds_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/session_detail_screen.dart';
import 'screens/session_form_screen.dart';
import 'screens/welcome_screen.dart';
import 'widgets/app_shell.dart';

GoRouter createRouter(AuthModel auth) => GoRouter(
  initialLocation: '/welcome',
  refreshListenable: auth,
  // Нет токена (или пришёл 401) → на экран входа.
  redirect: (_, state) {
    final open = state.matchedLocation == '/welcome' || state.matchedLocation == '/auth';
    if (!auth.isLoggedIn && !open) return '/auth';
    if (auth.isLoggedIn && open) return '/home';
    return null;
  },
  routes: [
    GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
    GoRoute(path: '/auth', builder: (_, _) => const LoginScreen()),
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => AppShell(navigationShell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/home',
            builder: (_, _) => const ActivitiesHubScreen(),
            routes: [
              GoRoute(path: 'new-session', builder: (_, _) => const SessionFormScreen()),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/sounds', builder: (_, _) => const NatureSoundsScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/journal',
            builder: (_, _) => const JournalScreen(),
            routes: [
              GoRoute(
                path: 'session/:id',
                builder: (_, state) =>
                    SessionDetailScreen(sessionId: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (_, state) =>
                        SessionFormScreen(sessionId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
        ]),
      ],
    ),
  ],
);
