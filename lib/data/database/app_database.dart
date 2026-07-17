import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:rosid/data/database/tables.dart';

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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createSearchIndex();
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
      await customStatement(
        'INSERT INTO scan_search(scan_id, content) VALUES (?, ?)',
        [scanId, text.whereType<String>().join('\n')],
      );
    });
  }

  Future<List<String>> searchScanIds(String query, {int limit = 100}) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return [];
    final rows = await customSelect(
      'SELECT scan_id FROM scan_search WHERE scan_search MATCH ? LIMIT ?',
      variables: [Variable<String>(normalized), Variable<int>(limit)],
      readsFrom: {scans},
    ).get();
    return rows.map((row) => row.read<String>('scan_id')).toList();
  }
}
