import 'dart:io';

import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/database/database_provider.dart';
import 'package:rosid/data/files/private_file_store.dart';
import 'package:rosid/data/repositories/record_repository.dart';
import 'package:rosid/parsing/models/parsed_receipt.dart';

/// Pure check for whether receipt item amounts add up to the total (either
/// directly or with VAT/tax added).
class ReceiptItemsSumCheck {
  const ReceiptItemsSumCheck({
    required this.itemCount,
    required this.itemsSum,
    required this.matchesTotal,
  });

  final int itemCount;
  final double itemsSum;
  final bool matchesTotal;
}

ReceiptItemsSumCheck evaluateReceiptItemsSum({
  required double total,
  required List<double> itemAmounts,
  double? tax,
}) {
  final sum = itemAmounts.fold<double>(0, (acc, v) => acc + v);
  if (itemAmounts.isEmpty) {
    return const ReceiptItemsSumCheck(
      itemCount: 0,
      itemsSum: 0,
      matchesTotal: true,
    );
  }
  final directMatch = (sum - total).abs() <= 0.05;
  final taxMatch =
      tax != null && tax > 0 && ((sum + tax) - total).abs() <= 0.05;
  return ReceiptItemsSumCheck(
    itemCount: itemAmounts.length,
    itemsSum: sum,
    matchesTotal: directMatch || taxMatch,
  );
}

class CategorySpendRow {
  const CategorySpendRow({
    required this.categoryId,
    required this.name,
    required this.amount,
    required this.fractionOfMax,
  });

  final String categoryId;
  final String name;
  final double amount;
  final double fractionOfMax;
}

class ExpenseReceiptRow {
  const ExpenseReceiptRow({
    required this.receipt,
    required this.scan,
    required this.categoryName,
    required this.items,
  });

  final Receipt receipt;
  final Scan scan;
  final String categoryName;
  final List<LineItem> items;
}

class MonthlyExpensesView {
  const MonthlyExpensesView({
    required this.month,
    required this.total,
    required this.previousMonthTotal,
    required this.currency,
    required this.categories,
    required this.receipts,
  });

  final DateTime month;
  final double total;
  final double previousMonthTotal;
  final String currency;
  final List<CategorySpendRow> categories;
  final List<ExpenseReceiptRow> receipts;

  double get deltaFromPrevious => total - previousMonthTotal;
}

class ReceiptCheckView {
  const ReceiptCheckView({
    required this.scan,
    required this.receipt,
    required this.items,
    required this.pages,
    required this.lines,
    required this.categories,
    required this.sourceLineByField,
  });

  final Scan scan;
  final Receipt receipt;
  final List<LineItem> items;
  final List<ScanPage> pages;
  final List<TextLine> lines;
  final List<Category> categories;

  /// Maps field keys (`total`, `shop`, `date`, `vat`) to their OCR `TextLine`
  /// so tapping a field highlights where it was read on the receipt.
  final Map<String, TextLine> sourceLineByField;
}

/// Builds a monthly expenses CSV string with Shop, Date, Category, Total, VAT,
/// Payment method, Currency, Items, and Note.
String buildExpensesCsv(List<ExpenseReceiptRow> rows) {
  final table = <List<dynamic>>[
    const [
      'Date',
      'Shop',
      'Category',
      'Total',
      'VAT',
      'Paid with',
      'Currency',
      'Items',
      'Note',
    ],
    for (final row in rows)
      [
        DateFormat('yyyy-MM-dd').format(row.receipt.dateOfPurchase),
        row.receipt.merchant,
        row.categoryName,
        row.receipt.total.toStringAsFixed(2),
        row.receipt.tax == null ? '' : row.receipt.tax!.toStringAsFixed(2),
        row.receipt.paymentMethod ?? '',
        row.receipt.currency,
        row.items.map((i) => i.name).join('; '),
        row.receipt.note ?? '',
      ],
  ];
  return const CsvEncoder().convert(table);
}

class ExpensesRepository {
  const ExpensesRepository(this.db, this.records, this.fileStore);

  final AppDatabase db;
  final RecordRepository records;
  final PrivateFileStore fileStore;

