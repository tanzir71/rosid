import 'dart:ui';

const _banglaDigits = <String, String>{
  '0': '০',
  '1': '১',
  '2': '২',
  '3': '৩',
  '4': '৪',
  '5': '৫',
  '6': '৬',
  '7': '৭',
  '8': '৮',
  '9': '৯',
};

const _latinDigits = <String, String>{
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

/// Converts ASCII digits to Bangla digits when [locale] is `bn`.
String localizeDigits(String input, Locale locale) {
  if (locale.languageCode != 'bn') return input;
  return toBanglaDigits(input);
}

/// Converts ASCII digits (`0-9`) to Bangla digits (`০-৯`).
String toBanglaDigits(String input) {
  final sb = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    final ch = input[i];
    sb.write(_banglaDigits[ch] ?? ch);
  }
  return sb.toString();
}

/// Converts Bangla digits (`০-৯`) to ASCII digits (`0-9`).
String toLatinDigits(String input) {
  final sb = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    final ch = input[i];
    sb.write(_latinDigits[ch] ?? ch);
  }
  return sb.toString();
}
