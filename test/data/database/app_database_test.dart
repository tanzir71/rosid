import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosid/core/profile/app_profile.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/repositories/scan_repository.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('creates and seeds the seven default categories', () async {
    final categories = await database.select(database.categories).get();

    expect(categories, hasLength(7));
    expect(
      categories.map((category) => category.nameBn),
      containsAll(['মুদি', 'খাবার', 'যাতায়াত', 'অন্যান্য']),
    );
  });

  test('FTS index finds English and Bangla content', () async {
    await database.indexScan(
      scanId: 'scan-1',
      text: ['Dhaka Grocery', 'সর্বমোট ১২৫০ টাকা'],
    );

    expect(await database.searchScanIds('Grocery'), ['scan-1']);
    expect(await database.searchScanIds('সর্বমোট'), ['scan-1']);
  });

  test('reindex replaces stale content', () async {
    await database.indexScan(scanId: 'scan-1', text: ['old merchant']);
    await database.indexScan(scanId: 'scan-1', text: ['new merchant']);

    expect(await database.searchScanIds('old'), isEmpty);
    expect(await database.searchScanIds('new'), ['scan-1']);
  });

  test('FTS search is unbounded unless a caller requests a limit', () async {
    for (var index = 0; index < 125; index++) {
      await database.indexScan(
        scanId: 'scan-$index',
        text: ['shared searchable token'],
      );
    }

    expect(await database.searchScanIds('searchable'), hasLength(125));
    expect(
      await database.searchScanIds('searchable', limit: 25),
      hasLength(25),
    );
  });

  test('v1 migration preserves scans and rebuilds normalized FTS', () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp(
      'rosid-migration-test-',
    );
    final file = File('${directory.path}${Platform.pathSeparator}rosid.sqlite');
    try {
      final original = AppDatabase.forTesting(NativeDatabase(file));
      final scans = ScanRepository(original);
      await scans.createScan(
        id: 'legacy-scan',
        mode: ScanMode.document,
        imagePath: '/private/legacy.jpg',
        langHint: 'automatic',
        createdAt: DateTime(2026, 7, 17),
      );
      await scans.updateOcr(
        scanId: 'legacy-scan',
        rawText: 'পুরোনো নথি',
        engine: 'legacy',
        meanConfidence: 0.8,
      );
      await original.close();

      final raw = sqlite3.sqlite3.open(file.path);
      raw
        ..userVersion = 1
        ..execute('DELETE FROM scan_search');
      raw.close();

      final migrated = AppDatabase.forTesting(NativeDatabase(file));
      expect(await migrated.select(migrated.scans).get(), hasLength(1));
      expect(await migrated.searchScanIds('পুরোনো'), ['legacy-scan']);
      await migrated.close();
    } finally {
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  });

  test('normalizes indexed OCR and query while preserving raw text', () async {
    const rawDecomposed = 'ম\u09c7\u09beট ১০০';
    const composedQuery = 'মোট';
    final scans = ScanRepository(database);
    await scans.createScan(
      id: 'scan-1',
      mode: ScanMode.document,
      imagePath: '/private/scan-1.jpg',
      langHint: 'automatic',
      createdAt: DateTime(2026, 7, 17),
    );

    await scans.updateOcr(
      scanId: 'scan-1',
      rawText: rawDecomposed,
      engine: 'fake',
      meanConfidence: 1,
    );

    expect((await scans.getScan('scan-1')).ocrRawText, rawDecomposed);
    final indexed = await database
        .customSelect(
          'SELECT content FROM scan_search WHERE scan_id = ?',
          variables: const [Variable<String>('scan-1')],
        )
        .getSingle();
    expect(indexed.read<String>('content'), contains(composedQuery));
    expect(await database.searchScanIds(composedQuery), ['scan-1']);
    expect(await database.searchScanIds('ম\u09c7\u09beট'), ['scan-1']);
  });

  test('OCR row update rolls back when FTS indexing fails', () async {
    final scans = ScanRepository(database);
    await scans.createScan(
      id: 'scan-1',
      mode: ScanMode.document,
      imagePath: '/private/scan-1.jpg',
      langHint: 'automatic',
      createdAt: DateTime(2026, 7, 17),
    );
    await scans.updateOcr(
      scanId: 'scan-1',
      rawText: 'original text',
      engine: 'original-engine',
      meanConfidence: 0.75,
    );
    final before = await scans.getScan('scan-1');
    await database.customStatement('DROP TABLE scan_search');

    await expectLater(
      scans.updateOcr(
        scanId: 'scan-1',
        rawText: 'replacement text',
        engine: 'replacement-engine',
        meanConfidence: 0.25,
      ),
      throwsA(anything),
    );

    final after = await scans.getScan('scan-1');
    expect(after.ocrRawText, before.ocrRawText);
    expect(after.ocrEngine, before.ocrEngine);
    expect(after.ocrMeanConfidence, before.ocrMeanConfidence);
    expect(after.updatedAt, before.updatedAt);
  });

  test('scan deletion rolls back when FTS cleanup fails', () async {
    final scans = ScanRepository(database);
    await scans.createScan(
      id: 'scan-1',
      mode: ScanMode.document,
      imagePath: '/private/scan-1.jpg',
      langHint: 'automatic',
      createdAt: DateTime(2026, 7, 17),
    );
    await database.customStatement('DROP TABLE scan_search');

    await expectLater(scans.deleteScan('scan-1'), throwsA(anything));

    expect((await scans.getScan('scan-1')).id, 'scan-1');
    expect(await scans.getPages('scan-1'), hasLength(1));
  });
}
