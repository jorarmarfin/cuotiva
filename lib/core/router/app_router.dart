import 'package:go_router/go_router.dart';

import '../../features/settings/presentation/screens/credits_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../widgets/main_shell.dart';
import '../widgets/placeholder_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => MainShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const PlaceholderScreen('Inicio'),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/cobros',
              builder: (_, _) => const PlaceholderScreen('Cobros'),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/personas',
              builder: (_, _) => const PlaceholderScreen('Personas'),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/reportes',
              builder: (_, _) => const PlaceholderScreen('Reportes'),
            ),
          ],
        ),
      ],
    ),
    GoRoute(path: '/ajustes', builder: (_, _) => const SettingsScreen()),
    GoRoute(path: '/credits', builder: (_, _) => const CreditsScreen()),
  ],
);
