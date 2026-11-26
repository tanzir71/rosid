import 'package:drift/native.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosid/app.dart';
import 'package:rosid/core/profile/app_profile.dart';
import 'package:rosid/core/routing/app_router.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/database/database_provider.dart';
import 'package:rosid/data/repositories/record_repository.dart';
import 'package:rosid/data/repositories/scan_repository.dart';
import 'package:rosid/data/repositories/startup_cleanup_repository.dart';
import 'package:rosid/features/detail/detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<SharedPreferences> preferences() async {
    SharedPreferences.setMockInitialValues({});
    return SharedPreferences.getInstance();
  }

  testWidgets('renders the navigable app shell', (tester) async {
    final prefs = await preferences();
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appProfileProvider.overrideWithValue(const AppProfile.android()),
          databaseProvider.overrideWithValue(database),
          startupCleanupProvider.overrideWith((ref) async => 0),
        ],
        child: const RosidApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('This month'), findsOneWidget);
    expect(find.byIcon(Icons.document_scanner_outlined), findsOneWidget);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('History'), findsWidgets);
  });

  testWidgets('uses Bangla labels from persisted language setting', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'language_code': 'bn'});
    final prefs = await SharedPreferences.getInstance();
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appProfileProvider.overrideWithValue(const AppProfile.android()),
          databaseProvider.overrideWithValue(database),
          startupCleanupProvider.overrideWith((ref) async => 0),
        ],
        child: const RosidApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('হোম'), findsOneWidget);
    expect(find.text('ইতিহাস'), findsOneWidget);
    expect(find.text('সেটিংস'), findsOneWidget);
    expect(find.byTooltip('অফলাইন'), findsOneWidget);
  });

  testWidgets('iOS profile starts documents-first and can enable expenses', (
    tester,
  ) async {
    final prefs = await preferences();
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appProfileProvider.overrideWithValue(const AppProfile.ios()),
          databaseProvider.overrideWithValue(database),
          startupCleanupProvider.overrideWith((ref) async => 0),
        ],
        child: const RosidApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No documents yet'), findsOneWidget);
    expect(find.text('This month'), findsNothing);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    final expenseSwitch = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Expense tracking'),
    );
    expect(expenseSwitch.value, isFalse);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Expense tracking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(find.text('This month'), findsOneWidget);
  });

  testWidgets(
    'expense-off profile hides receipt surfaces and rejects receipt details',
    (tester) async {
      final prefs = await preferences();
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
            appProfileProvider.overrideWithValue(const AppProfile.ios()),
            databaseProvider.overrideWithValue(database),
            startupCleanupProvider.overrideWith((ref) async => 0),
          ],
          child: const RosidApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('Lecture notes'), findsOneWidget);
      expect(find.text('Hidden merchant'), findsNothing);
      expect(find.text('Receipt'), findsNothing);
      expect(find.text('Category'), findsNothing);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Expense tracking'), findsOneWidget);
      expect(find.text('Default currency'), findsNothing);
      expect(find.text('Categories'), findsNothing);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(RosidApp)),
      );
      container.read(appRouterProvider).go('/detail/receipt-hidden');
      await tester.pumpAndSettle();

      expect(find.byType(DetailScreen), findsNothing);
      expect(find.text('Lecture notes'), findsOneWidget);
      expect(find.text('Hidden merchant'), findsNothing);
    },
  );
}
