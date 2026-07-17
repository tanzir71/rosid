import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/database/database_provider.dart';

class ExpenseExportRow {
  const ExpenseExportRow({required this.receipt, this.category});

  final Receipt receipt;
  final Category? category;
}

class ExportRepository {
  const ExportRepository(this.database);

  final AppDatabase database;

  Future<List<ExpenseExportRow>> expenses(DateTime start, DateTime end) async {
    final query =
        database.select(database.receipts).join([
            leftOuterJoin(
              database.categories,
              database.categories.id.equalsExp(database.receipts.categoryId),
            ),
          ])
          ..where(database.receipts.dateOfPurchase.isBiggerOrEqualValue(start))
          ..where(
            database.receipts.dateOfPurchase.isSmallerThanValue(
              end.add(const Duration(days: 1)),
            ),
          )
          ..orderBy([OrderingTerm.asc(database.receipts.dateOfPurchase)]);
    return (await query.get())
        .map(
          (row) => ExpenseExportRow(
            receipt: row.readTable(database.receipts),
            category: row.readTableOrNull(database.categories),
          ),
        )
        .toList();
  }
}

final exportRepositoryProvider = Provider<ExportRepository>(
  (ref) => ExportRepository(ref.watch(databaseProvider)),
);
