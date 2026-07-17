import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:rosid/ocr/engines/mlkit_latin.dart';
import 'package:rosid/ocr/engines/tesseract_bn.dart';
import 'package:rosid/ocr/models/ocr_models.dart';
import 'package:rosid/ocr/ocr_service.dart';
import 'package:rosid/ocr/preprocess/image_preprocessor.dart';
import 'package:rosid/ocr/tessdata_installer.dart';

import 'ocr_fixture_bytes.g.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'ML Kit recognizes the English printed fixture',
    (tester) async {
      final page = await _prepareFixture('assets/fixtures/english_receipt.png');
      final engine = MlKitLatinEngine();
      try {
        final result = await engine.recognize(page);
        final normalized = result.text.toLowerCase();

        expect(result.engineIds, contains('mlkit-latin'));
        expect(normalized, contains('rice'));
        expect(normalized, contains('vat'));
        expect(normalized, contains('80.00'));
      } finally {
        await engine.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  testWidgets(
    'mixed hint routes through ML Kit and bundled Bangla Tesseract',
    (tester) async {
      final page = await _prepareFixture(
        'assets/fixtures/mixed_bangla_receipt.png',
      );
      final latin = MlKitLatinEngine();
      try {
        final service = OcrService(
          latinEngine: latin,
          banglaEngine: const TesseractBanglaEngine(),
          handwritingEngine: const TesseractBanglaEngine(),
          tessdataInstaller: const TessdataInstaller(),
        );
        final result = await service.recognize([page], hint: ScriptHint.mixed);
        final normalized = result.text.toLowerCase();

        expect(
          result.engineIds,
          containsAll(['mlkit-latin', 'tesseract-ben-eng']),
        );
        expect(normalized, contains('rosid'));
        expect(
          RegExp(r'[\u0980-\u09ff]').hasMatch(result.text),
          isTrue,
          reason: 'The mixed printed fixture must produce Bangla OCR text.',
        );
      } finally {
        await latin.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  testWidgets(
    'Tesseract returns editable text for the handwritten document fixture',
    (tester) async {
      final page = await _prepareFixture(
        'assets/fixtures/handwritten_bangla_note.png',
      );
      final result = await const TesseractBanglaEngine().recognize(page);
      final normalized = result.text.toLowerCase();

      expect(result.engineIds, contains('tesseract-ben-eng'));
      expect(normalized.trim(), isNotEmpty);
      expect(
        normalized.contains('project') ||
            RegExp(r'[\u0980-\u09ff]').hasMatch(result.text),
        isTrue,
        reason: 'Best-effort handwriting OCR should preserve editable content.',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<PreprocessedImage> _prepareFixture(String asset) async {
  final encoded = ocrFixtureBase64[asset];
  expect(encoded, isNotNull, reason: '$asset is missing from the test bundle');
  final bytes = base64Decode(encoded!);
  final decoded = image.decodeImage(bytes);
  expect(decoded, isNotNull, reason: '$asset must remain a decodable image');

  const preprocessor = ImagePreprocessor();
  final quad = preprocessor.detectDocumentQuad(bytes);
  final processed = preprocessor.process(
    bytes,
    quad: quad,
    options: const PreprocessOptions(
      minimumDimension: 1000,
      maximumDimension: 1800,
    ),
  );
  final directory = await getTemporaryDirectory();
  final stem = path.basenameWithoutExtension(asset);
  final color = File(path.join(directory.path, '$stem-color.jpg'));
  final binary = File(path.join(directory.path, '$stem-binary.jpg'));
  await Future.wait([
    color.writeAsBytes(processed.colorCorrectedJpeg, flush: true),
    binary.writeAsBytes(processed.binarizedJpeg, flush: true),
  ]);
  return PreprocessedImage(
    colorCorrectedPath: color.path,
    binarizedPath: binary.path,
    width: processed.width,
    height: processed.height,
  );
}
