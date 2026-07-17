import 'dart:math' as math;

import 'package:rosid/ocr/models/ocr_models.dart';
import 'package:rosid/ocr/script_detect.dart';

/// Converts Tesseract's hOCR word output into line-level OCR blocks while
/// preserving the engine's real bounding boxes and confidence values.
abstract final class TesseractHocrParser {
  static final RegExp _wordElement = RegExp(
    r'''<span\b([^>]*\bclass\s*=\s*["'][^"']*\bocrx_word\b[^"']*["'][^>]*)>(.*?)</span>''',
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp _bbox = RegExp(
    r'\bbbox\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)',
    caseSensitive: false,
  );
  static final RegExp _confidence = RegExp(
    r'\bx_wconf\s+(\d+(?:\.\d+)?)',
    caseSensitive: false,
  );

  static List<OcrBlock> parse(
    String hocr, {
    required String engineId,
    required int pageIndex,
    required int imageWidth,
    required int imageHeight,
  }) {
    final words = <_HocrWord>[];
    for (final match in _wordElement.allMatches(hocr)) {
      final attributes = match.group(1)!;
      final bbox = _bbox.firstMatch(attributes);
      final text = _plainText(match.group(2)!).trim();
      if (bbox == null || text.isEmpty) continue;
      final left = double.parse(
        bbox.group(1)!,
      ).clamp(0, imageWidth.toDouble()).toDouble();
      final top = double.parse(
        bbox.group(2)!,
      ).clamp(0, imageHeight.toDouble()).toDouble();
      final right = double.parse(
        bbox.group(3)!,
      ).clamp(left, imageWidth.toDouble()).toDouble();
      final bottom = double.parse(
        bbox.group(4)!,
      ).clamp(top, imageHeight.toDouble()).toDouble();
      if (right <= left || bottom <= top) continue;
      final confidenceMatch = _confidence.firstMatch(attributes);
      final confidence = confidenceMatch == null
          ? 0.35
          : (double.parse(confidenceMatch.group(1)!) / 100).clamp(0.0, 1.0);
      words.add(
        _HocrWord(
          text: text,
          box: OcrRect(left: left, top: top, right: right, bottom: bottom),
          confidence: confidence,
        ),
      );
    }

    if (words.isEmpty) {
      final text = _plainText(hocr).trim();
      if (text.isEmpty) return const [];
      return [
        OcrBlock(
          text: text,
          boundingBox: OcrRect(
            left: 0,
            top: 0,
            right: imageWidth.toDouble(),
            bottom: imageHeight.toDouble(),
          ),
          confidence: 0.25,
          script: ScriptDetector.classify(text),
          engineId: engineId,
          pageIndex: pageIndex,
        ),
      ];
    }

    final lines = <List<_HocrWord>>[];
    for (final word in words) {
      if (lines.isEmpty || !_sameLine(lines.last, word)) {
        lines.add([word]);
      } else {
        lines.last.add(word);
      }
    }

    return lines.map((line) {
      final text = line.map((word) => word.text).join(' ');
      final characterCount = line.fold<int>(
        0,
        (sum, word) => sum + math.max(1, word.text.runes.length),
      );
      final weightedConfidence =
          line.fold<double>(
            0,
            (sum, word) =>
                sum + word.confidence * math.max(1, word.text.runes.length),
          ) /
          characterCount;
      return OcrBlock(
        text: text,
        boundingBox: OcrRect(
          left: line.map((word) => word.box.left).reduce(math.min),
          top: line.map((word) => word.box.top).reduce(math.min),
          right: line.map((word) => word.box.right).reduce(math.max),
          bottom: line.map((word) => word.box.bottom).reduce(math.max),
        ),
        confidence: weightedConfidence,
        script: ScriptDetector.classify(text),
        engineId: engineId,
        pageIndex: pageIndex,
      );
    }).toList();
  }

  static bool _sameLine(List<_HocrWord> line, _HocrWord word) {
    final lineTop = line.map((item) => item.box.top).reduce(math.min);
    final lineBottom = line.map((item) => item.box.bottom).reduce(math.max);
    final overlap = math.max(
      0.0,
      math.min(lineBottom, word.box.bottom) - math.max(lineTop, word.box.top),
    );
    final smallerHeight = math.min(
      lineBottom - lineTop,
      word.box.bottom - word.box.top,
    );
    return smallerHeight > 0 && overlap / smallerHeight >= 0.45;
  }

  static String _plainText(String html) {
    var value = html.replaceAll(RegExp(r'<[^>]+>'), ' ');
    value = value
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    value = value.replaceAllMapped(RegExp(r'&#(x?[0-9A-Fa-f]+);'), (match) {
      final raw = match.group(1)!;
      final radix = raw.startsWith('x') ? 16 : 10;
      final digits = raw.startsWith('x') ? raw.substring(1) : raw;
      final codePoint = int.tryParse(digits, radix: radix);
      return codePoint == null
          ? match.group(0)!
          : String.fromCharCode(codePoint);
    });
    return value.replaceAll(RegExp(r'[ \t\f\v]+'), ' ');
  }
}

class _HocrWord {
  const _HocrWord({
    required this.text,
    required this.box,
    required this.confidence,
  });

  final String text;
  final OcrRect box;
  final double confidence;
}
