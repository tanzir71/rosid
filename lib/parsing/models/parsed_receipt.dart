enum ParsedSource { keyword, pattern, fallback, inferred, lineItemSum }

class ParsedField<T> {
  const ParsedField({
    required this.value,
    required this.rawText,
    required this.confidence,
    required this.source,
  });

  final T value;
  final String rawText;
  final double confidence;
  final ParsedSource source;

  ParsedField<T> copyWith({double? confidence, ParsedSource? source}) {
    return ParsedField<T>(
      value: value,
      rawText: rawText,
      confidence: confidence ?? this.confidence,
      source: source ?? this.source,
    );
  }
}

class ParsedLineItem {
  const ParsedLineItem({
    required this.name,
    required this.quantity,
    required this.amount,
    required this.rawText,
    this.unitPrice,
  });

  final String name;
  final double quantity;
  final double? unitPrice;
  final double amount;
  final String rawText;
}

class ParsedReceipt {
  const ParsedReceipt({
    required this.merchant,
    required this.date,
    required this.total,
    required this.tax,
    required this.paymentMethod,
    required this.categoryId,
    required this.lineItems,
    required this.rawText,
  });

  final ParsedField<String> merchant;
  final ParsedField<DateTime> date;
  final ParsedField<double?> total;
  final ParsedField<double?> tax;
  final ParsedField<String?> paymentMethod;
  final ParsedField<String?> categoryId;
  final List<ParsedLineItem> lineItems;
  final String rawText;
}
