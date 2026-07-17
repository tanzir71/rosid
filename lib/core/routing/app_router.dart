import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/features/shared/app_shell.dart';
import 'package:rosid/features/shared/placeholder_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final expenseEnabled = ref.watch(expenseTrackingEnabledProvider);
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final receiptOnly =
          state.matchedLocation == '/export' ||
          state.matchedLocation == '/review/receipt';
      if (!expenseEnabled && receiptOnly) return '/';
      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const PlaceholderScreen(
              title: 'Home',
              message: 'Rosid keeps every scan on this device.',
            ),
          ),
          GoRoute(
            path: '/history',
            builder: (context, state) =>
                const PlaceholderScreen(title: 'History'),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) =>
                const PlaceholderScreen(title: 'Settings'),
          ),
        ],
      ),
      GoRoute(
        path: '/capture',
        builder: (context, state) => const PlaceholderScreen(title: 'Capture'),
      ),
      GoRoute(
        path: '/crop',
        builder: (context, state) =>
            const PlaceholderScreen(title: 'Crop & enhance'),
      ),
      GoRoute(
        path: '/review/receipt',
        builder: (context, state) =>
            const PlaceholderScreen(title: 'Review receipt'),
      ),
      GoRoute(
        path: '/review/document',
        builder: (context, state) =>
            const PlaceholderScreen(title: 'Review document'),
      ),
      GoRoute(
        path: '/detail/:id',
        builder: (context, state) =>
            PlaceholderScreen(title: 'Scan ${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/export',
        builder: (context, state) =>
            const PlaceholderScreen(title: 'Export expenses'),
      ),
    ],
  );
});
