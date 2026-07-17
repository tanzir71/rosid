import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/files/private_file_store.dart';
import 'package:rosid/data/repositories/export_repository.dart';
import 'package:rosid/features/export/export_service.dart';

class _FakeExportRepository implements ExportRepository {
  const _FakeExportRepository(this.rows);

  final List<ExpenseExportRow> rows;

  @override
  Future<List<ExpenseExportRow>> expenses(DateTime start, DateTime end) async =>
      rows;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const dangerousPrefixes = <String, String>{
    'equals': '=',
    'plus': '+',
    'minus': '-',
    'at sign': '@',
    'tab': '\t',
    'carriage return': '\r',
  };

  for (final prefix in dangerousPrefixes.entries) {
    test(
      'neutralizes the ${prefix.key} prefix in every textual cell',
      () async {
        final root = await Directory.systemTemp.createTemp('rosid_csv_');
        final fileStore = PrivateFileStore(rootDirectory: root);
        final value = '${prefix.value}spreadsheet-command';
        final service = ExportService(
          _FakeExportRepository([
            ExpenseExportRow(
              receipt: Receipt(
                id: 'receipt-1',
                scanId: 'scan-1',
                merchant: value,
                dateOfPurchase: DateTime(2026, 7, 17),
                total: -12.5,
                currency: value,
                tax: -1.25,
                paymentMethod: value,
                note: value,
                fieldConfidenceJson: '{}',
              ),
              category: Category(
                id: 'category-1',
                nameEn: value,
                nameBn: 'নিরাপদ',
                icon: 'tag',
                isDefault: false,
              ),
            ),
          ]),
          fileStore,
        );

        try {
          final path = await service.createExpenseCsv(
            DateTime(2026, 7, 1),
            DateTime(2026, 7, 31),
          );
          final bytes = await File(path).readAsBytes();
          expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
          final decoded = csv.decode(utf8.decode(bytes.sublist(3)));
          final values = decoded[1];

          for (final column in const [1, 2, 4, 6, 7]) {
            expect(values[column], "'$value", reason: 'column $column');
          }
          expect(values[0], '2026-07-17');
          expect(values[3], '-12.50');
          expect(values[5], '-1.25');
        } finally {
          if (await root.exists()) await root.delete(recursive: true);
        }
      },
    );
  }

  test('leaves ordinary textual cells unchanged', () {
    expect(sanitizeCsvTextCell('Dhaka Market'), 'Dhaka Market');
    expect(sanitizeCsvTextCell(''), '');
  });
}
