import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/data/repositories/history_repository.dart';
import 'package:rosid/features/capture/capture_screen.dart';
import 'package:rosid/features/crop/crop_enhance_screen.dart';
import 'package:rosid/features/detail/detail_screen.dart';
import 'package:rosid/features/detail/detail_edit_screen.dart';
import 'package:rosid/features/export/export_screen.dart';
import 'package:rosid/features/history/history_screen.dart';
import 'package:rosid/features/home/home_screen.dart';
import 'package:rosid/features/review/document_review_screen.dart';
import 'package:rosid/features/review/receipt_review_screen.dart';
import 'package:rosid/features/settings/settings_screen.dart';
import 'package:rosid/features/shared/app_shell.dart';

class _RouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final _routerRefreshProvider = Provider<_RouterRefresh>((ref) {
  final refresh = _RouterRefresh();
  ref
    ..listen(expenseTrackingEnabledProvider, (previous, next) {
      if (previous != next) refresh.refresh();
    })
    ..onDispose(refresh.dispose);
  return refresh;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(_routerRefreshProvider);
  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) async {
      final expenseEnabled = ref.read(expenseTrackingEnabledProvider);
      final receiptOnly =
          state.matchedLocation == '/export' ||
          state.matchedLocation == '/review/receipt';
      if (!expenseEnabled && receiptOnly) return '/';
      if (!expenseEnabled && state.matchedLocation.startsWith('/detail/')) {
        final scanId = state.pathParameters['id'];
        if (scanId != null) {
          final detail = await ref
              .read(historyRepositoryProvider)
              .detail(scanId);
          if (detail?.entry.isReceipt ?? false) return '/';
        }
      }
      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          GoRoute(
            path: '/history',
            builder: (context, state) => const HistoryScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/capture',
        builder: (context, state) => const CaptureScreen(),
      ),
      GoRoute(
        path: '/crop',
        builder: (context, state) => const CropEnhanceScreen(),
      ),
      GoRoute(
        path: '/review/receipt',
        builder: (context, state) => const ReceiptReviewScreen(),
      ),
      GoRoute(
        path: '/review/document',
        builder: (context, state) => const DocumentReviewScreen(),
      ),
      GoRoute(
        path: '/detail/:id',
        builder: (context, state) =>
            DetailScreen(scanId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/detail/:id/edit',
        builder: (context, state) =>
            DetailEditScreen(scanId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/export',
        builder: (context, state) => const ExportScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
