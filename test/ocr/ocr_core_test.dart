import 'package:flutter_test/flutter_test.dart';
import 'package:rosid/ocr/engines/tflite_bn_stub.dart';
import 'package:rosid/ocr/merge.dart';
import 'package:rosid/ocr/models/ocr_models.dart';
import 'package:rosid/ocr/script_detect.dart';

void main() {
  OcrBlock block(
    String text, {
    String engine = 'engine',
    double confidence = 0.8,
    OcrRect box = const OcrRect(left: 0, top: 0, right: 100, bottom: 20),
  }) => OcrBlock(
    text: text,
    boundingBox: box,
    confidence: confidence,
    script: ScriptDetector.classify(text),
    engineId: engine,
  );

  test('detects Latin text', () {
    expect(ScriptDetector.classify('Grand Total'), DetectedScript.latin);
  });

  test('detects Bangla text', () {
    expect(ScriptDetector.classify('সর্বমোট টাকা'), DetectedScript.bangla);
  });

  test('detects mixed text', () {
    expect(ScriptDetector.classify('Total মোট'), DetectedScript.mixed);
  });

  test('marks digits as unknown script', () {
    expect(ScriptDetector.classify('1250.00'), DetectedScript.unknown);
  });

  test('explicit Bangla hint routes to Bangla engine', () {
    final result = OcrResult(
      blocks: [block('Total 10')],
      engineIds: const {'ml'},
    );
    expect(
      ScriptDetector.shouldRunBanglaEngine(result, hint: ScriptHint.bangla),
      isTrue,
    );
  });

  test('empty Latin result routes to Bangla engine', () {
    const result = OcrResult(blocks: [], engineIds: {'ml'});
    expect(
      ScriptDetector.shouldRunBanglaEngine(result, hint: ScriptHint.automatic),
      isTrue,
    );
  });

  test('strong Latin result stays on ML Kit', () {
    final result = OcrResult(
      blocks: [block('Grand Total')],
      engineIds: const {'ml'},
    );
    expect(
      ScriptDetector.shouldRunBanglaEngine(result, hint: ScriptHint.automatic),
      isFalse,
    );
  });

  test('merger prefers Bangla block at the same geometry', () {
    final latin = OcrResult(
      blocks: [block('nonsense', engine: 'ml')],
      engineIds: const {'ml'},
    );
    final bangla = OcrResult(
      blocks: [block('সর্বমোট', engine: 'tess')],
      engineIds: const {'tess'},
    );
    final result = OcrMerger.merge(latin, bangla);
    expect(result.blocks.single.text, 'সর্বমোট');
    expect(result.engineIds, containsAll(['ml', 'tess']));
  });

  test('merger keeps non-overlapping blocks', () {
    final result = OcrMerger.merge(
      OcrResult(blocks: [block('Shop')], engineIds: const {'ml'}),
      OcrResult(
        blocks: [
          block(
            'মোট',
            engine: 'tess',
            box: const OcrRect(left: 0, top: 50, right: 100, bottom: 70),
          ),
        ],
        engineIds: const {'tess'},
      ),
    );
    expect(result.blocks, hasLength(2));
  });

  test('TFLite handwriting seam is registered but disabled', () {
    const engine = TfliteBanglaHandwritingEngine();
    expect(engine.enabled, isFalse);
    expect(
      () => engine.recognize(
        const PreprocessedImage(
          colorCorrectedPath: 'color',
          binarizedPath: 'binary',
          width: 10,
          height: 10,
        ),
      ),
      throwsUnimplementedError,
    );
  });
}
