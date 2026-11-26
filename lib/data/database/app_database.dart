import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:rosid/data/database/tables.dart';
import 'package:rosid/parsing/normalizers/text_normalizer.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Scans,
    ScanPages,
    Receipts,
    LineItems,
    Documents,
    Categories,
    Tags,
    ScanTags,
    TextLines,
    Details,
    Translations,
    Names,
    Terms,
    Corrections,
    Bundles,
    BundleItems,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'rosid'));

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createSearchIndex();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 3) {
        await _migrateToV3(migrator);
      }
      if (from < 2) {
        await _rebuildSearchIndex();
      } else if (from < 3) {
        await _rebuildSearchIndex();
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await _createSearchIndex();
      await _seedCategories();
    },
  );

  Future<void> _migrateToV3(Migrator migrator) async {
    final scanCols = await _existingColumns('scans');
    if (!scanCols.contains('kind')) {
      await migrator.addColumn(scans, scans.kind);
    }
    if (!scanCols.contains('language')) {
      await migrator.addColumn(scans, scans.language);
    }
    if (!scanCols.contains('check_count')) {
      await migrator.addColumn(scans, scans.checkCount);
    }
    if (!scanCols.contains('renew_by')) {
      await migrator.addColumn(scans, scans.renewBy);
    }

    final pageCols = await _existingColumns('scan_pages');
    if (!pageCols.contains('filter')) {
      await migrator.addColumn(scanPages, scanPages.filter);
    }
    if (!pageCols.contains('quad_json')) {
      await migrator.addColumn(scanPages, scanPages.quadJson);
    }
    if (!pageCols.contains('rotation')) {
      await migrator.addColumn(scanPages, scanPages.rotation);
    }
    if (!pageCols.contains('side')) {
      await migrator.addColumn(scanPages, scanPages.side);
    }

    // Backfill kind from existing v1/v2 `type` column.
    await customStatement(
      "UPDATE scans SET kind = CASE WHEN type = 'receipt' THEN 'receipt' ELSE 'document' END WHERE kind = 'document'",
    );

    final existingTables = await _existingTables();
    if (!existingTables.contains('text_lines')) {
      await migrator.createTable(textLines);
    }
    if (!existingTables.contains('details')) {
      await migrator.createTable(details);
    }
    if (!existingTables.contains('translations')) {
      await migrator.createTable(translations);
    }
    if (!existingTables.contains('names')) {
      await migrator.createTable(names);
    }
    if (!existingTables.contains('terms')) {
      await migrator.createTable(terms);
    }
    if (!existingTables.contains('corrections')) {
      await migrator.createTable(corrections);
    }
    if (!existingTables.contains('bundles')) {
      await migrator.createTable(bundles);
    }
    if (!existingTables.contains('bundle_items')) {
      await migrator.createTable(bundleItems);
    }
  }

  Future<Set<String>> _existingColumns(String tableName) async {
    final rows = await customSelect('PRAGMA table_info($tableName)').get();
    return rows.map((row) => row.read<String>('name')).toSet();
  }

  Future<Set<String>> _existingTables() async {
    final rows = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    ).get();
    return rows.map((row) => row.read<String>('name')).toSet();
  }

  Future<void> _createSearchIndex() => customStatement('''
    CREATE VIRTUAL TABLE IF NOT EXISTS scan_search USING fts5(
      scan_id UNINDEXED,
      content,
      tokenize = 'unicode61'
    )
  ''');

  Future<void> _rebuildSearchIndex() async {
    await customStatement('DROP TABLE IF EXISTS scan_search');
    await _createSearchIndex();
    final existingScans = await select(scans).get();
    for (final scan in existingScans) {
      final receipt = await (select(
        receipts,
      )..where((row) => row.scanId.equals(scan.id))).getSingleOrNull();
      final document = await (select(
        documents,
      )..where((row) => row.scanId.equals(scan.id))).getSingleOrNull();
      final tagQuery = select(tags).join([
        innerJoin(scanTags, scanTags.tagId.equalsExp(tags.id)),
      ])..where(scanTags.scanId.equals(scan.id));
      final tagNames = (await tagQuery.get())
          .map((row) => row.readTable(tags).name)
          .join(' ');
      final lineItemNames = receipt == null
          ? ''
          : (await (select(
                  lineItems,
                )..where((row) => row.receiptId.equals(receipt.id))).get())
                .map((item) => item.name)
                .join(' ');
      final translatedLines =
          (await (select(
                translations,
              )..where((row) => row.scanId.equals(scan.id))).get())
              .map((row) => row.englishText)
              .join('\n');
      final ocrLines =
          (await (select(
                textLines,
              )..where((row) => row.scanId.equals(scan.id))).get())
              .map((row) => row.textContent)
              .join('\n');
      await _writeSearchIndex(scan.id, [
        scan.ocrRawText,
        ocrLines,
        translatedLines,
        receipt?.merchant,
        receipt?.note,
        document?.title,
        document?.body,
        tagNames,
        lineItemNames,
      ]);
    }
  }

  Future<void> _seedCategories() async {
    const defaults = [
      ('groceries', 'Groceries', 'মুদি', 'shopping_basket'),
      ('food', 'Food', 'খাবার', 'restaurant'),
      ('transport', 'Transport', 'যাতায়াত', 'directions_bus'),
      ('utilities', 'Utilities', 'ইউটিলিটি', 'bolt'),
      ('health', 'Health', 'স্বাস্থ্য', 'health_and_safety'),
      ('shopping', 'Shopping', 'কেনাকাটা', 'shopping_bag'),
      ('other', 'Other', 'অন্যান্য', 'category'),
    ];
    await batch((batch) {
      for (final item in defaults) {
        batch.insert(
          categories,
          CategoriesCompanion.insert(
            id: item.$1,
            nameEn: item.$2,
            nameBn: item.$3,
            icon: item.$4,
            isDefault: const Value(true),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  Future<void> indexScan({
    required String scanId,
    required Iterable<String?> text,
  }) async {
    await transaction(() async {
      await customStatement('DELETE FROM scan_search WHERE scan_id = ?', [
        scanId,
      ]);
      await _writeSearchIndex(scanId, text);
    });
  }

  Future<void> _writeSearchIndex(String scanId, Iterable<String?> text) =>
      customStatement(
        'INSERT INTO scan_search(scan_id, content) VALUES (?, ?)',
        [
          scanId,
          text
              .whereType<String>()
              .map(TextNormalizer.normalize)
              .where((value) => value.isNotEmpty)
              .join('\n'),
        ],
      );

  Future<List<String>> searchScanIds(String query, {int? limit}) async {
    final normalized = TextNormalizer.normalize(query);
    if (normalized.isEmpty) return [];
    final sql = limit == null
        ? 'SELECT scan_id FROM scan_search WHERE scan_search MATCH ?'
        : 'SELECT scan_id FROM scan_search WHERE scan_search MATCH ? LIMIT ?';
    final rows = await customSelect(
      sql,
      variables: [
        Variable<String>(normalized),
        if (limit != null) Variable<int>(limit),
      ],
      readsFrom: {scans},
    ).get();
    return rows.map((row) => row.read<String>('scan_id')).toList();
  }
}
