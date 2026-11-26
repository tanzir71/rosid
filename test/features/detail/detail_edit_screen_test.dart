import 'dart:async';

import 'package:drift/native.dart';
import 'package:material_ui/material_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rosid/core/l10n/app_localizations.dart';
import 'package:rosid/core/profile/app_profile.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/database/database_provider.dart';
import 'package:rosid/data/repositories/record_repository.dart';
import 'package:rosid/data/repositories/scan_repository.dart';
import 'package:rosid/features/detail/detail_edit_screen.dart';
import 'package:rosid/parsing/models/parsed_receipt.dart';

class _MockRecordRepository extends Mock implements RecordRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(DateTime(2000));
    registerFallbackValue(<ParsedLineItem>[]);
    registerFallbackValue(<String, double>{});
  });

  const cases =
      <
        ({
          String name,
          String label,
          int occurrence,
          String input,
          String message,
        })
      >[
        (
          name: 'total',
          label: 'Total',
          occurrence: 0,
          input: '1abc2',
          message: 'Enter valid non-negative total and tax amounts.',
        ),
        (
          name: 'tax',
          label: 'Tax',
          occurrence: 0,
          input: '1/2',
          message: 'Enter valid non-negative total and tax amounts.',
        ),
        (
          name: 'quantity',
          label: 'Quantity',
          occurrence: 0,
          input: '1,23',
          message: 'Each line item needs a valid name, quantity, and amount.',
        ),
        (
          name: 'unit price',
          label: 'Unit price',
          occurrence: 0,
          input: '12x34',
          message: 'Each line item needs a valid name, quantity, and amount.',
        ),
      ];

  for (final testCase in cases) {
    testWidgets('edit flow rejects malformed ${testCase.name}', (tester) async {
      final database = await _pumpReceiptEditor(tester);
      final field = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == testCase.label,
      );
      expect(field, findsNWidgets(testCase.label == 'Total' ? 2 : 1));

      await tester.enterText(field.at(testCase.occurrence), testCase.input);
      final save = find.text('Save');
      await tester.scrollUntilVisible(
        save,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(find.text(testCase.message), findsOneWidget);
      final receipt = await database.select(database.receipts).getSingle();
      expect(receipt.total, 100);
    });
  }

  testWidgets('save blocks back and tolerates app teardown before completion', (
    tester,
  ) async {
    final database = await _seedReceiptDatabase();
    final records = _MockRecordRepository();
    final save = Completer<void>();
    when(() => records.categories()).thenAnswer((_) async => const []);
    when(
      () => records.saveReceipt(
        scanId: any(named: 'scanId'),
        merchant: any(named: 'merchant'),
        date: any(named: 'date'),
        total: any(named: 'total'),
        currency: any(named: 'currency'),
        categoryId: any(named: 'categoryId'),
        items: any(named: 'items'),
        fieldConfidence: any(named: 'fieldConfidence'),
        tax: any(named: 'tax'),
        paymentMethod: any(named: 'paymentMethod'),
        note: any(named: 'note'),
      ),
    ).thenAnswer((_) => save.future);

    await _pumpEditor(tester, database: database, records: records);
    final saveButton = find.text('Save');
    await tester.scrollUntilVisible(
      saveButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(saveButton);
    await tester.pump();
    tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(DetailEditScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    save.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

Future<AppDatabase> _pumpReceiptEditor(WidgetTester tester) async {
  final database = await _seedReceiptDatabase();
  await _pumpEditor(tester, database: database);
  return database;
}

Future<AppDatabase> _seedReceiptDatabase() async {
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(database.close);
  final scans = ScanRepository(database);
  final records = RecordRepository(database);
  final createdAt = DateTime(2026, 7, 17);
  await scans.createScan(
    id: 'receipt-edit',
    mode: ScanMode.receipt,
    imagePath: '/private/receipt-edit.jpg',
    langHint: 'automatic',
    createdAt: createdAt,
  );
  await records.saveReceipt(
    scanId: 'receipt-edit',
    merchant: 'Corner Shop',
    date: createdAt,
    total: 100,
    currency: 'BDT',
    categoryId: 'other',
    items: const [
      ParsedLineItem(
        name: 'Rice',
        quantity: 1,
        unitPrice: 50,
        amount: 50,
        rawText: '',
      ),
    ],
    fieldConfidence: const {},
  );
  return database;
}

Future<void> _pumpEditor(
  WidgetTester tester, {
  required AppDatabase database,
  RecordRepository? records,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        if (records != null)
          recordRepositoryProvider.overrideWithValue(records),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: DetailEditScreen(scanId: 'receipt-edit'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
