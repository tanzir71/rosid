import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rosid/data/repositories/scan_repository.dart';
import 'package:rosid/features/capture/capture_session.dart';
import 'package:rosid/features/crop/preprocess_controller.dart';
import 'package:rosid/ocr/models/ocr_models.dart';
import 'package:rosid/ocr/ocr_service.dart';

class OcrState {
  const OcrState({
    this.scanId,
    this.preprocessGeneration,
    this.result,
    this.isRunning = false,
    this.errorMessage,
  });

  final String? scanId;
  final int? preprocessGeneration;
  final OcrResult? result;
  final bool isRunning;
  final String? errorMessage;

  bool matches(String scanId, int generation) =>
      this.scanId == scanId && preprocessGeneration == generation;
}

class OcrController extends Notifier<OcrState> {
  var _requestToken = 0;
  Future<void> _requestBarrier = Future<void>.value();
  String? _activeKey;
  Future<OcrResult?>? _activeResult;

  @override
  OcrState build() => const OcrState();

  Future<OcrResult?> recognize({
    required CaptureSession session,
    required List<PreprocessedAsset> assets,
  }) {
    final scanId = session.scanId;
    final generation = assets.isEmpty ? null : assets.first.generation;
    if (scanId == null || generation == null) {
      return Future<OcrResult?>.value(null);
    }
    final key = '$scanId:$generation';
    if (state.isRunning && _activeKey == key && _activeResult != null) {
      return _activeResult!;
    }
    if (!state.isRunning &&
        state.matches(scanId, generation) &&
        state.result != null) {
      return Future<OcrResult?>.value(state.result);
    }

    final token = ++_requestToken;
    final pages = <PreprocessedImage>[
      for (var index = 0; index < assets.length; index++)
        PreprocessedImage(
          colorCorrectedPath: assets[index].colorPath,
          binarizedPath: assets[index].binaryPath,
          width: assets[index].width,
          height: assets[index].height,
          pageIndex: index,
        ),
    ];
    state = OcrState(
      scanId: scanId,
      preprocessGeneration: generation,
      isRunning: true,
    );
    final work = _requestBarrier.then(
      (_) => _performRecognition(
        token: token,
        scanId: scanId,
        generation: generation,
        pages: pages,
        languageHint: session.languageHint,
      ),
    );
    _requestBarrier = work.then<void>((_) {});
    _activeKey = key;
    _activeResult = work;
    return work;
  }

  Future<OcrResult?> _performRecognition({
    required int token,
    required String scanId,
    required int generation,
    required List<PreprocessedImage> pages,
    required CaptureLanguageHint languageHint,
  }) async {
    try {
      _ensureCurrent(token);
      final result = await ref
          .read(ocrServiceProvider)
          .recognize(pages, hint: _hintFor(languageHint));
      _ensureCurrent(token);
      await ref
          .read(scanRepositoryProvider)
          .updateOcr(
            scanId: scanId,
            rawText: result.text,
            engine: result.engineIds.join('+'),
            meanConfidence: result.meanConfidence,
          );
      _ensureCurrent(token);
      state = OcrState(
        scanId: scanId,
        preprocessGeneration: generation,
        result: result,
      );
      return result;
    } on Object catch (error) {
      if (token == _requestToken) {
        state = OcrState(
          scanId: scanId,
          preprocessGeneration: generation,
          errorMessage: error.toString(),
        );
      }
      return null;
    }
  }

  void _ensureCurrent(int token) {
    if (token != _requestToken) throw const _OcrCancelled();
  }

  ScriptHint _hintFor(CaptureLanguageHint hint) => switch (hint) {
    CaptureLanguageHint.automatic => ScriptHint.automatic,
    CaptureLanguageHint.banglaEnglish => ScriptHint.mixed,
    CaptureLanguageHint.english => ScriptHint.latin,
  };

  void reset() {
    _requestToken++;
    _activeKey = null;
    _activeResult = null;
    state = const OcrState();
  }
}

class _OcrCancelled implements Exception {
  const _OcrCancelled();
}

final ocrControllerProvider = NotifierProvider<OcrController, OcrState>(
  OcrController.new,
);
