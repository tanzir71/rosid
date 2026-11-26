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

  /// Normalizes Bangla and English text for FTS5 indexing and search matching
  /// (`handover/milestones/M7-library-and-bundles.md` step 3):
  /// - Unicode NFC
  /// - Strips zero-width joiners / non-joiners (`\u200C`, `\u200D`, `\uFEFF`)
  /// - Canonicalizes nukta forms & spelling variants (`য+়` / `য়` -> `য়`,
  ///   `ড+়` / `ড়` -> `ড়`, `ঢ+়` / `ঢ়` -> `ঢ়`, `র` variants, `ী`->`ি`? kept distinct
  ///   while folding `য়`/`য` nukta decompositions and `ড়`/`ঢ়`/`য়` compatibility points)
  /// - Lowercases Latin for case-insensitive matching.
  static String normalizeForSearch(String input) {
    if (input.isEmpty) return '';
    return unorm
        .nfc(input)
        .replaceAll('\u200C', '')
        .replaceAll('\u200D', '')
        .replaceAll('\uFEFF', '')
        .replaceAll('\u00A0', ' ')
        // Ensure decomposed nukta sequences become canonical precomposed Bangla forms.
        .replaceAll('য\u09BC', 'য়')
        .replaceAll('ড\u09BC', 'ড়')
        .replaceAll('ঢ\u09BC', 'ঢ়')
        // Map common Bangla OCR/keyboard orthographic variants for search recall:
        // e.g. `য়` (U+09DF) vs `য` without nukta when preceded by vowel/consonant?
        // Keep exact precomposed canonical forms `য়`, `ড়`, `ঢ়`, and fold
        // `য়`/`ড়`/`ঢ়` (which are identical to NFC precomposed) + Bangla `ঃ` variants.
        .replaceAll('ঃ', ':')
        .toLowerCase()
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r' *\n *'), '\n')
        .trim();
  }
}
