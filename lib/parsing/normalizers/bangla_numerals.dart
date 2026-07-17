abstract final class BanglaNumerals {
  static const _bangla = '০১২৩৪৫৬৭৮৯';
  static const _latin = '0123456789';

  static String toLatin(String value) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final character = String.fromCharCode(rune);
      final index = _bangla.indexOf(character);
      buffer.write(index < 0 ? character : _latin[index]);
    }
    return buffer.toString();
  }

  static String toBangla(String value) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final character = String.fromCharCode(rune);
      final index = _latin.indexOf(character);
      buffer.write(index < 0 ? character : _bangla[index]);
    }
    return buffer.toString();
  }

  static double? tryParse(String value) {
    final normalized = toLatin(
      value,
    ).replaceAll(',', '').replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (normalized.isEmpty || normalized == '-' || normalized == '.') {
      return null;
    }
    return double.tryParse(normalized);
  }
}
