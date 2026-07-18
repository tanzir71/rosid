import 'package:flutter/services.dart';
import 'package:rosid/ocr/engines/ocr_engine.dart';
import 'package:rosid/ocr/models/ocr_models.dart';
import 'package:rosid/ocr/script_detect.dart';

double mlKitConfidenceOrFallback(double? confidence) =>
    (confidence ?? 0.55).clamp(0, 1).toDouble();

class NativeOcrLine {
  const NativeOcrLine({
    required this.text,
    required this.boundingBox,
    this.confidence,
  });

  final String text;
  final OcrRect boundingBox;
  final double? confidence;
}

abstract interface class AndroidLatinOcrClient {
  Future<List<NativeOcrLine>> recognize(String imagePath);
}

class MethodChannelAndroidLatinOcrClient implements AndroidLatinOcrClient {
  const MethodChannelAndroidLatinOcrClient();

  static const _channel = MethodChannel('app.rosid.rosid/ocr');

  @override
  Future<List<NativeOcrLine>> recognize(String imagePath) async {
    final response = await _channel.invokeListMethod<Object?>(
      'recognizeLatin',
      {'path': imagePath},
    );
    return (response ?? const <Object?>[])
        .whereType<Map<Object?, Object?>>()
        .map(_decodeLine)
        .toList(growable: false);
  }

  NativeOcrLine _decodeLine(Map<Object?, Object?> value) {
    double coordinate(String key) => (value[key] as num?)?.toDouble() ?? 0;

    return NativeOcrLine(
      text: value['text'] as String? ?? '',
      boundingBox: OcrRect(
        left: coordinate('left'),
        top: coordinate('top'),
        right: coordinate('right'),
        bottom: coordinate('bottom'),
      ),
      confidence: (value['confidence'] as num?)?.toDouble(),
    );
  }
}

/// Android's bundled, fully on-device Latin text recognizer.
///
/// Platform selection happens in [ocrServiceProvider], so this engine's native
/// channel is never invoked by iOS or desktop builds.
class MlKitLatinEngine implements OcrEngine {
  const MlKitLatinEngine({
    this.client = const MethodChannelAndroidLatinOcrClient(),
  });

  final AndroidLatinOcrClient client;

  @override
  String get id => 'mlkit-latin';

  @override
  Set<ScriptHint> get supportedScripts => const {
    ScriptHint.automatic,
    ScriptHint.latin,
    ScriptHint.mixed,
  };

  @override
  Future<OcrResult> recognize(
    PreprocessedImage image, {
    ScriptHint? hint,
  }) async {
    final recognized = await client.recognize(image.colorCorrectedPath);
    final blocks = recognized
        .where((line) => line.text.trim().isNotEmpty)
        .map(
          (line) => OcrBlock(
            text: line.text,
            boundingBox: line.boundingBox,
            confidence: mlKitConfidenceOrFallback(line.confidence),
            script: ScriptDetector.classify(line.text),
            engineId: id,
            pageIndex: image.pageIndex,
          ),
        )
        .toList(growable: false);
    return OcrResult(blocks: blocks, engineIds: {id});
  }
}
