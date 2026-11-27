import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rosid/core/l10n/app_localizations.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/core/theme/app_theme.dart';
import 'package:rosid/core/widgets/rosid_navigation.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/database/database_provider.dart';
import 'package:rosid/features/expenses/check_receipt_screen.dart';
import 'package:rosid/features/expenses/expenses_repository.dart';
import 'package:rosid/features/expenses/expenses_screen.dart';
import 'package:rosid/features/safety/backup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/golden_fonts.dart';

void main() {
  setUpAll(loadRosidTestFonts);

  Future<void> pumpPhone(
    WidgetTester tester,
    AppDatabase db,
    SharedPreferences prefs,
    Widget child,
    String goldenName, {
    RosidNavTab? dockTab,
  }) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Widget screen = child;
    if (dockTab != null) {
      screen = Stack(
        children: [
          child,
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Material(
              type: MaterialType.transparency,
              child: RosidNavDock(
                activeTab: dockTab,
                showExpenses: true,
                onSelectTab: (_) {},
                onScanPressed: () {},
                homeLabel: 'Home',
                libraryLabel: 'Library',
                bundlesLabel: 'Bundles',
                expensesLabel: 'Expenses',
                scanTooltip: 'Scan',
              ),
            ),
          ),
        ],
      );
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$goldenName.png'),
    );
  }

  testWidgets('M8 screen golden: expenses', (tester) async {
    SharedPreferences.setMockInitialValues({
      'language_code': 'en',
      'expense_tracking_enabled': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final nov = DateTime(2026, 11, 1);
    final preview = MonthlyExpensesView(
      month: nov,
      total: 18460,
      previousMonthTotal: 20600,
      currency: 'BDT',
      categories: const [
        CategorySpendRow(
          categoryId: 'cat_groceries',
          name: 'Groceries',
          amount: 7920,
          fractionOfMax: 1.0,
        ),
        CategorySpendRow(
          categoryId: 'cat_utilities',
          name: 'Utilities',
          amount: 4310,
          fractionOfMax: 4310 / 7920,
        ),
        CategorySpendRow(
          categoryId: 'cat_transport',
          name: 'Transport',
          amount: 2880,
          fractionOfMax: 2880 / 7920,
        ),
        CategorySpendRow(
          categoryId: 'cat_health',
          name: 'Health',
          amount: 1950,
          fractionOfMax: 1950 / 7920,
        ),
        CategorySpendRow(
          categoryId: 'cat_other',
          name: 'Other',
          amount: 1400,
          fractionOfMax: 1400 / 7920,
        ),
      ],
      receipts: [
        ExpenseReceiptRow(
          receipt: Receipt(
            id: 'r1',
            scanId: 's1',
            merchant: 'Shwapno, Banani',
            dateOfPurchase: DateTime(2026, 11, 24),
            total: 1840,
            currency: 'BDT',
            fieldConfidenceJson: '{}',
          ),
          scan: Scan(
            id: 's1',
            type: 'receipt',
            kind: 'receipt',
            language: 'en',
            checkCount: 0,
            imagePath: '',
            ocrRawText: '',
            langHint: 'auto',
            createdAt: DateTime(2026, 11, 24),
            updatedAt: DateTime(2026, 11, 24),
          ),
          categoryName: 'Groceries',
          items: const [],
        ),
        ExpenseReceiptRow(
          receipt: Receipt(
            id: 'r2',
            scanId: 's2',
            merchant: 'বিদ্যুৎ বিল, নভেম্বর',
            dateOfPurchase: DateTime(2026, 11, 12),
            total: 2310,
            currency: 'BDT',
            fieldConfidenceJson: '{}',
          ),
          scan: Scan(
            id: 's2',
            type: 'receipt',
            kind: 'receipt',
            language: 'bn',
            checkCount: 0,
            imagePath: '',
            ocrRawText: '',
            langHint: 'auto',
            createdAt: DateTime(2026, 11, 12),
            updatedAt: DateTime(2026, 11, 12),
          ),
          categoryName: 'Utilities',
          items: const [],
        ),
        ExpenseReceiptRow(
          receipt: Receipt(
            id: 'r3',
            scanId: 's3',
            merchant: 'ফার্মেসি, ধানমন্ডি',
            dateOfPurchase: DateTime(2026, 11, 9),
            total: 640,
            currency: 'BDT',
            fieldConfidenceJson: '{}',
          ),
          scan: Scan(
            id: 's3',
            type: 'receipt',
            kind: 'receipt',
            language: 'bn',
            checkCount: 0,
            imagePath: '',
            ocrRawText: '',
            langHint: 'auto',
            createdAt: DateTime(2026, 11, 9),
            updatedAt: DateTime(2026, 11, 9),
          ),
          categoryName: 'Health',
          items: const [],
        ),
      ],
    );

    await pumpPhone(
      tester,
      db,
      prefs,
      ExpensesScreen(previewView: preview),
      'm8_expenses',
      dockTab: RosidNavTab.expenses,
    );
  });

  testWidgets('M8 screen golden: expenses-check-receipt', (tester) async {
    SharedPreferences.setMockInitialValues({'language_code': 'en'});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final dt = DateTime(2026, 11, 24);
    final preview = ReceiptCheckView(
      scan: Scan(
        id: 's1',
        type: 'receipt',
        kind: 'receipt',
        language: 'en',
        checkCount: 0,
        imagePath: '',
        ocrRawText: '',
        langHint: 'auto',
        createdAt: dt,
        updatedAt: dt,
      ),
      receipt: Receipt(
        id: 'r1',
        scanId: 's1',
        merchant: 'Shwapno, Banani',
        dateOfPurchase: dt,
        total: 1840.0,
        currency: 'BDT',
        tax: 87.62,
        paymentMethod: 'Card',
        categoryId: 'cat_groceries',
        fieldConfidenceJson: '{"date": 0.45}',
      ),
      items: const [
        LineItem(id: 'i1', receiptId: 'r1', name: 'Rice', qty: 1, amount: 420),
        LineItem(
          id: 'i2',
          receiptId: 'r1',
          name: 'lentils',
          qty: 1,
          amount: 310,
        ),
        LineItem(id: 'i3', receiptId: 'r1', name: 'oil', qty: 1, amount: 260),
        LineItem(id: 'i4', receiptId: 'r1', name: 'Salt', qty: 1, amount: 250),
        LineItem(id: 'i5', receiptId: 'r1', name: 'Tea', qty: 1, amount: 300),
        LineItem(id: 'i6', receiptId: 'r1', name: 'Milk', qty: 1, amount: 300),
      ],
      pages: const [],
      lines: const [],
      categories: const [
        Category(
          id: 'cat_groceries',
          nameEn: 'Groceries',
          nameBn: 'মুদি',
          icon: 'tag',
          isDefault: true,
        ),
        Category(
          id: 'cat_food',
          nameEn: 'Food',
          nameBn: 'খাবার',
          icon: 'tag',
          isDefault: true,
        ),
        Category(
          id: 'cat_transport',
          nameEn: 'Transport',
          nameBn: 'যাতায়াত',
          icon: 'tag',
          isDefault: true,
        ),
        Category(
          id: 'cat_health',
          nameEn: 'Health',
          nameBn: 'স্বাস্থ্য',
          icon: 'tag',
          isDefault: true,
        ),
        Category(
          id: 'cat_other',
          nameEn: 'Other',
          nameBn: 'অন্যান্য',
          icon: 'tag',
          isDefault: true,
        ),
      ],
      sourceLineByField: const {},
    );

    await pumpPhone(
      tester,
      db,
      prefs,
      CheckReceiptScreen(
        scanId: 's1',
        previewView: preview,
        previewDateUncertain: true,
      ),
      'm8_expenses_check_receipt',
    );
  });

  testWidgets('M8 screen golden: settings-backup', (tester) async {
    SharedPreferences.setMockInitialValues({
      'language_code': 'en',
      'backup_reminder_enabled': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await pumpPhone(
      tester,
      db,
      prefs,
      BackupScreen(
        previewLastBackupAt: DateTime(2026, 11, 12),
        previewBackedUpCount: 96,
        previewNotBackedUpCount: 32,
      ),
      'm8_settings_backup',
    );
  });
}
