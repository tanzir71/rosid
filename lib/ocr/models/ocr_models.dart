class OcrRect {
  const OcrRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  const OcrRect.empty() : left = 0, top = 0, right = 0, bottom = 0;

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => (right - left).clamp(0, double.infinity);
  double get height => (bottom - top).clamp(0, double.infinity);
  double get area => width * height;

  double intersectionOverUnion(OcrRect other) {
    final overlapWidth =
        (right.clamp(other.left, other.right) -
                left.clamp(other.left, other.right))
            .abs();
    final xOverlap = (right < other.left || other.right < left)
        ? 0.0
        : overlapWidth;
    final overlapHeight =
        (bottom.clamp(other.top, other.bottom) -
                top.clamp(other.top, other.bottom))
            .abs();
    final yOverlap = (bottom < other.top || other.bottom < top)
        ? 0.0
        : overlapHeight;
    final intersection = xOverlap * yOverlap;
    final union = area + other.area - intersection;
    return union <= 0 ? 0 : intersection / union;
  }
}

enum ScriptHint { automatic, latin, bangla, mixed, banglaHandwriting }

enum DetectedScript { latin, bangla, mixed, unknown }

enum OcrDiagnosticCode {
  handwritingNotRouted,
  handwritingProbeRequested,
  handwritingFallbackUnavailable,
  handwritingAttempted,
  handwritingAccepted,
  handwritingFallbackSelected,
  handwritingEmpty,
  handwritingInvalid,
  handwritingRecoverableFailure,
}

class OcrDiagnostic {
  const OcrDiagnostic({
    required this.code,
    required this.pageIndex,
    required this.engineId,
    this.detail,
  });

  final OcrDiagnosticCode code;
  final int pageIndex;
  final String engineId;
  final String? detail;
}

class OcrBlock {
  const OcrBlock({
    required this.text,
    required this.boundingBox,
    required this.confidence,
    required this.script,
    required this.engineId,
    this.pageIndex = 0,
  });

  final String text;
  final OcrRect boundingBox;
  final double confidence;
  final DetectedScript script;
  final String engineId;
  final int pageIndex;

  OcrBlock copyWith({DetectedScript? script, int? pageIndex}) => OcrBlock(
    text: text,
    boundingBox: boundingBox,
    confidence: confidence,
    script: script ?? this.script,
    engineId: engineId,
    pageIndex: pageIndex ?? this.pageIndex,
  );
}

class OcrResult {
  const OcrResult({
    required this.blocks,
    required this.engineIds,
    this.diagnostics = const [],
  });

  final List<OcrBlock> blocks;
  final Set<String> engineIds;
  final List<OcrDiagnostic> diagnostics;

  String get text => blocks
      .map((block) => block.text.trim())
      .where((text) => text.isNotEmpty)
      .join('\n');

  double get meanConfidence {
    if (blocks.isEmpty) return 0;
    return blocks.fold<double>(0, (sum, block) => sum + block.confidence) /
        blocks.length;
  }
}

class PreprocessedImage {
  const PreprocessedImage({
    required this.colorCorrectedPath,
    required this.binarizedPath,
    required this.width,
    required this.height,
    this.pageIndex = 0,
  });

  final String colorCorrectedPath;
  final String binarizedPath;
  final int width;
  final int height;
  final int pageIndex;
}
