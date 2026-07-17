String currencySymbol(String currency) => switch (currency.toUpperCase()) {
  'BDT' => '৳',
  'USD' => r'$',
  'EUR' => '€',
  _ => currency.toUpperCase(),
};

String formatMoney(double amount, String currency) {
  final symbol = currencySymbol(currency);
  final separator = symbol.length > 1 ? ' ' : '';
  return '$symbol$separator${amount.toStringAsFixed(2)}';
}
