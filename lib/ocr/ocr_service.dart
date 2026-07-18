import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rosid/ocr/engines/mlkit_latin.dart';
import 'package:rosid/ocr/engines/ocr_engine.dart';
import 'package:rosid/ocr/engines/tesseract_bn.dart';
import 'package:rosid/ocr/engines/tflite_bn_stub.dart';
import 'package:rosid/ocr/handwriting/handwriting_failures.dart';
import 'package:rosid/ocr/handwriting/handwriting_result_arbitrator.dart';
import 'package:rosid/ocr/handwriting/handwriting_routing.dart';
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
    this.latinEngineRequiresTessdata = false,
    this.handwritingRoutingPolicy = const DisabledHandwritingRoutingPolicy(),
    this.handwritingResultArbitrator =
        const UnconfiguredHandwritingResultArbitrator(),
  });

  final OcrEngine latinEngine;
  final OcrEngine banglaEngine;
  final OcrEngine handwritingEngine;
  final TessdataInstaller tessdataInstaller;
  final bool latinEngineRequiresTessdata;
  final HandwritingRoutingPolicy handwritingRoutingPolicy;
  final HandwritingResultArbitrator handwritingResultArbitrator;

  static const _serviceOwnedDiagnosticCodes = <OcrDiagnosticCode>{
    OcrDiagnosticCode.handwritingNotRouted,
    OcrDiagnosticCode.handwritingProbeRequested,
    OcrDiagnosticCode.handwritingFallbackUnavailable,
    OcrDiagnosticCode.handwritingAttempted,
    OcrDiagnosticCode.handwritingAccepted,
    OcrDiagnosticCode.handwritingFallbackSelected,
    OcrDiagnosticCode.handwritingEmpty,
    OcrDiagnosticCode.handwritingInvalid,
    OcrDiagnosticCode.handwritingRecoverableFailure,
  };

  Future<OcrResult> recognize(
    List<PreprocessedImage> pages, {
    ScriptHint hint = ScriptHint.automatic,
  }) async {
    final blocks = <OcrBlock>[];
    final engines = <String>{};
    final diagnostics = <OcrDiagnostic>[];
    TessdataInstallResult? tessdata;
    for (final page in pages) {
      Object? primaryTesseractFailure;
      StackTrace? primaryTesseractFailureStack;
      OcrResult latin;
      try {
        if (latinEngineRequiresTessdata) {
          final installedTessdata = tessdata ??= await tessdataInstaller
              .install();
          _requireCompleteTessdata(installedTessdata);
        }
        latin = _sanitizeExternalDiagnostics(
          await latinEngine.recognize(page, hint: hint),
        );
      } catch (error, stackTrace) {
        if (!latinEngineRequiresTessdata ||
            !_isRecoverableTesseractFailure(error)) {
          rethrow;
        }
        primaryTesseractFailure = error;
        primaryTesseractFailureStack = stackTrace;
        latin = const OcrResult(blocks: [], engineIds: {});
      }
      var pageResult = latin;
      var tesseractHasRun =
          latinEngineRequiresTessdata &&
          latinEngine.id == banglaEngine.id &&
          primaryTesseractFailure == null;
      var tesseractAttempted =
          tesseractHasRun ||
          (latinEngine.id == banglaEngine.id &&
              primaryTesseractFailure != null);
      Object? tesseractFailure = primaryTesseractFailure;
      StackTrace? tesseractFailureStack = primaryTesseractFailureStack;
      final routingDiagnostics = <OcrDiagnostic>[];

      Future<void> runBanglaFallback() async {
        if (tesseractHasRun) return;
        if (tesseractAttempted && tesseractFailure != null) {
          Error.throwWithStackTrace(
            tesseractFailure!,
            tesseractFailureStack ?? StackTrace.current,
          );
        }
        tesseractAttempted = true;
        final installedTessdata = tessdata ??= await tessdataInstaller
            .install();
        _requireCompleteTessdata(installedTessdata);
        final bangla = _sanitizeExternalDiagnostics(
          await banglaEngine.recognize(page, hint: hint),
        );
        pageResult = _snapshotResult(OcrMerger.merge(latin, bangla));
        tesseractHasRun = true;
      }

      Future<Object?> tryBanglaFallback() async {
        try {
          await runBanglaFallback();
          return null;
        } catch (error, stackTrace) {
          if (!_isRecoverableTesseractFailure(error)) rethrow;
          tesseractFailure = error;
          tesseractFailureStack = stackTrace;
          return error;
        }
      }

      HandwritingRouteContext routeContext() => HandwritingRouteContext(
        image: page,
        hint: hint,
        primaryResult: _mutableCopy(latin),
        baselineResult: _mutableCopy(pageResult),
        tesseractHasRun: tesseractHasRun,
        tesseractUnavailable: tesseractFailure != null,
      );

      final shouldRunBangla = ScriptDetector.shouldRunBanglaEngine(
        latin,
        hint: hint,
      );
      var action = await handwritingRoutingPolicy.next(routeContext());
      if (action == HandwritingRouteAction.requestBanglaProbe) {
        routingDiagnostics.add(
          _handwritingDiagnostic(
            OcrDiagnosticCode.handwritingProbeRequested,
            page,
            engineId: banglaEngine.id,
          ),
        );
        final failure = await tryBanglaFallback();
        if (failure != null) {
          routingDiagnostics.add(
            _handwritingDiagnostic(
              OcrDiagnosticCode.handwritingFallbackUnavailable,
              page,
              engineId: banglaEngine.id,
              detail: failure.runtimeType.toString(),
            ),
          );
        }
        action = await handwritingRoutingPolicy.next(routeContext());
        if (action == HandwritingRouteAction.requestBanglaProbe) {
          throw StateError(
            'The handwriting router requested a second Tesseract probe.',
          );
        }
      } else if (action == HandwritingRouteAction.finishBaseline &&
          shouldRunBangla) {
        // The disabled production router retains the exact V1 routing/error
        // behavior, including an actionable hard failure for missing tessdata.
        await runBanglaFallback();
      }
      if (action == HandwritingRouteAction.finishBaseline &&
          tesseractFailure != null &&
          pageResult.blocks.isEmpty) {
        Error.throwWithStackTrace(
          tesseractFailure!,
          tesseractFailureStack ?? StackTrace.current,
        );
      }
      if (action == HandwritingRouteAction.attemptHandwriting) {
        final fallbackFailure = await tryBanglaFallback();
        if (fallbackFailure != null &&
            !routingDiagnostics.any(
              (value) =>
                  value.code ==
                  OcrDiagnosticCode.handwritingFallbackUnavailable,
            )) {
          routingDiagnostics.add(
            _handwritingDiagnostic(
              OcrDiagnosticCode.handwritingFallbackUnavailable,
              page,
              engineId: banglaEngine.id,
              detail: fallbackFailure.runtimeType.toString(),
            ),
          );
        }
        routingDiagnostics.add(
          _handwritingDiagnostic(OcrDiagnosticCode.handwritingAttempted, page),
        );
        try {
          final handwriting = _sanitizeExternalDiagnostics(
            await handwritingEngine.recognize(
              page,
              hint: ScriptHint.banglaHandwriting,
            ),
          );
          if (handwriting.blocks.isEmpty) {
            routingDiagnostics.add(
              _handwritingDiagnostic(OcrDiagnosticCode.handwritingEmpty, page),
            );
          } else {
            _validateHandwritingResult(handwriting, page);
            final fallbackSnapshot = _snapshotResult(pageResult);
            final handwritingSnapshot = _snapshotResult(handwriting);
            final combined = _sanitizeExternalDiagnostics(
              handwritingResultArbitrator.combine(
                fallback: _mutableCopy(fallbackSnapshot),
                handwriting: _mutableCopy(handwritingSnapshot),
              ),
            );
            final usesHandwriting = _validateCombinedResult(
              combined,
              fallback: fallbackSnapshot,
              handwriting: handwritingSnapshot,
              image: page,
            );
            pageResult = OcrResult(
              blocks: combined.blocks,
              engineIds: combined.engineIds,
              diagnostics: _mergeDiagnostics(
                fallbackSnapshot.diagnostics,
                handwritingSnapshot.diagnostics,
                combined.diagnostics,
              ),
            );
            routingDiagnostics.add(
              _handwritingDiagnostic(
                usesHandwriting
                    ? OcrDiagnosticCode.handwritingAccepted
                    : OcrDiagnosticCode.handwritingFallbackSelected,
                page,
              ),
            );
          }
        } on InvalidHandwritingOutputException catch (error) {
          routingDiagnostics.add(
            _handwritingDiagnostic(
              OcrDiagnosticCode.handwritingInvalid,
              page,
              detail: error.runtimeType.toString(),
            ),
          );
        } on RecoverableHandwritingException catch (error) {
          routingDiagnostics.add(
            _handwritingDiagnostic(
              OcrDiagnosticCode.handwritingRecoverableFailure,
              page,
              detail: error.runtimeType.toString(),
            ),
          );
        }
        if (pageResult.blocks.isEmpty && tesseractFailure != null) {
          Error.throwWithStackTrace(
            tesseractFailure!,
            tesseractFailureStack ?? StackTrace.current,
          );
        }
      } else if (handwritingRoutingPolicy
          is! DisabledHandwritingRoutingPolicy) {
        routingDiagnostics.add(
          _handwritingDiagnostic(OcrDiagnosticCode.handwritingNotRouted, page),
        );
      }
      blocks.addAll(pageResult.blocks);
      engines.addAll(pageResult.engineIds);
      diagnostics.addAll(pageResult.diagnostics);
      diagnostics.addAll(routingDiagnostics);
    }
    blocks.sort((a, b) {
      final page = a.pageIndex.compareTo(b.pageIndex);
      if (page != 0) return page;
      return a.boundingBox.top.compareTo(b.boundingBox.top);
    });
    return OcrResult(
      blocks: blocks,
      engineIds: engines,
      diagnostics: diagnostics,
    );
  }

  void _requireCompleteTessdata(TessdataInstallResult result) {
    if (!result.isComplete) {
      throw BanglaOcrUnavailableException(result.missing);
    }
  }

  bool _isRecoverableTesseractFailure(Object error) {
    return error is BanglaOcrUnavailableException ||
        error is TesseractOcrTimeoutException ||
        error is TesseractOcrRuntimeException ||
        error is FileSystemException;
  }

  void _validateHandwritingResult(OcrResult result, PreprocessedImage image) {
    if (result.engineIds.length != 1 ||
        !result.engineIds.contains(handwritingEngine.id)) {
      throw InvalidHandwritingOutputException(
        'Result must identify only ${handwritingEngine.id}.',
      );
    }
    _validateResultBlocks(
      result,
      image,
      requiredEngineId: handwritingEngine.id,
    );
  }

  bool _validateCombinedResult(
    OcrResult result, {
    required OcrResult fallback,
    required OcrResult handwriting,
    required PreprocessedImage image,
  }) {
    if (result.blocks.isEmpty) {
      throw StateError('The handwriting arbitrator returned no usable blocks.');
    }
    final allowedEngineIds = {...fallback.engineIds, ...handwriting.engineIds};
    final unexpectedEngineIds = result.engineIds.difference(allowedEngineIds);
    final hasHandwritingBlock = result.blocks.any(
      (block) => block.engineId == handwritingEngine.id,
    );
    final isFallbackOnly = result.blocks.every(
      (block) => fallback.engineIds.contains(block.engineId),
    );
    if (unexpectedEngineIds.isNotEmpty ||
        (!hasHandwritingBlock && !isFallbackOnly)) {
      throw StateError(
        'The handwriting arbitrator introduced an unrelated OCR engine.',
      );
    }
    try {
      final remainingFallback = [...fallback.blocks];
      final remainingHandwriting = [...handwriting.blocks];
      for (final block in result.blocks) {
        if (block.engineId == handwritingEngine.id) {
          if (!_consumeMatchingBlock(block, remainingHandwriting)) {
            throw InvalidHandwritingOutputException(
              'The arbitrator changed, duplicated, or fabricated an HTR block.',
            );
          }
          _validateResultBlock(
            block,
            result.engineIds,
            image,
            requiredEngineId: handwritingEngine.id,
          );
        } else if (!result.engineIds.contains(block.engineId) ||
            !_consumeMatchingBlock(block, remainingFallback)) {
          throw InvalidHandwritingOutputException(
            'The arbitrator changed, duplicated, or fabricated a fallback block.',
          );
        }
      }
    } on InvalidHandwritingOutputException catch (error) {
      throw StateError(
        'The handwriting arbitrator returned invalid output: $error',
      );
    }
    return hasHandwritingBlock;
  }

  List<OcrDiagnostic> _mergeDiagnostics(
    List<OcrDiagnostic> fallback,
    List<OcrDiagnostic> handwriting,
    List<OcrDiagnostic> combined,
  ) {
    final seen = <(OcrDiagnosticCode, int, String, String?)>{};
    return [
      for (final diagnostic in [...fallback, ...handwriting, ...combined])
        if (seen.add((
          diagnostic.code,
          diagnostic.pageIndex,
          diagnostic.engineId,
          diagnostic.detail,
        )))
          diagnostic,
    ];
  }

  OcrResult _sanitizeExternalDiagnostics(OcrResult result) {
    final retained = result.diagnostics
        .where(
          (diagnostic) =>
              !_serviceOwnedDiagnosticCodes.contains(diagnostic.code),
        )
        .toList(growable: false);
    return _snapshotResult(
      OcrResult(
        blocks: result.blocks,
        engineIds: result.engineIds,
        diagnostics: retained,
      ),
    );
  }

  OcrResult _snapshotResult(OcrResult result) => OcrResult(
    blocks: List<OcrBlock>.unmodifiable(result.blocks),
    engineIds: Set<String>.unmodifiable(result.engineIds),
    diagnostics: List<OcrDiagnostic>.unmodifiable(result.diagnostics),
  );

  OcrResult _mutableCopy(OcrResult result) => OcrResult(
    blocks: List<OcrBlock>.of(result.blocks),
    engineIds: Set<String>.of(result.engineIds),
    diagnostics: List<OcrDiagnostic>.of(result.diagnostics),
  );

  void _validateResultBlocks(
    OcrResult result,
    PreprocessedImage image, {
    String? requiredEngineId,
  }) {
    for (final block in result.blocks) {
      _validateResultBlock(
        block,
        result.engineIds,
        image,
        requiredEngineId: requiredEngineId,
      );
    }
  }

  void _validateResultBlock(
    OcrBlock block,
    Set<String> resultEngineIds,
    PreprocessedImage image, {
    String? requiredEngineId,
  }) {
    final box = block.boundingBox;
    final finiteGeometry =
        box.left.isFinite &&
        box.top.isFinite &&
        box.right.isFinite &&
        box.bottom.isFinite;
    final insidePage =
        box.left >= 0 &&
        box.top >= 0 &&
        box.right <= image.width &&
        box.bottom <= image.height &&
        box.right > box.left &&
        box.bottom > box.top;
    if (block.text.trim().isEmpty ||
        !block.confidence.isFinite ||
        block.confidence < 0 ||
        block.confidence > 1 ||
        !finiteGeometry ||
        !insidePage ||
        block.pageIndex != image.pageIndex ||
        !resultEngineIds.contains(block.engineId) ||
        (requiredEngineId != null && block.engineId != requiredEngineId)) {
      throw InvalidHandwritingOutputException(
        'The handwriting engine returned an invalid line block.',
      );
    }
  }

  bool _consumeMatchingBlock(OcrBlock candidate, List<OcrBlock> available) {
    final index = available.indexWhere(
      (block) =>
          identical(candidate, block) ||
          (candidate.text == block.text &&
              candidate.boundingBox.left == block.boundingBox.left &&
              candidate.boundingBox.top == block.boundingBox.top &&
              candidate.boundingBox.right == block.boundingBox.right &&
              candidate.boundingBox.bottom == block.boundingBox.bottom &&
              candidate.confidence == block.confidence &&
              candidate.script == block.script &&
              candidate.engineId == block.engineId &&
              candidate.pageIndex == block.pageIndex),
    );
    if (index < 0) return false;
    available.removeAt(index);
    return true;
  }

  OcrDiagnostic _handwritingDiagnostic(
    OcrDiagnosticCode code,
    PreprocessedImage image, {
    String? engineId,
    String? detail,
  }) {
    return OcrDiagnostic(
      code: code,
      pageIndex: image.pageIndex,
      engineId: engineId ?? handwritingEngine.id,
      detail: detail,
    );
  }
}

final mlKitLatinEngineProvider = Provider<MlKitLatinEngine>((ref) {
  return const MlKitLatinEngine();
});

final tesseractBanglaEngineProvider = Provider<TesseractBanglaEngine>(
  (ref) => const TesseractBanglaEngine(),
);

final tfliteBanglaHandwritingEngineProvider =
    Provider<TfliteBanglaHandwritingEngine>(
      (ref) => const TfliteBanglaHandwritingEngine(),
    );

final ocrServiceProvider = Provider<OcrService>((ref) {
  final usesAndroidMlKit = Platform.isAndroid;
  final tesseract = ref.watch(tesseractBanglaEngineProvider);
  final latinEngine = usesAndroidMlKit
      ? ref.watch(mlKitLatinEngineProvider)
      : tesseract;
  return OcrService(
    latinEngine: latinEngine,
    banglaEngine: tesseract,
    handwritingEngine: ref.watch(tfliteBanglaHandwritingEngineProvider),
    tessdataInstaller: ref.watch(tessdataInstallerProvider),
    latinEngineRequiresTessdata: !usesAndroidMlKit,
  );
});
