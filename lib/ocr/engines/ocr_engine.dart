import 'package:rosid/ocr/models/ocr_models.dart';

abstract interface class OcrEngine {
  String get id;
  Set<ScriptHint> get supportedScripts;

  Future<OcrResult> recognize(PreprocessedImage image, {ScriptHint? hint});
}