  Future<MonthlyExpensesView> loadMonth(
    DateTime month, {
    required String languageCode,
    String currency = 'BDT',
  }) async {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final prevStart = DateTime(month.year, month.month - 1);

    final cats = await db.select(db.categories).get();
    final catMap = {for (final c in cats) c.id: c};

    final query =
        db.select(db.receipts).join([
            innerJoin(db.scans, db.scans.id.equalsExp(db.receipts.scanId)),
          ])
          ..where(db.receipts.dateOfPurchase.isBiggerOrEqualValue(start))
          ..where(db.receipts.dateOfPurchase.isSmallerThanValue(end))
          ..orderBy([OrderingTerm.desc(db.receipts.dateOfPurchase)]);

    final joined = await query.get();
    final byCatId = <String, double>{};
    final rows = <ExpenseReceiptRow>[];
    var total = 0.0;

    for (final j in joined) {
      final receipt = j.readTable(db.receipts);
      final scan = j.readTable(db.scans);
      final cat = receipt.categoryId == null
          ? null
          : catMap[receipt.categoryId!];
      final catId = cat?.id ?? 'cat_other';
      final catName = cat == null
          ? (languageCode == 'bn' ? 'অন্যান্য' : 'Other')
          : (languageCode == 'bn' ? cat.nameBn : cat.nameEn);
      final items = await (db.select(
        db.lineItems,
      )..where((l) => l.receiptId.equals(receipt.id))).get();

      total += receipt.total;
      byCatId[catId] = (byCatId[catId] ?? 0) + receipt.total;
      rows.add(
        ExpenseReceiptRow(
          receipt: receipt,
          scan: scan,
          categoryName: catName,
          items: items,
        ),
      );
    }

    final prevRows =
        await (db.select(db.receipts)
              ..where((r) => r.dateOfPurchase.isBiggerOrEqualValue(prevStart))
              ..where((r) => r.dateOfPurchase.isSmallerThanValue(start)))
            .get();
    final prevTotal = prevRows.fold<double>(0, (acc, r) => acc + r.total);

    final sortedCats = byCatId.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxAmount = sortedCats.isEmpty ? 1.0 : sortedCats.first.value;
    final categorySpend = <CategorySpendRow>[
      for (final e in sortedCats)
        CategorySpendRow(
          categoryId: e.key,
          name: () {
            final c = catMap[e.key];
            if (c == null) return languageCode == 'bn' ? 'অন্যান্য' : 'Other';
            return languageCode == 'bn' ? c.nameBn : c.nameEn;
          }(),
          amount: e.value,
          fractionOfMax: maxAmount <= 0
              ? 0.0
              : (e.value / maxAmount).clamp(0.05, 1.0),
        ),
    ];

    return MonthlyExpensesView(
      month: start,
      total: total,
      previousMonthTotal: prevTotal,
      currency: currency,
      categories: categorySpend,
      receipts: rows,
    );
  }

