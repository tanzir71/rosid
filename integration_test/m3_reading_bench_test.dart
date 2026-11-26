import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:rosid/ocr/pipeline/onnx_latin_recognizer.dart';
import 'package:rosid/ocr/pipeline/onnx_line_detector.dart';
import 'package:rosid/ocr/pipeline/rosid_reading_pipeline.dart';
import 'package:rosid/ocr/pipeline/tesseract_line_recognizer.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'M3 emulator benchmark: ONNX PP-OCRv5 det + en rec + Tesseract ben on real device',
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

      // Load bundled sample receipt/document fixtures OR synthesize crisp test
      // pages so we verify real ONNX + Tesseract execution & timing on Android.
      final enPage = img.Image(width: 640, height: 320);
      img.fill(enPage, color: img.ColorRgb8(250, 250, 248));
      img.drawString(
        enPage,
        'Shwapno Super Shop',
        font: img.arial24,
        x: 40,
        y: 32,
        color: img.ColorRgb8(20, 20, 24),
      );
      img.drawString(
        enPage,
        'Date: 15/11/2026',
        font: img.arial24,
        x: 40,
        y: 88,
        color: img.ColorRgb8(20, 20, 24),
      );
      img.drawString(
        enPage,
        'Miniket Rice 5kg  380.00',
        font: img.arial24,
        x: 40,
        y: 144,
        color: img.ColorRgb8(20, 20, 24),
      );
      img.drawString(
        enPage,
        'Grand Total  399.00',
        font: img.arial24,
        x: 40,
        y: 204,
        color: img.ColorRgb8(20, 20, 24),
      );
      final enBytes = Uint8List.fromList(img.encodePng(enPage));

      // Warm up ONNX sessions once (first-time asset extraction + ORT init).
      final warm = await pipeline.readPage(
        greyImageBytes: enBytes,
        pageIndex: 0,
      );
      expect(warm.lines, isNotEmpty);
      expect(warm.fullText.toLowerCase(), contains('total'));

      // Measure 5 timed runs on rosid_test to get real median page time.
      final timesMs = <int>[];
      for (var i = 0; i < 5; i++) {
        final res = await pipeline.readPage(
          greyImageBytes: enBytes,
          pageIndex: i,
        );
        expect(res.lines, isNotEmpty);
        for (final ln in res.lines) {
          expect(ln.confidence, greaterThan(0));
          expect(ln.box.boundingRect.area, greaterThan(0));
        }
        timesMs.add(res.elapsedMs);
      }
      timesMs.sort();
      final medianMs = timesMs[timesMs.length ~/ 2];
      final rssMb = ProcessInfo.currentRss / (1024 * 1024);
      // ignore: avoid_print
      print(
        '[M3_EMULATOR_BENCH] median_page_ms=$medianMs '
        'samples=$timesMs rss_mb=${rssMb.toStringAsFixed(1)} '
        'text="${warm.fullText.replaceAll('\n', ' | ')}"',
      );
      expect(medianMs, lessThanOrEqualTo(4000));
    },
  );
}
