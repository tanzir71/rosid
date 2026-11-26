import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rosid/app.dart';
import 'package:rosid/core/routing/app_router.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/database/database_provider.dart';
import 'package:rosid/data/repositories/record_repository.dart';
import 'package:rosid/data/repositories/scan_repository.dart';
import 'package:rosid/data/repositories/startup_cleanup_repository.dart';
import 'package:rosid/core/profile/app_profile.dart';
import 'package:rosid/features/detail/detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<SharedPreferences> preferences([
    Map<String, Object> initial = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(initial);
    return SharedPreferences.getInstance();
  }

  testWidgets('first run completes onboarding and lands on Home', (
    tester,
  ) async {
    final prefs = await preferences();
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(database),
          startupCleanupProvider.overrideWith((ref) async => 0),
        ],
        child: const RosidApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Step 1: Choose English
    await tester.ensureVisible(find.text('English'));
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('welcome-continue-language')));
    await tester.pumpAndSettle();

    // Step 2: Purposes screen
    expect(find.text('What do you need Rosid for?'), findsOneWidget);
    await tester.ensureVisible(find.text('Receipts and spending'));
    await tester.tap(find.text('Receipts and spending'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('welcome-continue-purpose')));
    await tester.pumpAndSettle();

    // Step 3: Camera explanation -> skip
    expect(find.text('Allow the camera to scan'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('welcome-skip-camera')));
    await tester.pumpAndSettle();

    // Landed on Home with Expenses tab enabled
    expect(find.text('What are you scanning?'), findsOneWidget);
    expect(find.text('Expenses'), findsOneWidget);
  });

  testWidgets('renders the navigable v2 app shell in English', (tester) async {
    final prefs = await preferences({
      'onboarding_complete': true,
      'language_code': 'en',
      'expense_tracking_enabled': true,
    });
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(database),
          startupCleanupProvider.overrideWith((ref) async => 0),
        ],
        child: const RosidApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('What are you scanning?'), findsOneWidget);
    expect(find.byKey(const ValueKey('dock-scan-button')), findsOneWidget);

    await tester.tap(find.text('Library').last);
    await tester.pumpAndSettle();
    expect(find.text('Search inside your papers'), findsOneWidget);

    await tester.tap(find.text('Bundles'));
    await tester.pumpAndSettle();
    expect(find.text('No bundles yet'), findsOneWidget);
  });

  testWidgets('uses Bangla labels from persisted language setting', (
    tester,
  ) async {
    final prefs = await preferences({
      'onboarding_complete': true,
      'language_code': 'bn',
      'expense_tracking_enabled': true,
    });
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(database),
          startupCleanupProvider.overrideWith((ref) async => 0),
        ],
        child: const RosidApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('হোম'), findsOneWidget);
    expect(find.text('কাগজপত্র'), findsWidgets);
    expect(find.text('ফাইল'), findsWidgets);
    expect(find.text('খরচ'), findsOneWidget);
    expect(find.text('অফলাইন'), findsOneWidget);
  });

  testWidgets(
    'expenses-off setting hides Expenses tab and rejects receipt details',
    (tester) async {
      final prefs = await preferences({
        'onboarding_complete': true,
        'language_code': 'en',
        'expense_tracking_enabled': false,
      });
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final scans = ScanRepository(database);
      final records = RecordRepository(database);
      final createdAt = DateTime(2026, 7, 17);
      await scans.createScan(
        id: 'receipt-hidden',
        mode: ScanMode.receipt,
        imagePath: '/private/receipt-hidden.jpg',
        langHint: 'automatic',
        createdAt: createdAt,
      );
      await records.saveReceipt(
        scanId: 'receipt-hidden',
        merchant: 'Hidden merchant',
        date: createdAt,
        total: 50,
        currency: 'BDT',
        categoryId: 'food',
        items: const [],
        fieldConfidence: const {},
      );
      await scans.createScan(
        id: 'document-visible',
        mode: ScanMode.document,
        imagePath: '/private/document-visible.jpg',
        langHint: 'automatic',
        createdAt: createdAt,
      );
      await records.saveDocument(
        scanId: 'document-visible',
        title: 'Lecture notes',
        body: 'Visible document body',
        tags: const [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWithValue(database),
            startupCleanupProvider.overrideWith((ref) async => 0),
          ],
          child: const RosidApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Expenses'), findsNothing);

      await tester.tap(find.text('Library').last);
      await tester.pumpAndSettle();
      expect(find.text('Lecture notes'), findsOneWidget);
      expect(find.text('Hidden merchant'), findsNothing);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(RosidApp)),
      );
      container.read(appRouterProvider).go('/detail/receipt-hidden');
      await tester.pumpAndSettle();

      expect(find.byType(DetailScreen), findsNothing);
      expect(find.text('Hidden merchant'), findsNothing);
    },
  );
}
