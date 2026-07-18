import 'package:rosid/ocr/models/ocr_models.dart';

enum HandwritingRouteAction {
  finishBaseline,
  requestBanglaProbe,
  attemptHandwriting,
}

class HandwritingRouteContext {
  const HandwritingRouteContext({
    required this.image,
    required this.hint,
    required this.primaryResult,
    required this.baselineResult,
    required this.tesseractHasRun,
    required this.tesseractUnavailable,
  });

  final PreprocessedImage image;
  final ScriptHint hint;
  final OcrResult primaryResult;
  final OcrResult baselineResult;
  final bool tesseractHasRun;
  final bool tesseractUnavailable;
}

abstract interface class HandwritingRoutingPolicy {
  Future<HandwritingRouteAction> next(HandwritingRouteContext context);
}

/// Keeps V1 recognition routing unchanged until P0 approves a router.
final class DisabledHandwritingRoutingPolicy
    implements HandwritingRoutingPolicy {
  const DisabledHandwritingRoutingPolicy();

  @override
  Future<HandwritingRouteAction> next(HandwritingRouteContext context) async {
    return HandwritingRouteAction.finishBaseline;
  }
}
