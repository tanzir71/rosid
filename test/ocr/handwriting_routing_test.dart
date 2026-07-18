import 'package:flutter_test/flutter_test.dart';
import 'package:rosid/ocr/handwriting/handwriting_routing.dart';
import 'package:rosid/ocr/models/ocr_models.dart';

void main() {
  test(
    'disabled handwriting routing always finishes the V1 baseline',
    () async {
      const policy = DisabledHandwritingRoutingPolicy();
      const result = OcrResult(blocks: [], engineIds: {'baseline'});
      final action = await policy.next(
        const HandwritingRouteContext(
          image: PreprocessedImage(
            colorCorrectedPath: 'color.jpg',
            binarizedPath: 'binary.jpg',
            width: 100,
            height: 200,
          ),
          hint: ScriptHint.automatic,
          primaryResult: result,
          baselineResult: result,
          tesseractHasRun: false,
          tesseractUnavailable: false,
        ),
      );

      expect(action, HandwritingRouteAction.finishBaseline);
    },
  );
}
