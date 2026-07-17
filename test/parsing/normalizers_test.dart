import 'package:flutter_test/flutter_test.dart';
import 'package:rosid/parsing/normalizers/bangla_numerals.dart';
import 'package:rosid/parsing/normalizers/currency_normalizer.dart';
import 'package:rosid/parsing/normalizers/date_normalizer.dart';
import 'package:rosid/parsing/normalizers/text_normalizer.dart';

void main() {
  group('Bangla numerals', () {
    const cases = <String, String>{
      '০': '0',
      '১': '1',
      '২': '2',
      '৩': '3',
      '৪': '4',
      '৫': '5',
      '৬': '6',
      '৭': '7',
      '৮': '8',
      '৯': '9',
    };
    for (final entry in cases.entries) {
      test('maps ${entry.key} to ${entry.value}', () {
        expect(BanglaNumerals.toLatin(entry.key), entry.value);
      });
    }

    test('maps a complete Bangla amount', () {
      expect(BanglaNumerals.toLatin('৳ ১,২৫০.৫০'), '৳ 1,250.50');
    });

    test('parses a Bangla decimal amount', () {
      expect(BanglaNumerals.tryParse('৳ ১,২৫০.৫০'), 1250.5);
    });
  });

  group('Currency normalization', () {
    const tokens = ['৳', 'Tk', 'TK.', 'Taka', 'BDT', 'টাকা'];
    for (final token in tokens) {
      test('normalizes $token to BDT', () {
        expect(
          CurrencyNormalizer.normalizeTokens('$token 25'),
          contains('BDT'),
        );
      });
    }

    test('extracts comma-separated money', () {
      expect(CurrencyNormalizer.extractAmounts('Total 1,590.50'), [1590.5]);
    });

    test('extracts Bangla numeral money', () {
      expect(CurrencyNormalizer.extractAmounts('মোট ৳১,২৫০'), [1250]);
    });
  });

  group('Date normalization', () {
    final cases = <String, DateTime>{
      '15/07/2026': DateTime(2026, 7, 15),
      '15-07-26': DateTime(2026, 7, 15),
      '2026-07-15': DateTime(2026, 7, 15),
      '15.07.2026': DateTime(2026, 7, 15),
      '15 Jul 2026': DateTime(2026, 7, 15),
      '15 July 2026': DateTime(2026, 7, 15),
      '১৫/০৭/২০২৬': DateTime(2026, 7, 15),
      '১৫ জুলাই ২০২৬': DateTime(2026, 7, 15),
      '১ জানুয়ারি ২০২৬': DateTime(2026),
      '28 February 2026': DateTime(2026, 2, 28),
      '31 December 2026': DateTime(2026, 12, 31),
      '01-01-69': DateTime(2069),
    };
    for (final entry in cases.entries) {
      test('parses ${entry.key}', () {
        expect(DateNormalizer.find(entry.key)?.value, entry.value);
      });
    }

    test('rejects an impossible date', () {
      expect(DateNormalizer.find('31/02/2026'), isNull);
    });

    test('rejects an out-of-range year', () {
      expect(DateNormalizer.find('15/07/1999'), isNull);
    });
  });

  group('Text normalization', () {
    test('normalizes Unicode to NFC', () {
      expect(TextNormalizer.normalize('A\u030A'), 'Å');
    });

    test('collapses spacing but preserves lines', () {
      expect(TextNormalizer.normalize('a   b \n  c'), 'a b\nc');
    });
  });
}
