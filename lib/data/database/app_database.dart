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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'rosid'));

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createSearchIndex();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) await _rebuildSearchIndex();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await _createSearchIndex();
      await _seedCategories();
    },
  );

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
      await _writeSearchIndex(scan.id, [
        scan.ocrRawText,
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
