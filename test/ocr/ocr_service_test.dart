import 'package:flutter_test/flutter_test.dart';
import 'package:rosid/ocr/engines/ocr_engine.dart';
import 'package:rosid/ocr/models/ocr_models.dart';
import 'package:rosid/ocr/ocr_service.dart';
import 'package:rosid/ocr/script_detect.dart';
import 'package:rosid/ocr/tessdata_installer.dart';

void main() {
  const pages = [
    PreprocessedImage(
      colorCorrectedPath: 'color-0',
      binarizedPath: 'binary-0',
      width: 100,
      height: 100,
      pageIndex: 0,
    ),
    PreprocessedImage(
      colorCorrectedPath: 'color-1',
      binarizedPath: 'binary-1',
      width: 100,
      height: 100,
      pageIndex: 1,
    ),
  ];

  test('strong Latin OCR does not install or invoke Bangla OCR', () async {
    final latin = _FakeEngine(
      id: 'latin',
      text: 'Grand Total',
      confidence: 0.95,
      top: 0,
    );
    final bangla = _FakeEngine(
      id: 'bangla',
      text: 'মোট',
      confidence: 0.9,
      top: 50,
    );
    final installer = _FakeInstaller(
      const TessdataInstallResult(installed: [], missing: []),
    );
    final service = _service(latin, bangla, installer);

    final result = await service.recognize([pages.first]);

    expect(result.engineIds, {'latin'});
    expect(latin.calls, 1);
    expect(bangla.calls, 0);
    expect(installer.calls, 0);
  });

  test(
    'mixed hint installs once and routes every page to both engines',
    () async {
      final latin = _FakeEngine(
        id: 'latin',
        text: 'Shop',
        confidence: 0.95,
        top: 0,
      );
      final bangla = _FakeEngine(
        id: 'bangla',
        text: 'মোট',
        confidence: 0.9,
        top: 50,
      );
      final installer = _FakeInstaller(
        const TessdataInstallResult(
          installed: ['eng.traineddata', 'ben.traineddata'],
          missing: [],
        ),
      );
      final service = _service(latin, bangla, installer);

      final result = await service.recognize(pages, hint: ScriptHint.mixed);

      expect(result.engineIds, {'latin', 'bangla'});
      expect(result.blocks, hasLength(4));
      expect(result.blocks.map((block) => block.pageIndex), [0, 0, 1, 1]);
      expect(latin.calls, 2);
      expect(bangla.calls, 2);
      expect(installer.calls, 1);
    },
  );

  test('missing tessdata throws an actionable typed error', () async {
    final latin = _FakeEngine(id: 'latin', text: '', confidence: 0, top: 0);
    final bangla = _FakeEngine(
      id: 'bangla',
      text: 'মোট',
      confidence: 0.9,
      top: 50,
    );
    final installer = _FakeInstaller(
      const TessdataInstallResult(
        installed: ['eng.traineddata'],
        missing: ['ben.traineddata'],
      ),
    );
    final service = _service(latin, bangla, installer);

    await expectLater(
      service.recognize([pages.first], hint: ScriptHint.bangla),
      throwsA(
        isA<BanglaOcrUnavailableException>()
            .having((error) => error.missingFiles, 'missingFiles', [
              'ben.traineddata',
            ])
            .having(
              (error) => error.toString(),
              'message',
              contains('Reinstall or update Rosid'),
            ),
      ),
    );
    expect(bangla.calls, 0);
    expect(installer.calls, 1);
  });
}

OcrService _service(
  OcrEngine latin,
  OcrEngine bangla,
  TessdataInstaller installer,
) {
  return OcrService(
    latinEngine: latin,
    banglaEngine: bangla,
    handwritingEngine: _FakeEngine(
      id: 'handwriting',
      text: '',
      confidence: 0,
      top: 0,
    ),
    tessdataInstaller: installer,
  );
}

class _FakeEngine implements OcrEngine {
  _FakeEngine({
    required this.id,
    required this.text,
    required this.confidence,
    required this.top,
  });

  @override
  final String id;
  final String text;
  final double confidence;
  final double top;
  int calls = 0;

  @override
  Set<ScriptHint> get supportedScripts => ScriptHint.values.toSet();

  @override
  Future<OcrResult> recognize(
    PreprocessedImage image, {
    ScriptHint? hint,
  }) async {
    calls++;
    final blocks = text.isEmpty
        ? const <OcrBlock>[]
        : [
            OcrBlock(
              text: text,
              boundingBox: OcrRect(
                left: 0,
                top: top,
                right: 100,
                bottom: top + 20,
              ),
              confidence: confidence,
              script: ScriptDetector.classify(text),
              engineId: id,
              pageIndex: image.pageIndex,
            ),
          ];
    return OcrResult(blocks: blocks, engineIds: {id});
  }
}

class _FakeInstaller extends TessdataInstaller {
  _FakeInstaller(this.result);

  final TessdataInstallResult result;
  int calls = 0;

  @override
  Future<TessdataInstallResult> install() async {
    calls++;
    return result;
  }
}
