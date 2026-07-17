import 'package:rosid/parsing/models/parsed_receipt.dart';
import 'package:rosid/parsing/normalizers/currency_normalizer.dart';
import 'package:rosid/parsing/normalizers/date_normalizer.dart';
import 'package:rosid/parsing/normalizers/text_normalizer.dart';

class ReceiptParser {
  const ReceiptParser();

  static final RegExp _totalKeyword = RegExp(
    r'\bgrand\s*total\b|\bnet\s*(?:total|amount)\b|\btotal\b|সর্বমোট|মোট|টোটাল',
    caseSensitive: false,
  );
  static final RegExp _weakTotal = RegExp(
    r'\bsub\s*total\b|উপমোট|discount|ছাড়|ছাড়',
    caseSensitive: false,
  );
  static final RegExp _taxKeyword = RegExp(
    r'\bvat\b|\btax\b|মূসক|ভ্যাট|কর',
    caseSensitive: false,
  );

  ParsedReceipt parse(String ocrText, {DateTime? scanTime}) {
    final raw = TextNormalizer.normalize(ocrText);
    final lines = raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final items = _lineItems(lines);
    final total = _total(lines, items);
    final dateMatch = DateNormalizer.find(raw);
    final date = dateMatch == null
        ? ParsedField<DateTime>(
            value: scanTime ?? DateTime.now(),
            rawText: '',
            confidence: 0.3,
            source: ParsedSource.inferred,
          )
        : ParsedField<DateTime>(
            value: dateMatch.value,
            rawText: dateMatch.rawText,
            confidence: 0.93,
            source: ParsedSource.pattern,
          );
    final merchant = _merchant(lines);
    return ParsedReceipt(
      merchant: merchant,
      date: date,
      total: total,
      tax: _tax(lines),
      paymentMethod: _paymentMethod(lines),
      categoryId: _category(lines, merchant.value),
      lineItems: items,
      rawText: raw,
    );
  }

  ParsedField<double?> _total(List<String> lines, List<ParsedLineItem> items) {
    for (var index = lines.length - 1; index >= 0; index--) {
      final line = lines[index];
      if (!_totalKeyword.hasMatch(line) || _weakTotal.hasMatch(line)) continue;
      final sameLine = CurrencyNormalizer.extractAmounts(line);
      final adjacent = index + 1 < lines.length
          ? CurrencyNormalizer.extractAmounts(lines[index + 1])
          : const <double>[];
      final amounts = sameLine.isNotEmpty ? sameLine : adjacent;
      if (amounts.isEmpty) continue;
      final value = amounts.last.abs();
      var confidence = 0.93;
      var source = ParsedSource.keyword;
      final itemSum = items.fold<double>(0, (sum, item) => sum + item.amount);
      if (itemSum > 0 &&
          (itemSum - value).abs() / value.clamp(1, double.infinity) < 0.03) {
        confidence = 0.98;
        source = ParsedSource.lineItemSum;
      }
      return ParsedField<double?>(
        value: value,
        rawText: sameLine.isNotEmpty
            ? line
            : '${lines[index]}\n${lines[index + 1]}',
        confidence: confidence,
        source: source,
      );
    }

    final candidates = <(double, String)>[];
    for (final line in lines) {
      if (DateNormalizer.find(line) != null || _taxKeyword.hasMatch(line)) {
        continue;
      }
      for (final amount in CurrencyNormalizer.extractAmounts(line)) {
        if (amount >= 1900 && amount <= 2100 && amount % 1 == 0) {
          continue;
        }
        if (amount > 0) {
          candidates.add((amount, line));
        }
      }
    }
    candidates.sort((a, b) => b.$1.compareTo(a.$1));
    if (candidates.isNotEmpty) {
      return ParsedField<double?>(
        value: candidates.first.$1,
        rawText: candidates.first.$2,
        confidence: 0.44,
        source: ParsedSource.fallback,
      );
    }
    return const ParsedField<double?>(
      value: null,
      rawText: '',
      confidence: 0,
      source: ParsedSource.fallback,
    );
  }

  ParsedField<String> _merchant(List<String> lines) {
    final candidates = lines.take(4).where((line) {
      if (_totalKeyword.hasMatch(line) ||
          _taxKeyword.hasMatch(line) ||
          DateNormalizer.find(line) != null) {
        return false;
      }
      final digits = RegExp(r'[0-9০-৯]').allMatches(line).length;
      return line.length >= 2 && digits / line.length < 0.5;
    }).toList();
    final value = candidates.isEmpty ? 'Unknown merchant' : candidates.first;
    return ParsedField<String>(
      value: value,
      rawText: candidates.isEmpty ? '' : candidates.first,
      confidence: candidates.isEmpty ? 0.15 : 0.72,
      source: candidates.isEmpty ? ParsedSource.fallback : ParsedSource.pattern,
    );
  }

