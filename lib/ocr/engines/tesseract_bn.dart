import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rosid/ocr/engines/ocr_engine.dart';
import 'package:rosid/ocr/engines/tesseract_hocr_parser.dart';
import 'package:rosid/ocr/models/ocr_models.dart';
import 'package:rosid/ocr/script_detect.dart';
import 'package:rosid/ocr/tessdata_installer.dart';
import 'package:tesseract_ocr/ocr_engine_config.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';

abstract interface class TesseractOcrClient {
  Future<String> extractHocr(
    String imagePath, {
    required String language,
    required Map<String, String> args,
  });

  Future<String> extractText(
    String imagePath, {
    required String language,
    required Map<String, String> args,
  });
}

class FlutterTesseractOcrClient implements TesseractOcrClient {
  const FlutterTesseractOcrClient();

  static const MethodChannel _channel = MethodChannel('tesseract_ocr');

  @override
  Future<String> extractHocr(
    String imagePath, {
    required String language,
    required Map<String, String> args,
  }) async {
    await const TessdataInstaller().install();
    final root = await getApplicationDocumentsDirectory();
    final hocr = await _channel.invokeMethod<String>('extractHocr', {
      'imagePath': imagePath,
      'tessData': root.path,
      'language': language,
      'engine': 'tesseract',
      'options': args,
    });
    return hocr ?? '';
  }

  @override
  Future<String> extractText(
    String imagePath, {
    required String language,
    required Map<String, String> args,
  }) => TesseractOcr.extractText(
    imagePath,
    config: OCRConfig(
      language: language,
      engine: OCREngine.tesseract,
      options: args,
    ),
  );
}

class TesseractOcrTimeoutException implements Exception {
  const TesseractOcrTimeoutException(this.platform);

  final String platform;

  @override
  String toString() => 'Tesseract OCR timed out on $platform.';
}

class TesseractBanglaEngine implements OcrEngine {
  const TesseractBanglaEngine({
    this.client = const FlutterTesseractOcrClient(),
    this.useHocr,
    this.timeout = const Duration(minutes: 2),
  });

  final TesseractOcrClient client;

  /// Override used by tests. The upstream iOS plugin does not implement its
  /// `extractHocr` channel method, so production iOS must use plain text.
  final bool? useHocr;
  final Duration timeout;

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
    const args = {'preserve_interword_spaces': '1', 'psm': '6'};
    final shouldUseHocr = useHocr ?? !Platform.isIOS;
    try {
      if (shouldUseHocr) {
        final hocr = await client
            .extractHocr(image.binarizedPath, language: 'ben+eng', args: args)
            .timeout(timeout);
        final blocks = TesseractHocrParser.parse(
          hocr,
          engineId: id,
          pageIndex: image.pageIndex,
          imageWidth: image.width,
          imageHeight: image.height,
        );
        return OcrResult(blocks: blocks, engineIds: {id});
      }

      final text = await client
          .extractText(image.binarizedPath, language: 'ben+eng', args: args)
          .timeout(timeout);
      return OcrResult(blocks: _plainTextBlocks(text, image), engineIds: {id});
    } on TimeoutException {
      throw TesseractOcrTimeoutException(shouldUseHocr ? 'Android' : 'iOS');
    }
  }

  List<OcrBlock> _plainTextBlocks(String text, PreprocessedImage image) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) return const [];
    final lineHeight = image.height / lines.length;
    return [
      for (var index = 0; index < lines.length; index++)
        OcrBlock(
          text: lines[index],
          boundingBox: OcrRect(
            left: 0,
            top: index * lineHeight,
            right: image.width.toDouble(),
            bottom: (index + 1) * lineHeight,
          ),
          // The iOS plugin exposes no native confidence or geometry. Keep the
          // fallback visibly reviewable instead of inventing high certainty.
          confidence: 0.4,
          script: ScriptDetector.classify(lines[index]),
          engineId: id,
          pageIndex: image.pageIndex,
        ),
    ];
  }
}
