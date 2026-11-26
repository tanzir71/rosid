import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rosid/parsing/models/parsed_receipt.dart';
import 'package:rosid/parsing/receipt_parser.dart';

void main() {
  const parser = ReceiptParser();
  final fixtureDirectory = Directory('test/fixtures/receipts');
  final fixtureFiles =
      fixtureDirectory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.txt'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  group('fixture corpus', () {
    for (final fixture in fixtureFiles) {
      final name = fixture.uri.pathSegments.last.replaceAll('.txt', '');
      test('parses $name', () {
        final expectationFile = File(fixture.path.replaceAll('.txt', '.json'));
        final expectation = jsonDecode(
          expectationFile.readAsStringSync(),
        ) as Map<String, dynamic>;
        final result = parser.parse(
          fixture.readAsStringSync(),
          scanTime: DateTime(2026, 7, 17),
        );

        expect(result.merchant.value, expectation['merchant']);
        expect(
          result.total.value,
          closeTo((expectation['total'] as num).toDouble(), 0.01),
        );
        final expectedDate = expectation['date'] as String?;
        if (expectedDate == null) {
          expect(result.date.source, ParsedSource.inferred);
        } else {
          expect(result.date.value, DateTime.parse(expectedDate));
        }
      });
    }
  });

  group('field heuristics', () {
    test('extracts tax', () {
      final result = parser.parse('Shop\nVAT 25.50\nTotal 125.50');
      expect(result.tax.value, 25.5);
      expect(result.tax.source, ParsedSource.keyword);
    });

    test('extracts card payment', () {
      expect(
        parser.parse('Shop\nTotal 100\nVISA CARD').paymentMethod.value,
        'Card',
      );
    });

    test('extracts bKash payment from Bangla', () {
      expect(
        parser.parse('দোকান\nমোট ১০০\nবিকাশ').paymentMethod.value,
        'bKash',
      );
    });

    test('infers grocery category', () {
      expect(
        parser.parse('Shwapno Supermarket\nTotal 100').categoryId.value,
        'groceries',
      );
    });

    test('parses quantity and unit price', () {
      final item = parser
          .parse('Shop\nRice 2 x 50 100\nTotal 100')
          .lineItems
          .single;
      expect(item.name, 'Rice');
      expect(item.quantity, 2);
      expect(item.unitPrice, 50);
      expect(item.amount, 100);
    });

    test('uses largest plausible amount as fallback', () {
      final total = parser.parse('Shop\nTea 20\nCoffee 80').total;
      expect(total.value, 80);
      expect(total.source, ParsedSource.fallback);
    });

    test('returns null when no amount exists', () {
      expect(parser.parse('Shop\nThank you').total.value, isNull);
    });

    test('falls back to scan timestamp when date is missing', () {
      final scanned = DateTime(2026, 7, 17, 12, 30);
      final date = parser.parse('Shop\nTotal 10', scanTime: scanned).date;
      expect(date.value, scanned);
      expect(date.confidence, lessThan(0.5));
    });

    test('prefers grand total over subtotal', () {
      expect(
        parser.parse('Shop\nSubtotal 800\nVAT 80\nGrand Total 880').total.value,
        880,
      );
    });

    test('flags keyword total with strong confidence', () {
      expect(
        parser.parse('Shop\nGrand Total 880').total.confidence,
        greaterThan(0.9),
      );
    });
  });
}