  ParsedField<double?> _tax(List<String> lines) {
    for (final line in lines.reversed) {
      if (!_taxKeyword.hasMatch(line)) continue;
      final amounts = CurrencyNormalizer.extractAmounts(line);
      if (amounts.isNotEmpty) {
        return ParsedField<double?>(
          value: amounts.last.abs(),
          rawText: line,
          confidence: 0.88,
          source: ParsedSource.keyword,
        );
      }
    }
    return const ParsedField<double?>(
      value: null,
      rawText: '',
      confidence: 0,
      source: ParsedSource.fallback,
    );
  }

  ParsedField<String?> _paymentMethod(List<String> lines) {
    const methods = <String, String>{
      'cash': 'Cash',
      'নগদ টাকা': 'Cash',
      'card': 'Card',
      'visa': 'Card',
      'mastercard': 'Card',
      'bkash': 'bKash',
      'বিকাশ': 'bKash',
      'nagad': 'Nagad',
    };
    for (final line in lines) {
      final lower = line.toLowerCase();
      for (final entry in methods.entries) {
        if (lower.contains(entry.key.toLowerCase())) {
          return ParsedField<String?>(
            value: entry.value,
            rawText: line,
            confidence: 0.9,
            source: ParsedSource.keyword,
          );
        }
      }
    }
    return const ParsedField<String?>(
      value: null,
      rawText: '',
      confidence: 0,
      source: ParsedSource.fallback,
    );
  }

  ParsedField<String?> _category(List<String> lines, String merchant) {
    final text = '$merchant ${lines.join(' ')}'.toLowerCase();
    const rules = <String, List<String>>{
      'groceries': [
        'grocery',
        'supermarket',
        'মুদি',
        'shwapno',
        'agora',
        'meena',
      ],
      'food': ['restaurant', 'cafe', 'pizza', 'খাবার', 'biryani'],
      'transport': ['uber', 'pathao', 'bus', 'train', 'যাতায়াত'],
      'utilities': ['electricity', 'internet', 'gas bill', 'বিদ্যুৎ'],
      'health': ['pharmacy', 'hospital', 'medicine', 'ফার্মেসি'],
      'shopping': ['fashion', 'clothing', 'shopping'],
    };
    for (final entry in rules.entries) {
      if (entry.value.any(text.contains)) {
        return ParsedField<String?>(
          value: entry.key,
          rawText: merchant,
          confidence: 0.65,
          source: ParsedSource.keyword,
        );
      }
    }
    return const ParsedField<String?>(
      value: 'other',
      rawText: '',
      confidence: 0.35,
      source: ParsedSource.fallback,
    );
  }

  List<ParsedLineItem> _lineItems(List<String> lines) {
    final items = <ParsedLineItem>[];
    final trailingAmount = RegExp(
      r'(?<!\d)(-?(?:[০-৯0-9]{1,3}(?:,[০-৯0-9]{3})+|[০-৯0-9]+)(?:\.[০-৯0-9]{1,2})?)\s*(?:৳|Tk\.?|BDT|টাকা)?\s*$',
      caseSensitive: false,
    );
    for (final line in lines) {
      if (_totalKeyword.hasMatch(line) ||
          _weakTotal.hasMatch(line) ||
          _taxKeyword.hasMatch(line) ||
          DateNormalizer.find(line) != null) {
        continue;
      }
      final match = trailingAmount.firstMatch(line);
      if (match == null || match.start == 0) continue;
      final amount = CurrencyNormalizer.extractAmounts(
        match.group(0)!,
      ).lastOrNull;
      if (amount == null || amount <= 0) continue;
      var namePart = line.substring(0, match.start).trim();
      var quantity = 1.0;
      double? unitPrice;
      final quantityMatch = RegExp(
        r'(.+?)\s+(\d+(?:\.\d+)?)\s*[x×]\s*(\d+(?:\.\d+)?)\s*$',
        caseSensitive: false,
      ).firstMatch(TextNormalizer.normalizeForParsing(namePart));
      if (quantityMatch != null) {
        namePart = quantityMatch.group(1)!.trim();
        quantity = double.parse(quantityMatch.group(2)!);
        unitPrice = double.parse(quantityMatch.group(3)!);
      }
      if (namePart.length < 2 || namePart.toLowerCase().contains('invoice')) {
        continue;
      }
      items.add(
        ParsedLineItem(
          name: namePart,
          quantity: quantity,
          unitPrice: unitPrice,
          amount: amount,
          rawText: line,
        ),
      );
    }
    return items;
  }
}

extension<T> on List<T> {
  T? get lastOrNull => isEmpty ? null : last;
}
