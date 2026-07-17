import 'package:rosid/parsing/normalizers/bangla_numerals.dart';

abstract final class CurrencyNormalizer {
  static final RegExp _currency = RegExp(
    r'(?:৳|\bBDT\b|\bTaka\b|\bTk\.?\b|টাকা)',
    caseSensitive: false,
  );
  static final RegExp _amount = RegExp(
    r'(?<!\d)-?(?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d{1,2})?(?!\d)',
  );

  static String normalizeTokens(String input) {
    return BanglaNumerals.toLatin(input).replaceAll(_currency, 'BDT');
  }

  static bool containsCurrency(String input) => _currency.hasMatch(input);

  static List<double> extractAmounts(String input) {
    final normalized = normalizeTokens(input);
    return _amount
        .allMatches(normalized)
        .map((match) => match.group(0)!.replaceAll(',', ''))
        .map(double.tryParse)
        .whereType<double>()
        .where((amount) => amount.abs() < 100000000)
        .toList();
  }
}
