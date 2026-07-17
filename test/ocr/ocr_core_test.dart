import 'package:flutter_test/flutter_test.dart';
import 'package:rosid/ocr/engines/mlkit_latin.dart';
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
    int pageIndex = 0,
  }) => OcrBlock(
    text: text,
    boundingBox: box,
    confidence: confidence,
    script: ScriptDetector.classify(text),
    engineId: engine,
    pageIndex: pageIndex,
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

  test('a diluted low-confidence block still routes to Bangla OCR', () {
    final result = OcrResult(
      blocks: [
        for (var index = 0; index < 9; index++)
          block('Strong English line $index', confidence: 0.95),
        block('@@@ ???', confidence: 0.2),
      ],
      engineIds: const {'ml'},
    );

    expect(result.meanConfidence, greaterThan(0.8));
    expect(
      ScriptDetector.shouldRunBanglaEngine(result, hint: ScriptHint.automatic),
      isTrue,
    );
  });

  test('digit-only totals do not trigger Bangla OCR by confidence alone', () {
    final result = OcrResult(
      blocks: [block('1250.00', confidence: 0.2)],
      engineIds: const {'ml'},
    );

    expect(
      ScriptDetector.shouldRunBanglaEngine(result, hint: ScriptHint.automatic),
      isFalse,
    );
  });

  test('missing ML Kit confidence uses a verification-safe fallback', () {
    expect(mlKitConfidenceOrFallback(null), 0.55);
    expect(mlKitConfidenceOrFallback(1.4), 1);
    final cleanLatin = OcrResult(
      blocks: [
        block(
          'Clean English receipt',
          confidence: mlKitConfidenceOrFallback(null),
        ),
      ],
      engineIds: const {'ml'},
    );
    expect(
      ScriptDetector.shouldRunBanglaEngine(
        cleanLatin,
        hint: ScriptHint.automatic,
      ),
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

  test('merger does not replace a strong reading with weak Bangla text', () {
    final result = OcrMerger.merge(
      OcrResult(
        blocks: [block('Correct total', engine: 'ml', confidence: 0.95)],
        engineIds: const {'ml'},
      ),
      OcrResult(
        blocks: [
          block(
            '\u09ad\u09c1\u09b2 \u09aa\u09be\u09a0',
            engine: 'tess',
            confidence: 0.05,
          ),
        ],
        engineIds: const {'tess'},
      ),
    );

    expect(result.blocks.single.text, 'Correct total');
  });

  test('merger keeps both plausible readings when confidence is ambiguous', () {
    final result = OcrMerger.merge(
      OcrResult(
        blocks: [block('Grand total', engine: 'ml', confidence: 0.95)],
        engineIds: const {'ml'},
      ),
      OcrResult(
        blocks: [
          block(
            '\u09b8\u09b0\u09cd\u09ac\u09ae\u09cb\u099f',
            engine: 'tess',
            confidence: 0.55,
          ),
        ],
        engineIds: const {'tess'},
      ),
    );

    expect(result.blocks.map((value) => value.text), contains('Grand total'));
    expect(
      result.blocks.map((value) => value.text),
      contains('\u09b8\u09b0\u09cd\u09ac\u09ae\u09cb\u099f'),
    );
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

  test('merger preserves repeated text at distinct positions and pages', () {
    final result = OcrMerger.merge(
      OcrResult(blocks: [block('Total')], engineIds: const {'ml'}),
      OcrResult(
        blocks: [
          block(
            'Total',
            engine: 'tess',
            box: const OcrRect(left: 0, top: 50, right: 100, bottom: 70),
          ),
          block('Total', engine: 'tess', pageIndex: 1),
        ],
        engineIds: const {'tess'},
      ),
    );

    expect(result.blocks, hasLength(3));
    expect(result.blocks.map((value) => value.pageIndex), [0, 0, 1]);
  });

  test('merger splits a multiline ML block before replacing one line', () {
    final result = OcrMerger.merge(
      OcrResult(
        blocks: [
          block(
            'Shop\nTotal 262.50',
            engine: 'ml',
            box: const OcrRect(left: 0, top: 0, right: 100, bottom: 40),
          ),
        ],
        engineIds: const {'ml'},
      ),
      OcrResult(
        blocks: [
          block(
            '\u09ae\u09cb\u099f \u09e8\u09ec\u09e8.\u09eb\u09e6',
            engine: 'tess',
            box: const OcrRect(left: 0, top: 20, right: 100, bottom: 40),
          ),
        ],
        engineIds: const {'tess'},
      ),
    );

    expect(result.blocks.map((value) => value.text), [
      'Shop',
      '\u09ae\u09cb\u099f \u09e8\u09ec\u09e8.\u09eb\u09e6',
    ]);
  });

  test(
    'merger prefers mixed-script Tesseract text at matching line geometry',
    () {
      final result = OcrMerger.merge(
        OcrResult(
          blocks: [block('Total 262.50', engine: 'ml')],
          engineIds: const {'ml'},
        ),
        OcrResult(
          blocks: [
            block(
              'Total \u09ae\u09cb\u099f \u09e8\u09ec\u09e8.\u09eb\u09e6',
              engine: 'tess',
            ),
          ],
          engineIds: const {'tess'},
        ),
      );

      expect(result.blocks.single.text, contains('\u09ae\u09cb\u099f'));
    },
  );

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
