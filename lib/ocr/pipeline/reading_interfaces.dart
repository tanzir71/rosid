import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:rosid/ocr/models/ocr_models.dart';

/// Four-point bounding box of a detected text line in page pixel coordinates.
class DetectedLineBox {
  const DetectedLineBox({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
    required this.score,
  });

  factory DetectedLineBox.fromRect(OcrRect rect, {double score = 1.0}) {
    return DetectedLineBox(
      topLeft: (rect.left, rect.top),
      topRight: (rect.right, rect.top),
      bottomRight: (rect.right, rect.bottom),
      bottomLeft: (rect.left, rect.bottom),
      score: score,
    );
  }

  final (double, double) topLeft;
  final (double, double) topRight;
  final (double, double) bottomRight;
  final (double, double) bottomLeft;
  final double score;

  OcrRect get boundingRect {
    final xs = [topLeft.$1, topRight.$1, bottomRight.$1, bottomLeft.$1];
    final ys = [topLeft.$2, topRight.$2, bottomRight.$2, bottomLeft.$2];
    final left = xs.reduce((a, b) => a < b ? a : b);
    final right = xs.reduce((a, b) => a > b ? a : b);
    final top = ys.reduce((a, b) => a < b ? a : b);
    final bottom = ys.reduce((a, b) => a > b ? a : b);
    return OcrRect(left: left, top: top, right: right, bottom: bottom);
  }

  String toBoxJson() => jsonEncode([
    [topLeft.$1, topLeft.$2],
    [topRight.$1, topRight.$2],
    [bottomRight.$1, bottomRight.$2],
    [bottomLeft.$1, bottomLeft.$2],
  ]);

  static DetectedLineBox? fromBoxJson(String raw) {
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      if (list.length != 4) return null;
      (double, double) pt(dynamic v) {
        final pair = v as List<dynamic>;
        return ((pair[0] as num).toDouble(), (pair[1] as num).toDouble());
      }

      return DetectedLineBox(
        topLeft: pt(list[0]),
        topRight: pt(list[1]),
        bottomRight: pt(list[2]),
        bottomLeft: pt(list[3]),
        score: 1.0,
      );
    } on Object {
      return null;
    }
  }
}

/// Output of recognizing a single cropped text line.
class LineRecognition {
  const LineRecognition({
    required this.text,
    required this.confidence,
    required this.engineId,
    this.alternatives = const [],
  });

  final String text;
  final double confidence;
  final String engineId;
  final List<String> alternatives;
}

/// Uncertain word flagged for user review in Check Words (M4).
class UncertainWord {
  const UncertainWord({
    required this.word,
    required this.wordIndex,
    required this.confidence,
    this.alternatives = const [],
  });

  final String word;
  final int wordIndex;
  final double confidence;
  final List<String> alternatives;
}

/// One fully recognized line ready to persist to `text_lines`.
class RecognizedLine {
  const RecognizedLine({
    required this.pageIndex,
    required this.lineOrder,
    required this.text,
    required this.originalText,
    required this.box,
    required this.confidence,
    required this.script,
    required this.engineId,
    this.corrected = false,
    this.uncertainWords = const [],
  });

  final int pageIndex;
  final int lineOrder;
  final String text;
  final String originalText;
  final DetectedLineBox box;
  final double confidence;
  final String script; // 'bn', 'en', or 'mixed'
  final String engineId;
  final bool corrected;
  final List<UncertainWord> uncertainWords;

  RecognizedLine copyWith({
    String? text,
    double? confidence,
    bool? corrected,
    List<UncertainWord>? uncertainWords,
  }) {
    return RecognizedLine(
      pageIndex: pageIndex,
      lineOrder: lineOrder,
      text: text ?? this.text,
      originalText: originalText,
      box: box,
      confidence: confidence ?? this.confidence,
      script: script,
      engineId: engineId,
      corrected: corrected ?? this.corrected,
      uncertainWords: uncertainWords ?? this.uncertainWords,
    );
  }
}

/// Result of reading a single cleaned greyscale page.
class ReadingPageResult {
  const ReadingPageResult({
    required this.pageIndex,
    required this.lines,
    required this.hasHandwriting,
    required this.elapsedMs,
    required this.engineSummary,
    this.imageWidth = 0,
    this.imageHeight = 0,
  });

  final int pageIndex;
  final List<RecognizedLine> lines;
  final bool hasHandwriting;
  final int elapsedMs;
  final String engineSummary;
  final int imageWidth;
  final int imageHeight;

  String get fullText =>
      lines.map((l) => l.text.trim()).where((t) => t.isNotEmpty).join('\n');

  int get uncertainWordCount =>
      lines.fold<int>(0, (sum, l) => sum + l.uncertainWords.length);

  double get meanConfidence {
    if (lines.isEmpty) return 0;
    return lines.fold<double>(0, (s, l) => s + l.confidence) / lines.length;
  }
}

/// Progress updates emitted by [ReadingPipeline] to drive `ReadingProgressScreen`.
class ReadingProgressEvent {
  const ReadingProgressEvent({
    required this.stage,
    this.currentLine = 0,
    this.totalLines = 0,
    this.hasHandwriting = false,
  });

  final ReadingStage stage;
  final int currentLine;
  final int totalLines;
  final bool hasHandwriting;
}

enum ReadingStage {
  cleaning,
  detectingLines,
  readingLines,
  findingDetails,
  done,
}

/// Cancellation token so tapping Cancel on `ReadingProgressScreen` stops work
/// cleanly between lines without leaking resources.
class ReadingCancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() {
    _cancelled = true;
  }
}

/// Abstract line detector interface (e.g. PP-OCRv5 mobile ONNX).
abstract interface class LineDetector {
  Future<List<DetectedLineBox>> detect(img.Image greyPage);
}

/// Abstract single-line recogniser interface (Latin ONNX or Bangla Tesseract).
abstract interface class LineRecognizer {
  String get id;

  Future<LineRecognition> recognize(img.Image lineCrop);
}

/// Abstract full reading pipeline interface.
abstract interface class ReadingPipeline {
  Future<ReadingPageResult> readPage({
    required Uint8List greyImageBytes,
    required int pageIndex,
    void Function(ReadingProgressEvent event)? onProgress,
    ReadingCancelToken? cancelToken,
  });
}
