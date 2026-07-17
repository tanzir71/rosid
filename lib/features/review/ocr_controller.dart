import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rosid/data/repositories/scan_repository.dart';
import 'package:rosid/features/capture/capture_session.dart';
import 'package:rosid/features/crop/preprocess_controller.dart';
import 'package:rosid/ocr/models/ocr_models.dart';
import 'package:rosid/ocr/ocr_service.dart';

class OcrState {
  const OcrState({this.result, this.isRunning = false, this.errorMessage});

  final OcrResult? result;
  final bool isRunning;
  final String? errorMessage;
}

class OcrController extends Notifier<OcrState> {
  @override
  OcrState build() => const OcrState();

  Future<OcrResult?> recognize({
    required CaptureSession session,
    required List<PreprocessedAsset> assets,
  }) async {
    if (session.scanId == null || assets.isEmpty || state.isRunning) {
      return state.result;
    }
    state = const OcrState(isRunning: true);
    try {
      final pages = <PreprocessedImage>[];
      for (var index = 0; index < assets.length; index++) {
        final asset = assets[index];
        pages.add(
          PreprocessedImage(
            colorCorrectedPath: asset.colorPath,
            binarizedPath: asset.binaryPath,
            width: asset.width,
            height: asset.height,
            pageIndex: index,
          ),
        );
      }
      final result = await ref
          .read(ocrServiceProvider)
          .recognize(pages, hint: _hintFor(session.languageHint));
      await ref
          .read(scanRepositoryProvider)
          .updateOcr(
            scanId: session.scanId!,
            rawText: result.text,
            engine: result.engineIds.join('+'),
            meanConfidence: result.meanConfidence,
          );
      state = OcrState(result: result);
      return result;
    } on Object catch (error) {
      state = OcrState(errorMessage: error.toString());
      return null;
    }
  }

  ScriptHint _hintFor(CaptureLanguageHint hint) => switch (hint) {
    CaptureLanguageHint.automatic => ScriptHint.automatic,
    CaptureLanguageHint.banglaEnglish => ScriptHint.mixed,
    CaptureLanguageHint.english => ScriptHint.latin,
  };

  void reset() => state = const OcrState();
}

final ocrControllerProvider = NotifierProvider<OcrController, OcrState>(
  OcrController.new,
);
