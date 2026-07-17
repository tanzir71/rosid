import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rosid/data/files/private_file_store.dart';
import 'package:rosid/data/repositories/export_repository.dart';

class ExportService {
  const ExportService(this.repository, this.fileStore);

  final ExportRepository repository;
  final PrivateFileStore fileStore;

  Future<String> createExpenseCsv(DateTime start, DateTime end) async {
    final expenses = await repository.expenses(start, end);
    final rows = <List<Object?>>[
      [
        'Date',
        'Merchant',
        'Category',
        'Total',
        'Currency',
        'Tax',
        'Payment',
        'Note',
      ],
      for (final row in expenses)
        [
          DateFormat('yyyy-MM-dd').format(row.receipt.dateOfPurchase),
          row.receipt.merchant,
          row.category?.nameEn ?? 'Other',
          row.receipt.total.toStringAsFixed(2),
          row.receipt.currency,
          row.receipt.tax?.toStringAsFixed(2) ?? '',
          row.receipt.paymentMethod ?? '',
          row.receipt.note ?? '',
        ],
    ];
    final path = await fileStore.createExportPath(
      'rosid_${DateFormat('yyyyMMdd').format(start)}_${DateFormat('yyyyMMdd').format(end)}.csv',
    );
    await File(path).writeAsString('\ufeff${csv.encode(rows)}', flush: true);
    return path;
  }
}

final exportServiceProvider = Provider<ExportService>(
  (ref) => ExportService(
    ref.watch(exportRepositoryProvider),
    ref.watch(privateFileStoreProvider),
  ),
);
