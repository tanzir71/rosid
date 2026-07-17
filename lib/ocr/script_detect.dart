import 'package:rosid/ocr/models/ocr_models.dart';

abstract final class ScriptDetector {
  static final RegExp _bangla = RegExp(r'[\u0980-\u09FF]');
  static final RegExp _latin = RegExp(r'[A-Za-z]');
  static final RegExp _digit = RegExp(r'[0-9\u09E6-\u09EF]');
  static final RegExp _wordLike = RegExp(
    r'[A-Za-z0-9\u0980-\u09FF\s.,:/()\-৳%]',
  );

  static DetectedScript classify(String text) {
    var bangla = 0;
    var latin = 0;
    for (final rune in text.runes) {
      final character = String.fromCharCode(rune);
      if (_bangla.hasMatch(character)) bangla++;
      if (_latin.hasMatch(character)) latin++;
    }
    final letters = bangla + latin;
    if (letters == 0) return DetectedScript.unknown;
    final banglaFraction = bangla / letters;
    if (banglaFraction >= 0.7) return DetectedScript.bangla;
    if (banglaFraction <= 0.15) return DetectedScript.latin;
    return DetectedScript.mixed;
  }

  static double nonWordRatio(String text) {
    final visible = text.runes
        .map(String.fromCharCode)
        .where((character) => character.trim().isNotEmpty)
        .toList();
    if (visible.isEmpty) return 1;
    final garbage = visible
        .where((character) => !_wordLike.hasMatch(character))
        .length;
    return garbage / visible.length;
  }

  static bool shouldRunBanglaEngine(
    OcrResult latinResult, {
    required ScriptHint hint,
  }) {
    if (hint == ScriptHint.bangla ||
        hint == ScriptHint.mixed ||
        hint == ScriptHint.banglaHandwriting) {
      return true;
    }
    if (latinResult.text.trim().isEmpty) return true;
    for (final block in latinResult.blocks) {
      final text = block.text.trim();
      if (text.isEmpty || _isDigitOnly(text)) continue;
      if (block.confidence < 0.52 || nonWordRatio(text) > 0.28) return true;
    }
    return false;
  }

  static bool _isDigitOnly(String text) =>
      _digit.hasMatch(text) &&
      !_latin.hasMatch(text) &&
      !_bangla.hasMatch(text) &&
      nonWordRatio(text) <= 0.28;
}
