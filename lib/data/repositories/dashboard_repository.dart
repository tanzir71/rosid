import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/database/database_provider.dart';
import 'package:rosid/data/repositories/history_repository.dart';

class DashboardSummary {
  const DashboardSummary({
    required this.total,
    required this.currency,
    required this.byCategory,
    required this.recent,
  });

  final double total;
  final String currency;
  final Map<String, double> byCategory;
  final List<HistoryEntry> recent;
}

class DashboardRepository {
  const DashboardRepository(this.database, this.historyRepository);

  final AppDatabase database;
  final HistoryRepository historyRepository;

  Future<DashboardSummary> monthly(
    DateTime month, {
    required String currency,
    required String languageCode,
  }) async {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final query =
        database.select(database.receipts).join([
            leftOuterJoin(
              database.categories,
              database.categories.id.equalsExp(database.receipts.categoryId),
            ),
          ])
          ..where(database.receipts.dateOfPurchase.isBiggerOrEqualValue(start))
          ..where(database.receipts.dateOfPurchase.isSmallerThanValue(end))
          ..where(database.receipts.currency.equals(currency));
    final rows = await query.get();
    final byCategory = <String, double>{};
    var total = 0.0;
    for (final row in rows) {
      final receipt = row.readTable(database.receipts);
      final category = row.readTableOrNull(database.categories);
      total += receipt.total;
      final name = category == null
          ? 'Other'
          : languageCode == 'bn'
          ? category.nameBn
          : category.nameEn;
      byCategory[name] = (byCategory[name] ?? 0) + receipt.total;
    }
    final recent = await historyRepository.list(
      const HistoryQuery(type: HistoryTypeFilter.receipt),
    );
    return DashboardSummary(
      total: total,
      currency: currency,
      byCategory: byCategory,
      recent: recent
          .where((entry) => entry.receipt?.currency == currency)
          .take(5)
          .toList(),
    );
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(
    ref.watch(databaseProvider),
    ref.watch(historyRepositoryProvider),
  ),
);

final dashboardSummaryProvider = FutureProvider<DashboardSummary>(
  (ref) => ref
      .watch(dashboardRepositoryProvider)
      .monthly(
        DateTime.now(),
        currency: ref.watch(appSettingsProvider).currency,
        languageCode: ref.watch(appSettingsProvider).languageCode,
      ),
);

final homeDocumentsProvider = FutureProvider<List<HistoryEntry>>((ref) async {
  final documents = await ref
      .watch(historyRepositoryProvider)
      .list(const HistoryQuery(type: HistoryTypeFilter.document));
  documents.sort((a, b) {
    final aPinned = a.document?.pinned ?? false;
    final bPinned = b.document?.pinned ?? false;
    if (aPinned != bPinned) return bPinned ? 1 : -1;
    return b.scan.updatedAt.compareTo(a.scan.updatedAt);
  });
  return documents;
});
