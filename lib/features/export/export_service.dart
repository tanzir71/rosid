import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rosid/data/files/private_file_store.dart';
import 'package:rosid/data/repositories/export_repository.dart';
import 'package:uuid/uuid.dart';

const _expenseCsvHeader = <Object?>[
  'Date',
  'Merchant',
  'Category',
  'Total',
  'Currency',
  'Tax',
  'Payment',
  'Note',
];

String sanitizeCsvTextCell(String value) {
  if (value.isEmpty) return value;
  return switch (value.codeUnitAt(0)) {
    0x3D || 0x2B || 0x2D || 0x40 || 0x09 || 0x0D => "'$value",
    _ => value,
  };
}

List<List<Object?>> expenseCsvRows(Iterable<ExpenseExportRow> expenses) => [
  _expenseCsvHeader,
  for (final row in expenses)
    [
      DateFormat('yyyy-MM-dd').format(row.receipt.dateOfPurchase),
      sanitizeCsvTextCell(row.receipt.merchant),
      sanitizeCsvTextCell(row.category?.nameEn ?? 'Other'),
      row.receipt.total.toStringAsFixed(2),
      sanitizeCsvTextCell(row.receipt.currency),
      row.receipt.tax?.toStringAsFixed(2) ?? '',
      sanitizeCsvTextCell(row.receipt.paymentMethod ?? ''),
      sanitizeCsvTextCell(row.receipt.note ?? ''),
    ],
];

class ExportService {
  const ExportService(this.repository, this.fileStore);

  final ExportRepository repository;
  final PrivateFileStore fileStore;

  Future<String> createExpenseCsv(DateTime start, DateTime end) async {
    final expenses = await repository.expenses(start, end);
    final rows = expenseCsvRows(expenses);
    final exportId = const Uuid().v7();
    final path = await fileStore.createExportPath(
      'rosid_${DateFormat('yyyyMMdd').format(start)}_'
      '${DateFormat('yyyyMMdd').format(end)}_$exportId.csv',
    );
    try {
      await File(path).writeAsString('\ufeff${csv.encode(rows)}', flush: true);
    } on Object {
      await fileStore.deleteExportIfPresent(path);
      rethrow;
    }
    return path;
  }
}

final exportServiceProvider = Provider<ExportService>(
  (ref) => ExportService(
    ref.watch(exportRepositoryProvider),
    ref.watch(privateFileStoreProvider),
  ),
);
