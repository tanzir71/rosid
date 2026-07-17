import 'package:rosid/ocr/engines/ocr_engine.dart';
import 'package:rosid/ocr/models/ocr_models.dart';

class TfliteBanglaHandwritingEngine implements OcrEngine {
  const TfliteBanglaHandwritingEngine();

  bool get enabled => false;

  @override
  String get id => 'tflite-bangla-handwriting-v2';

  @override
  Set<ScriptHint> get supportedScripts => const {ScriptHint.banglaHandwriting};

  @override
  Future<OcrResult> recognize(PreprocessedImage image, {ScriptHint? hint}) {
    throw UnimplementedError(
      'The Bangla handwriting model is delivered in V2.',
    );
  }
}
