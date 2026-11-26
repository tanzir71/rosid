import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rosid/ocr/pipeline/onnx_latin_recognizer.dart';
import 'package:rosid/ocr/pipeline/onnx_line_detector.dart';
import 'package:rosid/ocr/pipeline/rosid_reading_pipeline.dart';
import 'package:rosid/ocr/pipeline/tesseract_line_recognizer.dart';

import 'ocr_fixture_bytes.g.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'M3 pipeline reads bundled English, mixed Bangla, and handwritten fixtures',
    (tester) async {
      final det = OnnxLineDetector();
      final latin = OnnxLatinLineRecognizer();
      const bangla = TesseractLineRecognizer();
      addTearDown(() async {
        await det.dispose();
        await latin.dispose();
      });

      final pipeline = RosidReadingPipeline(
        lineDetector: det,
        latinRecognizer: latin,
        banglaRecognizer: bangla,
      );

      // 1. Printed English receipt fixture
      final enBytes = base64Decode(
        ocrFixtureBase64['assets/fixtures/english_receipt.png']!,
      );
      final enRes = await pipeline.readPage(
        greyImageBytes: enBytes,
        pageIndex: 0,
      );
      final enLower = enRes.fullText.toLowerCase();
      expect(enLower, contains('rice'));
      expect(enLower, contains('vat'));
      expect(enLower, contains('80.00'));

      // 2. Mixed Bangla + English fixture
      final mixedBytes = base64Decode(
        ocrFixtureBase64['assets/fixtures/mixed_bangla_receipt.png']!,
      );
      final mixedRes = await pipeline.readPage(
        greyImageBytes: mixedBytes,
        pageIndex: 0,
      );
      expect(mixedRes.fullText.toLowerCase(), contains('rosid'));
      expect(RegExp(r'[\u0980-\u09ff]').hasMatch(mixedRes.fullText), isTrue);

      // 3. Handwritten note fixture (best-effort editable output)
      final hwBytes = base64Decode(
        ocrFixtureBase64['assets/fixtures/handwritten_bangla_note.png']!,
      );
      final hwRes = await pipeline.readPage(
        greyImageBytes: hwBytes,
        pageIndex: 0,
      );
      expect(hwRes.fullText.trim(), isNotEmpty);
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
