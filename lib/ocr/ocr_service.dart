import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rosid/ocr/engines/mlkit_latin.dart';
import 'package:rosid/ocr/engines/ocr_engine.dart';
import 'package:rosid/ocr/engines/tesseract_bn.dart';
import 'package:rosid/ocr/engines/tflite_bn_stub.dart';
import 'package:rosid/ocr/merge.dart';
import 'package:rosid/ocr/models/ocr_models.dart';
import 'package:rosid/ocr/script_detect.dart';
import 'package:rosid/ocr/tessdata_installer.dart';

class BanglaOcrUnavailableException implements Exception {
  BanglaOcrUnavailableException(Iterable<String> missingFiles)
    : missingFiles = List.unmodifiable(missingFiles);

  final List<String> missingFiles;

  @override
  String toString() {
    final files = missingFiles.isEmpty
        ? 'unknown files'
        : missingFiles.join(', ');
    return 'Bangla OCR language data is unavailable ($files). '
        'Reinstall or update Rosid to restore its bundled offline OCR data.';
  }
}

class OcrService {
  const OcrService({
    required this.latinEngine,
    required this.banglaEngine,
    required this.handwritingEngine,
    required this.tessdataInstaller,
  });

  final OcrEngine latinEngine;
  final OcrEngine banglaEngine;
  final OcrEngine handwritingEngine;
  final TessdataInstaller tessdataInstaller;

  Future<OcrResult> recognize(
    List<PreprocessedImage> pages, {
    ScriptHint hint = ScriptHint.automatic,
  }) async {
    final blocks = <OcrBlock>[];
    final engines = <String>{};
    TessdataInstallResult? tessdata;
    for (final page in pages) {
      final latin = await latinEngine.recognize(page, hint: hint);
      var pageResult = latin;
      if (ScriptDetector.shouldRunBanglaEngine(latin, hint: hint)) {
        tessdata ??= await tessdataInstaller.install();
        if (!tessdata.isComplete) {
          throw BanglaOcrUnavailableException(tessdata.missing);
        }
        final bangla = await banglaEngine.recognize(page, hint: hint);
        pageResult = OcrMerger.merge(latin, bangla);
      }
      blocks.addAll(pageResult.blocks);
      engines.addAll(pageResult.engineIds);
    }
    blocks.sort((a, b) {
      final page = a.pageIndex.compareTo(b.pageIndex);
      if (page != 0) return page;
      return a.boundingBox.top.compareTo(b.boundingBox.top);
    });
    return OcrResult(blocks: blocks, engineIds: engines);
  }
}

final mlKitLatinEngineProvider = Provider<MlKitLatinEngine>((ref) {
  final engine = MlKitLatinEngine();
  ref.onDispose(engine.close);
  return engine;
});

final tesseractBanglaEngineProvider = Provider<TesseractBanglaEngine>(
  (ref) => const TesseractBanglaEngine(),
);

final tfliteBanglaHandwritingEngineProvider =
    Provider<TfliteBanglaHandwritingEngine>(
      (ref) => const TfliteBanglaHandwritingEngine(),
    );

final ocrServiceProvider = Provider<OcrService>(
  (ref) => OcrService(
    latinEngine: ref.watch(mlKitLatinEngineProvider),
    banglaEngine: ref.watch(tesseractBanglaEngineProvider),
    handwritingEngine: ref.watch(tfliteBanglaHandwritingEngineProvider),
    tessdataInstaller: ref.watch(tessdataInstallerProvider),
  ),
);
