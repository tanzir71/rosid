import 'package:rosid/ocr/models/ocr_models.dart';
import 'package:rosid/ocr/script_detect.dart';

abstract final class OcrMerger {
  static OcrResult merge(OcrResult latin, OcrResult bangla) {
    final annotatedLatin = latin.blocks
        .map(
          (block) =>
              block.copyWith(script: ScriptDetector.classify(block.text)),
        )
        .toList();
    final annotatedBangla = bangla.blocks
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
        if (!merged.any((block) => _sameText(block.text, candidate.text))) {
          merged.add(candidate);
        }
        continue;
      }
      final existing = merged[overlapIndex];
      final preferBangla =
          candidate.script == DetectedScript.bangla ||
          candidate.script == DetectedScript.mixed;
      if (preferBangla ||
          (existing.script == DetectedScript.unknown &&
              candidate.confidence > existing.confidence)) {
        merged[overlapIndex] = candidate;
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

  static bool _sameText(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();
}
