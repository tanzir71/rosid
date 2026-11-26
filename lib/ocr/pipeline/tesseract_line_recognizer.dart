import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:rosid/ocr/engines/tesseract_bn.dart';
import 'package:rosid/ocr/engines/tesseract_hocr_parser.dart';
import 'package:rosid/ocr/pipeline/reading_interfaces.dart';
import 'package:rosid/ocr/tessdata_installer.dart';

/// Per-line Bangla/mixed recogniser backed by Tesseract (`psm = 7`).
/// Scales line crops gently to ~56 px with clean white padding so tall Bangla
/// i-kar / u-kar diacritics are never clipped.
class TesseractLineRecognizer implements LineRecognizer {
  const TesseractLineRecognizer({
    this.client = const FlutterTesseractOcrClient(),
    this.installer = const TessdataInstaller(),
    this.language = 'ben',
  });

  final TesseractOcrClient client;
  final TessdataInstaller installer;
  final String language;

  @override
  String get id => 'tesseract-line-$language';

  @override
  Future<LineRecognition> recognize(img.Image lineCrop) async {
    return recognizeWithLanguage(lineCrop, language: language);
  }

  Future<LineRecognition> recognizeWithLanguage(
    img.Image lineCrop, {
    required String language,
  }) async {
    if (lineCrop.width < 4 || lineCrop.height < 4) {
      return LineRecognition(text: '', confidence: 0, engineId: id);
    }
    await installer.install();
    final padded = prepareTesseractLineCrop(lineCrop);
    final tmpDir = await getTemporaryDirectory();
    final tmpFile = File(
      '${tmpDir.path}${Platform.pathSeparator}rosid_line_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    try {
      await tmpFile.writeAsBytes(img.encodePng(padded), flush: true);
      const args = {'psm': '7', 'preserve_interword_spaces': '1'};
      final hocr = await client.extractHocr(
        tmpFile.path,
        language: language,
        args: args,
      );
      final blocks = TesseractHocrParser.parse(
        hocr,
        engineId: 'tesseract-line-$language',
        pageIndex: 0,
        imageWidth: padded.width,
        imageHeight: padded.height,
      );
      if (blocks.isEmpty) {
        final plain = await client.extractText(
          tmpFile.path,
          language: language,
          args: args,
        );
        return LineRecognition(
          text: plain.trim(),
          confidence: plain.trim().isEmpty ? 0.0 : 0.65,
          engineId: 'tesseract-line-$language',
        );
      }
      final joined = blocks
          .map((b) => b.text.trim())
          .where((t) => t.isNotEmpty)
          .join(' ');
      final meanConf =
          blocks.fold<double>(0, (s, b) => s + b.confidence) / blocks.length;
      return LineRecognition(
        text: joined,
        confidence: meanConf.clamp(0.0, 1.0),
        engineId: 'tesseract-line-$language',
      );
    } finally {
      try {
        if (await tmpFile.exists()) await tmpFile.delete();
      } on Object {
        // Best-effort temp cleanup.
      }
    }
  }
}

/// Prepares a greyscale line crop for Tesseract `psm 7` (scales to ~52–64 px
/// height and pads with a crisp 16 px white border).
img.Image prepareTesseractLineCrop(img.Image crop) {
  final h = crop.height;
  final w = crop.width;
  final targetH = h <= 68 ? (h < 52 ? 52 : h) : 64;
  final scale = targetH / (h == 0 ? 1 : h);
  final resized = (scale - 1.0).abs() < 0.08
      ? crop
      : img.copyResize(
          crop,
          width: (w * scale).round().clamp(16, 2400),
          height: targetH,
          interpolation: img.Interpolation.cubic,
        );
  const padX = 20;
  const padY = 16;
  final out = img.Image(
    width: resized.width + padX * 2,
    height: resized.height + padY * 2,
  );
  img.fill(out, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(out, resized, dstX: padX, dstY: padY);
  return out;
}
