import 'package:rosid/parsing/normalizers/bangla_numerals.dart';
import 'package:rosid/parsing/normalizers/text_normalizer.dart';

class NormalizedDateMatch {
  const NormalizedDateMatch({required this.value, required this.rawText});

  final DateTime value;
  final String rawText;
}

abstract final class DateNormalizer {
  static const _months = <String, int>{
    'jan': 1,
    'january': 1,
    'জানুয়ারি': 1,
    'জানুয়ারি': 1,
    'feb': 2,
    'february': 2,
    'ফেব্রুয়ারি': 2,
    'ফেব্রুয়ারি': 2,
    'mar': 3,
    'march': 3,
    'মার্চ': 3,
    'apr': 4,
    'april': 4,
    'এপ্রিল': 4,
    'may': 5,
    'মে': 5,
    'jun': 6,
    'june': 6,
    'জুন': 6,
    'jul': 7,
    'july': 7,
    'জুলাই': 7,
    'aug': 8,
    'august': 8,
    'আগস্ট': 8,
    'sep': 9,
    'sept': 9,
    'september': 9,
    'সেপ্টেম্বর': 9,
    'oct': 10,
    'october': 10,
    'অক্টোবর': 10,
    'nov': 11,
    'november': 11,
    'নভেম্বর': 11,
    'dec': 12,
    'december': 12,
    'ডিসেম্বর': 12,
  };

  static NormalizedDateMatch? find(String input) {
    final original = TextNormalizer.normalize(input);
    final normalized = BanglaNumerals.toLatin(original);

    final ymd = RegExp(r'(?<!\d)(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})(?!\d)')
        .firstMatch(normalized);
    if (ymd != null) {
      final date = _valid(
        int.parse(ymd.group(1)!),
        int.parse(ymd.group(2)!),
        int.parse(ymd.group(3)!),
      );
      if (date != null) {
        return NormalizedDateMatch(
          value: date,
          rawText: original.substring(ymd.start, ymd.end),
        );
      }
    }

    final dmy = RegExp(r'(?<!\d)(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})(?!\d)')
        .firstMatch(normalized);
    if (dmy != null) {
      final year = _fourDigitYear(int.parse(dmy.group(3)!));
      final date = _valid(
        year,
        int.parse(dmy.group(2)!),
        int.parse(dmy.group(1)!),
      );
      if (date != null) {
        return NormalizedDateMatch(
          value: date,
          rawText: original.substring(dmy.start, dmy.end),
        );
      }
    }

    final names = _months.keys.map(RegExp.escape).join('|');
    final named = RegExp(
      '(?<!\\d)(\\d{1,2})\\s+($names)[,\\s]+(\\d{2,4})(?!\\d)',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (named != null) {
      final month = _months[named.group(2)!.toLowerCase()];
      final date = month == null
          ? null
          : _valid(
              _fourDigitYear(int.parse(named.group(3)!)),
              month,
              int.parse(named.group(1)!),
            );
      if (date != null) {
        return NormalizedDateMatch(
          value: date,
          rawText: original.substring(named.start, named.end),
        );
      }
    }
    return null;
  }

  static int _fourDigitYear(int year) => year < 70
      ? 2000 + year
      : year < 100
      ? 1900 + year
      : year;

  static DateTime? _valid(int year, int month, int day) {
    if (year < 2000 || year > 2100 || month < 1 || month > 12 || day < 1) {
      return null;
    }
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }
}
