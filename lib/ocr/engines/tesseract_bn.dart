import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:rosid/ocr/engines/ocr_engine.dart';
import 'package:rosid/ocr/models/ocr_models.dart';
import 'package:rosid/ocr/script_detect.dart';

class TesseractBanglaEngine implements OcrEngine {
  const TesseractBanglaEngine();

  @override
  String get id => 'tesseract-ben-eng';

  @override
  Set<ScriptHint> get supportedScripts => const {
    ScriptHint.bangla,
    ScriptHint.latin,
    ScriptHint.mixed,
    ScriptHint.banglaHandwriting,
  };

  @override
  Future<OcrResult> recognize(
    PreprocessedImage image, {
    ScriptHint? hint,
  }) async {
    final text = await FlutterTesseractOcr.extractText(
      image.binarizedPath,
      language: 'ben+eng',
      args: const {'preserve_interword_spaces': '1', 'psm': '6'},
    );
    final lines = text
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .toList();
    final lineHeight = image.height / (lines.isEmpty ? 1 : lines.length);
    final blocks = <OcrBlock>[];
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index].trim();
      blocks.add(
        OcrBlock(
          text: line,
          boundingBox: OcrRect(
            left: 0,
            top: index * lineHeight,
            right: image.width.toDouble(),
            bottom: (index + 1) * lineHeight,
          ),
          confidence: ScriptDetector.nonWordRatio(line) > 0.25 ? 0.42 : 0.68,
          script: ScriptDetector.classify(line),
          engineId: id,
          pageIndex: image.pageIndex,
        ),
      );
    }
    return OcrResult(blocks: blocks, engineIds: {id});
  }
}
