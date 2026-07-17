import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosid/core/profile/app_profile.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/repositories/history_repository.dart';
import 'package:rosid/data/repositories/record_repository.dart';
import 'package:rosid/data/repositories/scan_repository.dart';
import 'package:rosid/data/repositories/settings_repository.dart';
import 'package:rosid/parsing/models/parsed_receipt.dart';

void main() {
  late AppDatabase database;
  late ScanRepository scans;
  late RecordRepository records;
  late HistoryRepository history;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    scans = ScanRepository(database);
    records = RecordRepository(database);
    history = HistoryRepository(database);
    await database.select(database.categories).get();
  });

  tearDown(() => database.close());

  Future<void> createScan(String id, ScanMode mode) => scans.createScan(
    id: id,
    mode: mode,
    imagePath: '/private/$id.jpg',
    langHint: 'automatic',
    createdAt: DateTime(2026, 7, 17),
  );

  test('saves a receipt and line items transactionally', () async {
    await createScan('receipt-1', ScanMode.receipt);
    await records.saveReceipt(
      scanId: 'receipt-1',
      merchant: 'Shwapno',
      date: DateTime(2026, 7, 15),
      total: 120,
      currency: 'BDT',
      categoryId: 'groceries',
      items: const [
        ParsedLineItem(
          name: 'Rice',
          quantity: 2,
          unitPrice: 50,
          amount: 100,
          rawText: '',
        ),
      ],
      fieldConfidence: const {'total': 0.9},
    );

    expect(await database.select(database.receipts).get(), hasLength(1));
    expect(await database.select(database.lineItems).get(), hasLength(1));
    expect(await database.searchScanIds('Shwapno'), ['receipt-1']);
  });

  test('saving the same receipt updates rather than duplicates', () async {
    await createScan('receipt-1', ScanMode.receipt);
    for (final merchant in ['First', 'Updated']) {
      await records.saveReceipt(
        scanId: 'receipt-1',
        merchant: merchant,
        date: DateTime(2026, 7, 15),
        total: 10,
        currency: 'BDT',
        categoryId: 'other',
        items: const [],
        fieldConfidence: const {},
      );
    }
    final receipts = await database.select(database.receipts).get();
    expect(receipts, hasLength(1));
    expect(receipts.single.merchant, 'Updated');
  });

  test('saves searchable document tags', () async {
    await createScan('document-1', ScanMode.document);
    await records.saveDocument(
      scanId: 'document-1',
      title: 'Economics notes',
      body: 'Demand and supply',
      tags: const ['study', 'exam'],
      pinned: true,
    );

    expect(await database.select(database.documents).get(), hasLength(1));
    expect(await database.select(database.tags).get(), hasLength(2));
    expect(await database.searchScanIds('supply'), ['document-1']);
  });

  test('history filters receipts by category', () async {
    await createScan('receipt-1', ScanMode.receipt);
    await records.saveReceipt(
      scanId: 'receipt-1',
      merchant: 'Cafe',
      date: DateTime(2026, 7, 15),
      total: 250,
      currency: 'BDT',
      categoryId: 'food',
      items: const [],
      fieldConfidence: const {},
    );

    final values = await history.list(
      const HistoryQuery(type: HistoryTypeFilter.receipt, categoryId: 'food'),
    );
    expect(values.single.title, 'Cafe');
  });

  test(
    'delete all returns private paths and keeps default categories',
    () async {
      await createScan('document-1', ScanMode.document);
      final paths = await SettingsRepository(database).deleteAllData();

      expect(paths, contains('/private/document-1.jpg'));
      expect(await database.select(database.scans).get(), isEmpty);
      expect(await database.select(database.categories).get(), hasLength(7));
    },
  );
}
