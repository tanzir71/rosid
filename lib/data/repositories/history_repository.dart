import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/database/database_provider.dart';

enum HistoryTypeFilter { all, receipt, document }

class HistoryQuery {
  const HistoryQuery({
    this.text = '',
    this.type = HistoryTypeFilter.all,
    this.categoryId,
    this.start,
    this.end,
  });

  final String text;
  final HistoryTypeFilter type;
  final String? categoryId;
  final DateTime? start;
  final DateTime? end;

  HistoryQuery copyWith({
    String? text,
    HistoryTypeFilter? type,
    String? categoryId,
    bool clearCategory = false,
    DateTime? start,
    DateTime? end,
    bool clearDates = false,
  }) => HistoryQuery(
    text: text ?? this.text,
    type: type ?? this.type,
    categoryId: clearCategory ? null : categoryId ?? this.categoryId,
    start: clearDates ? null : start ?? this.start,
    end: clearDates ? null : end ?? this.end,
  );
}

class HistoryEntry {
  const HistoryEntry({
    required this.scan,
    this.receipt,
    this.document,
    this.category,
  });

  final Scan scan;
  final Receipt? receipt;
  final Document? document;
  final Category? category;

  bool get isReceipt => receipt != null;
  String get title => receipt?.merchant ?? document?.title ?? 'Unreviewed scan';
  String get body => document?.body ?? scan.ocrRawText;
}

class ScanDetail {
  const ScanDetail({
    required this.entry,
    required this.pages,
    required this.lineItems,
    required this.tags,
  });

  final HistoryEntry entry;
  final List<ScanPage> pages;
  final List<LineItem> lineItems;
  final List<Tag> tags;
}

class HistoryRepository {
  const HistoryRepository(this.database);

  final AppDatabase database;

  Future<List<HistoryEntry>> list(HistoryQuery filter) async {
    List<String>? searchIds;
    if (filter.text.trim().isNotEmpty) {
      final safeQuery = filter.text
          .trim()
          .split(RegExp(r'\s+'))
          .map((token) => '"${token.replaceAll('"', '')}"*')
          .join(' ');
      searchIds = await database.searchScanIds(safeQuery);
      if (searchIds.isEmpty) return [];
    }
    final query = database.select(database.scans).join([
      leftOuterJoin(
        database.receipts,
        database.receipts.scanId.equalsExp(database.scans.id),
      ),
      leftOuterJoin(
        database.documents,
        database.documents.scanId.equalsExp(database.scans.id),
      ),
      leftOuterJoin(
        database.categories,
        database.categories.id.equalsExp(database.receipts.categoryId),
      ),
    ]);
    if (searchIds != null) query.where(database.scans.id.isIn(searchIds));
    if (filter.type != HistoryTypeFilter.all) {
      query.where(database.scans.type.equals(filter.type.name));
    }
    if (filter.categoryId != null) {
      query.where(database.receipts.categoryId.equals(filter.categoryId!));
    }
    if (filter.start != null) {
      query.where(database.scans.createdAt.isBiggerOrEqualValue(filter.start!));
    }
    if (filter.end != null) {
      query.where(
        database.scans.createdAt.isSmallerThanValue(
          filter.end!.add(const Duration(days: 1)),
        ),
      );
    }
    query.orderBy([OrderingTerm.desc(database.scans.updatedAt)]);
    final rows = await query.get();
    return rows
        .map(
          (row) => HistoryEntry(
            scan: row.readTable(database.scans),
            receipt: row.readTableOrNull(database.receipts),
            document: row.readTableOrNull(database.documents),
            category: row.readTableOrNull(database.categories),
          ),
        )
        .toList();
  }

  Future<ScanDetail?> detail(String scanId) async {
    final entries = await list(const HistoryQuery());
    final matches = entries.where((entry) => entry.scan.id == scanId);
    if (matches.isEmpty) return null;
    final entry = matches.first;
    final pages =
        await (database.select(database.scanPages)
              ..where((row) => row.scanId.equals(scanId))
              ..orderBy([(row) => OrderingTerm.asc(row.pageIndex)]))
            .get();
    final items = entry.receipt == null
        ? const <LineItem>[]
        : await (database.select(
            database.lineItems,
          )..where((row) => row.receiptId.equals(entry.receipt!.id))).get();
    final tagQuery = database.select(database.tags).join([
      innerJoin(
        database.scanTags,
        database.scanTags.tagId.equalsExp(database.tags.id),
      ),
    ])..where(database.scanTags.scanId.equals(scanId));
    final tags = (await tagQuery.get())
        .map((row) => row.readTable(database.tags))
        .toList();
    return ScanDetail(entry: entry, pages: pages, lineItems: items, tags: tags);
  }

  Future<List<String>> delete(String scanId) async {
    final pages = await (database.select(
      database.scanPages,
    )..where((row) => row.scanId.equals(scanId))).get();
    await database.transaction(() async {
      await (database.delete(
        database.scans,
      )..where((row) => row.id.equals(scanId))).go();
      await database.customStatement(
        'DELETE FROM scan_search WHERE scan_id = ?',
        [scanId],
      );
    });
    return [
      for (final page in pages) ...[
        page.imagePath,
        if (page.processedPath != null) page.processedPath!,
      ],
    ];
  }

  Future<void> setPinned(String scanId, bool pinned) {
    return (database.update(database.documents)
          ..where((row) => row.scanId.equals(scanId)))
        .write(DocumentsCompanion(pinned: Value(pinned)));
  }

  Future<void> rename(String scanId, String value) async {
    final receipt = await (database.select(
      database.receipts,
    )..where((row) => row.scanId.equals(scanId))).getSingleOrNull();
    if (receipt != null) {
      await (database.update(database.receipts)
            ..where((row) => row.id.equals(receipt.id)))
          .write(ReceiptsCompanion(merchant: Value(value)));
    } else {
      await (database.update(database.documents)
            ..where((row) => row.scanId.equals(scanId)))
          .write(DocumentsCompanion(title: Value(value)));
    }
    final scan = await (database.select(
      database.scans,
    )..where((row) => row.id.equals(scanId))).getSingle();
    await database.indexScan(scanId: scanId, text: [scan.ocrRawText, value]);
  }
}

final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => HistoryRepository(ref.watch(databaseProvider)),
);