  Future<ReceiptCheckView?> loadReceiptForCheck(String scanId) async {
    final scan = await (db.select(
      db.scans,
    )..where((s) => s.id.equals(scanId))).getSingleOrNull();
    if (scan == null) return null;

    var receipt = await (db.select(
      db.receipts,
    )..where((r) => r.scanId.equals(scanId))).getSingleOrNull();

    if (receipt == null) {
      // Create an initial receipt record from scan metadata if user opened Check receipt.
      await records.saveReceipt(
        scanId: scanId,
        merchant: 'Receipt',
        date: scan.createdAt,
        total: 0,
        currency: 'BDT',
        categoryId: 'cat_other',
        items: const [],
        fieldConfidence: const {},
      );
      receipt = await (db.select(
        db.receipts,
      )..where((r) => r.scanId.equals(scanId))).getSingle();
    }

    final items = await (db.select(
      db.lineItems,
    )..where((l) => l.receiptId.equals(receipt!.id))).get();
    final pages =
        await (db.select(db.scanPages)
              ..where((p) => p.scanId.equals(scanId))
              ..orderBy([(p) => OrderingTerm.asc(p.pageIndex)]))
            .get();
    final lines =
        await (db.select(db.textLines)
              ..where((t) => t.scanId.equals(scanId))
              ..orderBy([
                (t) => OrderingTerm.asc(t.pageIndex),
                (t) => OrderingTerm.asc(t.lineOrder),
              ]))
            .get();
    final details = await (db.select(
      db.details,
    )..where((d) => d.scanId.equals(scanId))).get();
    final categories = await (db.select(
      db.categories,
    )..orderBy([(c) => OrderingTerm.asc(c.nameEn)])).get();

    final linesById = {for (final l in lines) l.id: l};
    final sourceMap = <String, TextLine>{};
    for (final d in details) {
      final line = d.sourceLineId == null ? null : linesById[d.sourceLineId!];
      if (line == null) continue;
      final key = d.detailKey.toLowerCase();
      if (key == 'total' || key == 'receipt_total') {
        sourceMap['total'] = line;
      } else if (key == 'shop' || key == 'merchant') {
        sourceMap['shop'] = line;
      } else if (key == 'date') {
        sourceMap['date'] = line;
      } else if (key == 'vat' || key == 'tax') {
        sourceMap['vat'] = line;
      }
    }

    // Fallback heuristic matching on textLines if details didn't capture a box.
    if (!sourceMap.containsKey('shop') && lines.isNotEmpty) {
      sourceMap['shop'] = lines.first;
    }
    if (!sourceMap.containsKey('total') && lines.isNotEmpty) {
      for (final l in lines.reversed) {
        if (RegExp(
              r'total|মোট|সর্বমোট',
              caseSensitive: false,
            ).hasMatch(l.textContent) &&
            !RegExp(r'sub', caseSensitive: false).hasMatch(l.textContent)) {
          sourceMap['total'] = l;
          break;
        }
      }
      sourceMap.putIfAbsent('total', () => lines.last);
    }
    if (!sourceMap.containsKey('vat')) {
      for (final l in lines) {
        if (RegExp(
          r'vat|tax|ভ্যাট|মূসক',
          caseSensitive: false,
        ).hasMatch(l.textContent)) {
          sourceMap['vat'] = l;
          break;
        }
      }
    }
    if (!sourceMap.containsKey('date')) {
      for (final l in lines) {
        if (RegExp(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|20\d{2}')
            .hasMatch(l.textContent)) {
          sourceMap['date'] = l;
          break;
        }
      }
    }

    return ReceiptCheckView(
      scan: scan,
      receipt: receipt,
      items: items,
      pages: pages,
      lines: lines,
      categories: categories,
      sourceLineByField: sourceMap,
    );
  }

  Future<void> saveCheckedReceipt({
    required String scanId,
    required String merchant,
    required DateTime date,
    required double total,
    required String categoryId,
    required List<ParsedLineItem> items,
    double? tax,
    String? paymentMethod,
    String? note,
  }) async {
    await records.saveReceipt(
      scanId: scanId,
      merchant: merchant.trim().isEmpty ? 'Receipt' : merchant.trim(),
      date: date,
      total: total,
      currency: 'BDT',
      categoryId: categoryId,
      items: items,
      fieldConfidence: const {'merchant': 1.0, 'date': 1.0, 'total': 1.0},
      tax: tax,
      paymentMethod: paymentMethod,
      note: note,
    );
    await (db.update(db.scans)..where((s) => s.id.equals(scanId))).write(
      ScansCompanion(
        type: const Value('receipt'),
        kind: const Value('receipt'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<({String filePath, String fileName, String csvContent})>
  writeMonthCsvExport(DateTime month, {required String languageCode}) async {
    final view = await loadMonth(month, languageCode: languageCode);
    final csvContent = buildExpensesCsv(view.receipts);
    final slug = DateFormat('yyyy-MM').format(view.month);
    final fileName = 'Rosid-Expenses-$slug.csv';
    final filePath = await fileStore.createExportPath(fileName);
    await File(filePath).writeAsString(csvContent, flush: true);
    return (filePath: filePath, fileName: fileName, csvContent: csvContent);
  }
}

final expensesRepositoryProvider = Provider<ExpensesRepository>(
  (ref) => ExpensesRepository(
    ref.watch(databaseProvider),
    ref.watch(recordRepositoryProvider),
    ref.watch(privateFileStoreProvider),
  ),
);

class SelectedExpenseMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void select(DateTime month) {
    state = DateTime(month.year, month.month);
  }

  void previousMonth() {
    state = DateTime(state.year, state.month - 1);
  }

  void nextMonth() {
    state = DateTime(state.year, state.month + 1);
  }
}

final selectedExpenseMonthProvider =
    NotifierProvider<SelectedExpenseMonthNotifier, DateTime>(
      SelectedExpenseMonthNotifier.new,
    );

final monthlyExpensesProvider = FutureProvider<MonthlyExpensesView>((ref) {
  final month = ref.watch(selectedExpenseMonthProvider);
  final settings = ref.watch(appSettingsProvider);
  return ref
      .watch(expensesRepositoryProvider)
      .loadMonth(
        month,
        languageCode: settings.languageCode,
        currency: settings.currency,
      );
});

final receiptCheckProvider = FutureProvider.family<ReceiptCheckView?, String>(
  (ref, scanId) =>
      ref.watch(expensesRepositoryProvider).loadReceiptForCheck(scanId),
);
