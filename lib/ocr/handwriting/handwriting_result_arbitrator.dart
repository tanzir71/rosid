import 'package:rosid/ocr/models/ocr_models.dart';

abstract interface class HandwritingResultArbitrator {
  OcrResult combine({
    required OcrResult fallback,
    required OcrResult handwriting,
  });
}

/// Fails loudly if a router is enabled before P0 selects an arbitration policy.
final class UnconfiguredHandwritingResultArbitrator
    implements HandwritingResultArbitrator {
  const UnconfiguredHandwritingResultArbitrator();

  @override
  OcrResult combine({
    required OcrResult fallback,
    required OcrResult handwriting,
  }) {
    throw StateError(
      'Handwriting routing was enabled without a result arbitrator.',
    );
  }
}
