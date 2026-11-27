import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/core/widgets/rosid_navigation.dart';
import 'package:rosid/data/repositories/history_repository.dart';
import 'package:rosid/features/bundles/bundle_checklist_screen.dart';
import 'package:rosid/features/bundles/bundle_export_screen.dart';
import 'package:rosid/features/bundles/bundles_screen.dart';
import 'package:rosid/features/capture/adjust_page_screen.dart';
import 'package:rosid/features/capture/capture_screen.dart';
import 'package:rosid/features/capture/reading_progress_screen.dart';
import 'package:rosid/features/capture/scan_camera_screen.dart';
import 'package:rosid/features/capture/scan_controller.dart';
import 'package:rosid/features/crop/crop_enhance_screen.dart';
import 'package:rosid/features/detail/detail_edit_screen.dart';
import 'package:rosid/features/detail/detail_screen.dart';
import 'package:rosid/features/expenses/check_receipt_screen.dart';
import 'package:rosid/features/expenses/expenses_screen.dart';
import 'package:rosid/features/export/cover_detail_screen.dart';
import 'package:rosid/features/export/export_id_card_screen.dart';
import 'package:rosid/features/export/export_preview_screen.dart';
import 'package:rosid/features/export/export_saved_screen.dart';
import 'package:rosid/features/export/export_screen.dart';
import 'package:rosid/features/export/paper_export_options_screen.dart';
import 'package:rosid/features/home/home_screen.dart';
import 'package:rosid/features/library/library_screen.dart';
import 'package:rosid/features/paper/check_words_screen.dart';
import 'package:rosid/features/paper/paper_screen.dart';
import 'package:rosid/features/review/document_review_screen.dart';
import 'package:rosid/features/review/receipt_review_screen.dart';
import 'package:rosid/features/safety/backup_screen.dart';
import 'package:rosid/features/settings/categories_screen.dart';
import 'package:rosid/features/settings/settings_screen.dart';
import 'package:rosid/features/shared/app_shell.dart';
import 'package:rosid/features/translation/name_book_screen.dart';
import 'package:rosid/features/welcome/welcome_screens.dart';

class _RouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final _routerRefreshProvider = Provider<_RouterRefresh>((ref) {
  final refresh = _RouterRefresh();
  ref
    ..listen(appSettingsProvider, (previous, next) {
      if (previous?.expenseTrackingEnabled != next.expenseTrackingEnabled ||
          previous?.onboardingComplete != next.onboardingComplete) {
        refresh.refresh();
      }
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
      final settings = ref.read(appSettingsProvider);
      final location = state.matchedLocation;

      if (!settings.onboardingComplete && !location.startsWith('/welcome')) {
        return '/welcome';
      }

      final expenseEnabled = settings.expenseTrackingEnabled;
      final receiptOnly =
          location == '/export' ||
          location == '/review/receipt' ||
          location == '/expenses';
      if (!expenseEnabled && receiptOnly) return '/';
      if (!expenseEnabled &&
          (location.startsWith('/detail/') || location.startsWith('/paper/'))) {
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
      // 01 First run
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeLanguageScreen(),
      ),
      GoRoute(
        path: '/welcome/purpose',
        builder: (context, state) => const WelcomePurposeScreen(),
      ),
      GoRoute(
        path: '/welcome/camera',
        builder: (context, state) => const WelcomeCameraScreen(),
      ),

      // Main 4-tab shell (Home, Library, Bundles, Expenses)
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          GoRoute(
            path: '/library',
            builder: (context, state) => LibraryScreen(
              initialQuery: state.uri.queryParameters['q'] ?? '',
            ),
          ),
          GoRoute(
            path: '/history',
            builder: (context, state) => LibraryScreen(
              initialQuery: state.uri.queryParameters['q'] ?? '',
            ),
          ),
          GoRoute(
            path: '/bundles',
            builder: (context, state) => const BundlesScreen(),
          ),
          GoRoute(
            path: '/expenses',
            builder: (context, state) => const ExpensesScreen(),
          ),
        ],
      ),

      // 03 Scan
      GoRoute(
        path: '/scan',
        builder: (context, state) {
          final modeParam = state.uri.queryParameters['mode'];
          final mode = switch (modeParam) {
            'id' => V2ScanMode.idCard,
            'receipt' => V2ScanMode.receipt,
            'translate' => V2ScanMode.translate,
            _ => V2ScanMode.document,
          };
          return ScanCameraScreen(initialMode: mode);
        },
      ),
      GoRoute(
        path: '/capture',
        builder: (context, state) => const CaptureScreen(),
      ),
      GoRoute(
        path: '/scan/adjust',
        builder: (context, state) => const AdjustPageScreen(),
      ),
      GoRoute(
        path: '/crop',
        builder: (context, state) => const CropEnhanceScreen(),
      ),
      GoRoute(
        path: '/scan/reading',
        builder: (context, state) => const ReadingProgressScreen(),
      ),

      // 04 Read and fix + 05 Translate + 06 Export
      GoRoute(
        path: '/paper/:id',
        builder: (context, state) {
          final tabParam = state.uri.queryParameters['tab'];
          final tab = switch (tabParam) {
            'scan' => RosidReaderTab.scan,
            'english' => RosidReaderTab.english,
            _ => RosidReaderTab.text,
          };
          return PaperScreen(
            scanId: state.pathParameters['id']!,
            initialTab: tab,
          );
        },
      ),
      GoRoute(
        path: '/paper/:id/check',
        builder: (context, state) =>
            CheckWordsScreen(scanId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/paper/:id/export',
        builder: (context, state) =>
            PaperExportOptionsScreen(scanId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/paper/:id/export/preview',
        builder: (context, state) =>
            ExportPreviewScreen(scanId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/paper/:id/export/id',
        builder: (context, state) =>
            ExportIdCardScreen(scanId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/paper/:id/export/saved',
        builder: (context, state) =>
            ExportSavedScreen(scanId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/paper/:id/export/cover',
        builder: (context, state) =>
            CoverDetailScreen(scanId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/paper/:id/receipt',
        builder: (context, state) =>
            CheckReceiptScreen(scanId: state.pathParameters['id']!),
      ),

      // 05 Name book
      GoRoute(
        path: '/names',
        builder: (context, state) => const NameBookScreen(),
      ),

      // 08 Bundles detail & export
      GoRoute(
        path: '/bundles/:id',
        builder: (context, state) =>
            BundleChecklistScreen(bundleId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/bundles/:id/export',
        builder: (context, state) =>
            BundleExportScreen(bundleId: state.pathParameters['id']!),
      ),

      // 10 Settings & safety
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/purposes',
        builder: (context, state) =>
            const WelcomePurposeScreen(fromSettings: true),
      ),
      GoRoute(
        path: '/settings/backup',
        builder: (context, state) => const BackupScreen(),
      ),
      GoRoute(
        path: '/settings/categories',
        builder: (context, state) => const CategoriesScreen(),
      ),

      // Legacy v1 review/detail routes kept functional while M2–M8 replace them
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
