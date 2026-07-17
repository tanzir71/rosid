import 'package:rosid/parsing/models/parsed_receipt.dart';
import 'package:rosid/parsing/normalizers/bangla_numerals.dart';

class ReceiptInputValidationException implements Exception {
  const ReceiptInputValidationException();
}

abstract final class ReceiptInputValidation {
  static const _numberPattern = r'[+-]?(?:\d+|\d{1,3}(?:,\d{3})+)(?:\.\d+)?';
  static const _currencyPattern = r'(?:৳|BDT|Taka|Tk\.?|টাকা)';
  static final RegExp _plainNumber = RegExp('^($_numberPattern)\$');
  static final RegExp _prefixedAmount = RegExp(
    '^$_currencyPattern\\s*($_numberPattern)\$',
    caseSensitive: false,
  );
  static final RegExp _suffixedAmount = RegExp(
    '^($_numberPattern)\\s*$_currencyPattern\$',
    caseSensitive: false,
  );

  static double requiredNonNegativeAmount(String text) {
    final value = _strictNumber(text, allowCurrency: true);
    if (value == null || value < 0) {
      throw const ReceiptInputValidationException();
    }
    return value;
  }

  static double? optionalNonNegativeAmount(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) return null;
    final value = _strictNumber(normalized, allowCurrency: true);
    if (value == null || value < 0) {
      throw const ReceiptInputValidationException();
    }
    return value;
  }

  static ParsedLineItem? lineItem({
    required String name,
    required String quantity,
    required String unitPrice,
    required String amount,
  }) {
    final normalizedName = name.trim();
    final amountText = amount.trim();
    final quantityText = quantity.trim();
    final unitPriceText = unitPrice.trim();
    if (normalizedName.isEmpty && amountText.isEmpty && unitPriceText.isEmpty) {
      return null;
    }

    final parsedAmount = _strictNumber(amountText, allowCurrency: true);
    final parsedQuantity = quantityText.isEmpty
        ? 1.0
        : _strictNumber(quantityText, allowCurrency: false);
    final parsedUnitPrice = unitPriceText.isEmpty
        ? null
        : _strictNumber(unitPriceText, allowCurrency: true);
    if (normalizedName.isEmpty ||
        parsedAmount == null ||
        parsedAmount < 0 ||
        parsedQuantity == null ||
        parsedQuantity <= 0 ||
        (unitPriceText.isNotEmpty &&
            (parsedUnitPrice == null || parsedUnitPrice < 0))) {
      throw const ReceiptInputValidationException();
    }
    return ParsedLineItem(
      name: normalizedName,
      quantity: parsedQuantity,
      unitPrice: parsedUnitPrice,
      amount: parsedAmount,
      rawText: '',
    );
  }

  static double? _strictNumber(String text, {required bool allowCurrency}) {
    final normalized = BanglaNumerals.toLatin(text.trim());
    if (normalized.isEmpty) return null;
    final match =
        _plainNumber.firstMatch(normalized) ??
        (allowCurrency ? _prefixedAmount.firstMatch(normalized) : null) ??
        (allowCurrency ? _suffixedAmount.firstMatch(normalized) : null);
    if (match == null) return null;
    final value = double.tryParse(match.group(1)!.replaceAll(',', ''));
    if (value == null || !value.isFinite) return null;
    return value;
  }
}
