import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rosid/core/extensions/l10n_extension.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/core/theme/rosid_icons.dart';
import 'package:rosid/core/widgets/rosid_navigation.dart';
import 'package:rosid/data/repositories/history_repository.dart';
import 'package:rosid/features/capture/capture_screen.dart';
import 'package:rosid/features/crop/crop_enhance_screen.dart';
import 'package:rosid/features/detail/detail_edit_screen.dart';
import 'package:rosid/features/detail/detail_screen.dart';
import 'package:rosid/features/export/export_screen.dart';
import 'package:rosid/features/home/home_screen.dart';
import 'package:rosid/features/review/document_review_screen.dart';
import 'package:rosid/features/review/receipt_review_screen.dart';
import 'package:rosid/features/settings/settings_screen.dart';
import 'package:rosid/features/shared/app_shell.dart';
import 'package:rosid/features/shell_views/v2_shell_screens.dart';
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
        builder: (context, state) => const CaptureScreen(),
      ),
      GoRoute(
        path: '/capture',
        builder: (context, state) => const CaptureScreen(),
      ),
      GoRoute(
        path: '/scan/adjust',
        builder: (context, state) => const CropEnhanceScreen(),
      ),
      GoRoute(
        path: '/crop',
        builder: (context, state) => const CropEnhanceScreen(),
      ),
      GoRoute(
        path: '/scan/reading',
        builder: (context, state) => V2RouteShellScreen(
          title: context.l10n.readingOnPhone,
          body: context.l10n.happensOnPhone,
          icon: RosidIcons.scan,
        ),
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
          return PaperShellScreen(
            scanId: state.pathParameters['id']!,
            initialTab: tab,
          );
        },
      ),
      GoRoute(
        path: '/paper/:id/check',
        builder: (context, state) => V2RouteShellScreen(
          title: context.l10n.checkWords,
          body: context.l10n.checkWordsEmpty,
          icon: RosidIcons.checkCircle,
        ),
      ),
      GoRoute(
        path: '/paper/:id/export',
        builder: (context, state) => const ExportScreen(),
      ),
      GoRoute(
        path: '/paper/:id/export/preview',
        builder: (context, state) => V2RouteShellScreen(
          title: context.l10n.exportPdf,
          body: context.l10n.englishDraftPending,
          icon: RosidIcons.document,
        ),
      ),
      GoRoute(
        path: '/paper/:id/export/id',
        builder: (context, state) => V2RouteShellScreen(
          title: context.l10n.idCard,
          body: context.l10n.export,
          icon: RosidIcons.idCard,
        ),
      ),
      GoRoute(
        path: '/paper/:id/export/saved',
        builder: (context, state) => V2RouteShellScreen(
          title: context.l10n.saved,
          body: context.l10n.privacyDescription,
          icon: RosidIcons.checkCircle,
        ),
      ),
      GoRoute(
        path: '/paper/:id/export/cover',
        builder: (context, state) => V2RouteShellScreen(
          title: context.l10n.coverDetailTitle,
          body: context.l10n.coverDetailHint,
          icon: RosidIcons.hide,
        ),
      ),
      GoRoute(
        path: '/paper/:id/receipt',
        builder: (context, state) => const ReceiptReviewScreen(),
      ),

      // 05 Name book
      GoRoute(
        path: '/names',
        builder: (context, state) => V2RouteShellScreen(
          title: context.l10n.names,
          body: context.l10n.namesEmpty,
          icon: RosidIcons.people,
        ),
      ),

      // 08 Bundles detail & export
      GoRoute(
        path: '/bundles/:id',
        builder: (context, state) => V2RouteShellScreen(
          title: context.l10n.bundles,
          body: context.l10n.bundleChecklistComing,
          icon: RosidIcons.bundle,
        ),
      ),
      GoRoute(
        path: '/bundles/:id/export',
        builder: (context, state) => V2RouteShellScreen(
          title: context.l10n.export,
          body: context.l10n.bundleChecklistComing,
          icon: RosidIcons.share,
        ),
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
        builder: (context, state) => V2RouteShellScreen(
          title: context.l10n.backUpAndMove,
          body: context.l10n.backupPageBody,
          icon: RosidIcons.backup,
        ),
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
