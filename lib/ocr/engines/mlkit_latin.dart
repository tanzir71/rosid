import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:rosid/ocr/engines/ocr_engine.dart';
import 'package:rosid/ocr/models/ocr_models.dart';
import 'package:rosid/ocr/script_detect.dart';

double mlKitConfidenceOrFallback(double? confidence) =>
    (confidence ?? 0.55).clamp(0, 1).toDouble();

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
    final blocks = recognized.blocks.expand((block) {
      final lines = block.lines;
      if (lines.isEmpty) {
        return [
          OcrBlock(
            text: block.text,
            boundingBox: OcrRect(
              left: block.boundingBox.left,
              top: block.boundingBox.top,
              right: block.boundingBox.right,
              bottom: block.boundingBox.bottom,
            ),
            confidence: mlKitConfidenceOrFallback(null),
            script: ScriptDetector.classify(block.text),
            engineId: id,
            pageIndex: image.pageIndex,
          ),
        ];
      }
      return lines.map(
        (line) => OcrBlock(
          text: line.text,
          boundingBox: OcrRect(
            left: line.boundingBox.left,
            top: line.boundingBox.top,
            right: line.boundingBox.right,
            bottom: line.boundingBox.bottom,
          ),
          confidence: mlKitConfidenceOrFallback(line.confidence),
          script: ScriptDetector.classify(line.text),
          engineId: id,
          pageIndex: image.pageIndex,
        ),
      );
    }).toList();
    return OcrResult(blocks: blocks, engineIds: {id});
  }

  Future<void> close() => _recognizer.close();
}
