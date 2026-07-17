import 'package:rosid/ocr/models/ocr_models.dart';
import 'package:rosid/ocr/script_detect.dart';

abstract final class OcrMerger {
  static OcrResult merge(OcrResult latin, OcrResult bangla) {
    final annotatedLatin = latin.blocks
        .expand(_splitLines)
        .map(
          (block) =>
              block.copyWith(script: ScriptDetector.classify(block.text)),
        )
        .toList();
    final annotatedBangla = bangla.blocks
        .expand(_splitLines)
        .map(
          (block) =>
              block.copyWith(script: ScriptDetector.classify(block.text)),
        )
        .toList();
    final merged = <OcrBlock>[...annotatedLatin];

    for (final candidate in annotatedBangla) {
      final overlapIndex = merged.indexWhere(
        (existing) =>
            existing.pageIndex == candidate.pageIndex &&
            existing.boundingBox.intersectionOverUnion(candidate.boundingBox) >
                0.45,
      );
      if (overlapIndex < 0) {
        merged.add(candidate);
        continue;
      }
      final existing = merged[overlapIndex];
      final preferBangla =
          candidate.script == DetectedScript.bangla ||
          candidate.script == DetectedScript.mixed;
      final credibleBanglaReplacement =
          preferBangla &&
          candidate.confidence >= 0.45 &&
          candidate.confidence + 0.25 >= existing.confidence;
      final betterUnknownReplacement =
          existing.script == DetectedScript.unknown &&
          candidate.confidence > existing.confidence;
      if (credibleBanglaReplacement || betterUnknownReplacement) {
        merged[overlapIndex] = candidate;
      } else if (preferBangla && candidate.confidence >= 0.35) {
        // The engines disagree without a clear confidence winner. Preserve
        // both readings so review remains lossless instead of silently
        // replacing a stronger result.
        merged.add(candidate);
      }
    }
    merged.sort((a, b) {
      final page = a.pageIndex.compareTo(b.pageIndex);
      if (page != 0) return page;
      final row = a.boundingBox.top.compareTo(b.boundingBox.top);
      return row != 0 ? row : a.boundingBox.left.compareTo(b.boundingBox.left);
    });
    return OcrResult(
      blocks: merged,
      engineIds: {...latin.engineIds, ...bangla.engineIds},
    );
  }

  static Iterable<OcrBlock> _splitLines(OcrBlock block) sync* {
    final lines = block.text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.length <= 1 || block.boundingBox.height <= 0) {
      yield block;
      return;
    }
    final lineHeight = block.boundingBox.height / lines.length;
    for (var index = 0; index < lines.length; index++) {
      yield OcrBlock(
        text: lines[index],
        boundingBox: OcrRect(
          left: block.boundingBox.left,
          top: block.boundingBox.top + lineHeight * index,
          right: block.boundingBox.right,
          bottom: block.boundingBox.top + lineHeight * (index + 1),
        ),
        confidence: block.confidence,
        script: ScriptDetector.classify(lines[index]),
        engineId: block.engineId,
        pageIndex: block.pageIndex,
      );
    }
  }
}
