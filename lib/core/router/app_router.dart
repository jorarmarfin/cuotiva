import 'package:go_router/go_router.dart';

import '../../features/collections/presentation/screens/collection_detail_screen.dart';
import '../../features/collections/presentation/screens/collection_form_screen.dart';
import '../../features/collections/presentation/screens/collections_screen.dart';
import '../../features/installments/presentation/screens/installment_plan_screen.dart';
import '../../features/payments/presentation/screens/payment_detail_screen.dart';
import '../../features/payments/presentation/screens/payment_form_screen.dart';
import '../../features/receivables/presentation/screens/assign_receivables_screen.dart';
import '../../features/receivables/presentation/screens/receivable_detail_screen.dart';
import '../../features/contacts/presentation/screens/contact_detail_screen.dart';
import '../../features/contacts/presentation/screens/contact_form_screen.dart';
import '../../features/contacts/presentation/screens/contacts_screen.dart';
import '../../features/dashboard/presentation/screens/home_screen.dart';
import '../../features/settings/presentation/screens/credits_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/spaces/presentation/screens/space_detail_screen.dart';
import '../../features/spaces/presentation/screens/space_form_screen.dart';
import '../../features/spaces/presentation/screens/spaces_screen.dart';
import '../widgets/main_shell.dart';
import '../widgets/placeholder_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => MainShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/cobros',
              builder: (_, _) => const CollectionsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/personas',
              builder: (_, _) => const ContactsScreen(),
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
    GoRoute(path: '/espacios', builder: (_, _) => const SpacesScreen()),
    GoRoute(
      path: '/espacios/nuevo',
      builder: (_, _) => const SpaceFormScreen(),
    ),
    GoRoute(
      path: '/espacios/:id',
      builder: (_, s) => SpaceDetailScreen(spaceId: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/espacios/:id/editar',
      builder: (_, s) => SpaceFormScreen(spaceId: s.pathParameters['id']),
    ),
    GoRoute(
      path: '/personas/nuevo',
      builder: (_, _) => const ContactFormScreen(),
    ),
    GoRoute(
      path: '/personas/:id',
      builder: (_, s) =>
          ContactDetailScreen(contactId: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/personas/:id/editar',
      builder: (_, s) => ContactFormScreen(contactId: s.pathParameters['id']),
    ),
    GoRoute(
      path: '/cobros/nuevo',
      builder: (_, s) =>
          CollectionFormScreen(spaceId: s.uri.queryParameters['espacio']),
    ),
    GoRoute(
      path: '/cobros/:id',
      builder: (_, s) =>
          CollectionDetailScreen(collectionId: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/cobros/:id/editar',
      builder: (_, s) =>
          CollectionFormScreen(collectionId: s.pathParameters['id']),
    ),
    GoRoute(
      path: '/cobros/:id/asignar',
      builder: (_, s) =>
          AssignReceivablesScreen(collectionId: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/obligaciones/:id',
      builder: (_, s) =>
          ReceivableDetailScreen(receivableId: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/obligaciones/:id/abono',
      builder: (_, s) =>
          PaymentFormScreen(receivableId: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/obligaciones/:id/plan',
      builder: (_, s) =>
          InstallmentPlanScreen(receivableId: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/abonos/:id',
      builder: (_, s) =>
          PaymentDetailScreen(paymentId: s.pathParameters['id']!),
    ),
    GoRoute(path: '/ajustes', builder: (_, _) => const SettingsScreen()),
    GoRoute(path: '/credits', builder: (_, _) => const CreditsScreen()),
  ],
);
