import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rosid/ocr/engines/ocr_engine.dart';
import 'package:rosid/ocr/engines/tesseract_bn.dart';
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
    required this.tessdataInstaller,
    this.latinEngineRequiresTessdata = false,
  });

  final OcrEngine latinEngine;
  final OcrEngine banglaEngine;
  final TessdataInstaller tessdataInstaller;
  final bool latinEngineRequiresTessdata;

  Future<OcrResult> recognize(
    List<PreprocessedImage> pages, {
    ScriptHint hint = ScriptHint.automatic,
  }) async {
    final blocks = <OcrBlock>[];
    final engines = <String>{};
    TessdataInstallResult? tessdata;
    for (final page in pages) {
      if (latinEngineRequiresTessdata) {
        tessdata ??= await tessdataInstaller.install();
        _requireCompleteTessdata(tessdata);
      }
      final latin = await latinEngine.recognize(page, hint: hint);
      var pageResult = latin;
      final shouldRunBangla = ScriptDetector.shouldRunBanglaEngine(
        latin,
        hint: hint,
      );
      final latinAlreadyUsedBanglaEngine =
          latinEngineRequiresTessdata && latinEngine.id == banglaEngine.id;
      if (shouldRunBangla && !latinAlreadyUsedBanglaEngine) {
        tessdata ??= await tessdataInstaller.install();
        _requireCompleteTessdata(tessdata);
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

  void _requireCompleteTessdata(TessdataInstallResult result) {
    if (!result.isComplete) {
      throw BanglaOcrUnavailableException(result.missing);
    }
  }
}

final tesseractBanglaEngineProvider = Provider<TesseractBanglaEngine>(
  (ref) => const TesseractBanglaEngine(),
);

final ocrServiceProvider = Provider<OcrService>((ref) {
  final tesseract = ref.watch(tesseractBanglaEngineProvider);
  return OcrService(
    latinEngine: tesseract,
    banglaEngine: tesseract,
    tessdataInstaller: ref.watch(tessdataInstallerProvider),
    latinEngineRequiresTessdata: true,
  );
});
