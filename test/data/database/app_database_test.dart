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

  test('v2 to v3 migration preserves receipts, documents, tags and creates v3 tables', () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp(
      'rosid-v2-to-v3-test-',
    );
    final file = File(
      '${directory.path}${Platform.pathSeparator}rosid_v2.sqlite',
    );
    try {
      // Build an authentic version-2 schema database fixture.
      final raw = sqlite3.sqlite3.open(file.path);
      raw
        ..execute('''
          CREATE TABLE scans (
            id TEXT NOT NULL PRIMARY KEY,
            type TEXT NOT NULL,
            image_path TEXT NOT NULL,
            thumb_path TEXT,
            ocr_raw_text TEXT NOT NULL DEFAULT '',
            ocr_engine TEXT,
            ocr_mean_confidence REAL,
            lang_hint TEXT NOT NULL DEFAULT 'auto',
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          );
          CREATE TABLE scan_pages (
            id TEXT NOT NULL PRIMARY KEY,
            scan_id TEXT NOT NULL REFERENCES scans(id) ON DELETE CASCADE,
            image_path TEXT NOT NULL,
            processed_path TEXT,
            page_index INTEGER NOT NULL
          );
          CREATE TABLE categories (
            id TEXT NOT NULL PRIMARY KEY,
            name_en TEXT NOT NULL,
            name_bn TEXT NOT NULL,
            icon TEXT NOT NULL,
            is_default INTEGER NOT NULL DEFAULT 0
          );
          CREATE TABLE receipts (
            id TEXT NOT NULL PRIMARY KEY,
            scan_id TEXT NOT NULL REFERENCES scans(id) ON DELETE CASCADE,
            merchant TEXT NOT NULL,
            date_of_purchase INTEGER NOT NULL,
            total REAL NOT NULL,
            currency TEXT NOT NULL DEFAULT 'BDT',
            tax REAL,
            payment_method TEXT,
            category_id TEXT REFERENCES categories(id) ON DELETE SET NULL,
            note TEXT,
            field_confidence_json TEXT NOT NULL DEFAULT '{}'
          );
          CREATE TABLE line_items (
            id TEXT NOT NULL PRIMARY KEY,
            receipt_id TEXT NOT NULL REFERENCES receipts(id) ON DELETE CASCADE,
            name TEXT NOT NULL,
            qty REAL NOT NULL DEFAULT 1,
            unit_price REAL,
            amount REAL NOT NULL
          );
          CREATE TABLE documents (
            id TEXT NOT NULL PRIMARY KEY,
            scan_id TEXT NOT NULL REFERENCES scans(id) ON DELETE CASCADE,
            title TEXT NOT NULL,
            body TEXT NOT NULL DEFAULT '',
            pinned INTEGER NOT NULL DEFAULT 0
          );
          CREATE TABLE tags (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL UNIQUE
          );
          CREATE TABLE scan_tags (
            scan_id TEXT NOT NULL REFERENCES scans(id) ON DELETE CASCADE,
            tag_id TEXT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
            PRIMARY KEY (scan_id, tag_id)
          );
        ''')
        ..execute(
          "INSERT INTO categories VALUES ('groceries','Groceries','মুদি','shopping_basket',1)",
        )
        ..execute(
          "INSERT INTO scans VALUES ('scan-rec','receipt','/p/r.jpg',NULL,'Shwapno 500','mlkit',0.9,'auto',1752710400,1752710400)",
        )
        ..execute(
          "INSERT INTO scan_pages VALUES ('p-rec','scan-rec','/p/r.jpg',NULL,0)",
        )
        ..execute(
          "INSERT INTO receipts VALUES ('rec-1','scan-rec','Shwapno',1752710400,500.0,'BDT',25.0,'Cash','groceries',NULL,'{}')",
        )
        ..execute(
          "INSERT INTO line_items VALUES ('li-1','rec-1','Rice',2.0,250.0,500.0)",
        )
        ..execute(
          "INSERT INTO scans VALUES ('scan-doc','document','/p/d.jpg',NULL,'খতিয়ান নং ১২৪৫','tess',0.8,'bn',1752710400,1752710400)",
        )
        ..execute(
          "INSERT INTO scan_pages VALUES ('p-doc','scan-doc','/p/d.jpg',NULL,0)",
        )
        ..execute(
          "INSERT INTO documents VALUES ('doc-1','scan-doc','খতিয়ান, বিরুলিয়া','খতিয়ান নং ১২৪৫',1)",
        )
        ..execute("INSERT INTO tags VALUES ('tag-1','land')")
        ..execute("INSERT INTO scan_tags VALUES ('scan-doc','tag-1')")
        ..userVersion = 2;
      raw.close();

      final migrated = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final allScans = await migrated.select(migrated.scans).get();
        expect(allScans, hasLength(2));
        final recScan = allScans.firstWhere((s) => s.id == 'scan-rec');
        final docScan = allScans.firstWhere((s) => s.id == 'scan-doc');
        expect(recScan.kind, 'receipt');
        expect(docScan.kind, 'document');
        expect(docScan.checkCount, 0);

        expect(await migrated.select(migrated.receipts).get(), hasLength(1));
        expect(await migrated.select(migrated.documents).get(), hasLength(1));
        expect(await migrated.select(migrated.tags).get(), hasLength(1));
        expect(await migrated.select(migrated.scanTags).get(), hasLength(1));

        // Verify all 8 new v3 tables are writable and queryable.
        expect(await migrated.select(migrated.textLines).get(), isEmpty);
        expect(await migrated.select(migrated.details).get(), isEmpty);
        expect(await migrated.select(migrated.translations).get(), isEmpty);
        expect(await migrated.select(migrated.names).get(), isEmpty);
        expect(await migrated.select(migrated.terms).get(), isEmpty);
        expect(await migrated.select(migrated.corrections).get(), isEmpty);
        expect(await migrated.select(migrated.bundles).get(), isEmpty);
        expect(await migrated.select(migrated.bundleItems).get(), isEmpty);

        // Verify FTS search rebuilt across migrated rows.
        expect(await migrated.searchScanIds('Shwapno'), ['scan-rec']);
        expect(await migrated.searchScanIds('খতিয়ান'), ['scan-doc']);
      } finally {
        await migrated.close();
      }
    } finally {
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  });
}
