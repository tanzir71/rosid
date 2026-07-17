import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:rosid/ocr/engines/ocr_engine.dart';
import 'package:rosid/ocr/models/ocr_models.dart';
import 'package:rosid/ocr/script_detect.dart';

class MlKitLatinEngine implements OcrEngine {
  MlKitLatinEngine()
    : _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

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
    final recognized = await _recognizer.processImage(
      InputImage.fromFilePath(image.colorCorrectedPath),
    );
    final blocks = recognized.blocks.map((block) {
      final lineConfidences = block.lines
          .map((line) => line.confidence)
          .whereType<double>()
          .toList();
      final confidence = lineConfidences.isEmpty
          ? 0.78
          : lineConfidences.reduce((a, b) => a + b) / lineConfidences.length;
      return OcrBlock(
        text: block.text,
        boundingBox: OcrRect(
          left: block.boundingBox.left,
          top: block.boundingBox.top,
          right: block.boundingBox.right,
          bottom: block.boundingBox.bottom,
        ),
        confidence: confidence.clamp(0, 1),
        script: ScriptDetector.classify(block.text),
        engineId: id,
        pageIndex: image.pageIndex,
      );
    }).toList();
    return OcrResult(blocks: blocks, engineIds: {id});
  }

  Future<void> close() => _recognizer.close();
}
