import 'package:rosid/parsing/normalizers/bangla_numerals.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

abstract final class TextNormalizer {
  static String normalize(String input) {
    return unorm
        .nfc(input)
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r' *\n *'), '\n')
        .trim();
  }

  static String normalizeForParsing(String input) {
    return BanglaNumerals.toLatin(normalize(input));
  }
}
