import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rosid/ocr/engines/tesseract_bn.dart';
import 'package:rosid/ocr/models/ocr_models.dart';

void main() {
  const page = PreprocessedImage(
    colorCorrectedPath: '/tmp/color.jpg',
    binarizedPath: '/tmp/binary.jpg',
    width: 800,
    height: 1200,
    pageIndex: 2,
  );

  test(
    'iOS fallback uses plain text and creates ordered line blocks',
    () async {
      final client = _FakeClient(text: 'মোট ২৬২.৫০\nROSID TEST MART');
      final result = await TesseractBanglaEngine(
        client: client,
        useHocr: false,
      ).recognize(page);

      expect(client.textCalls, 1);
      expect(client.hocrCalls, 0);
      expect(result.text, 'মোট ২৬২.৫০\nROSID TEST MART');
      expect(result.blocks, hasLength(2));
      expect(result.blocks.first.pageIndex, 2);
      expect(result.blocks.first.boundingBox.top, 0);
      expect(result.blocks.last.boundingBox.bottom, 1200);
    },
  );

  test('Android path retains hOCR geometry and confidence', () async {
    final client = _FakeClient(
      hocr: '''
        <span class="ocr_line" title="bbox 10 20 300 80">
          <span class="ocrx_word" title="bbox 10 20 100 80; x_wconf 91">Total</span>
        </span>
      ''',
    );
    final result = await TesseractBanglaEngine(
      client: client,
      useHocr: true,
    ).recognize(page);

    expect(client.hocrCalls, 1);
    expect(client.textCalls, 0);
    expect(result.blocks.single.text, 'Total');
    expect(result.blocks.single.confidence, closeTo(0.91, 0.001));
  });

  test('a native call that never completes fails with a typed timeout', () {
    final client = _FakeClient(hocrFuture: Completer<String>().future);
    expect(
      TesseractBanglaEngine(
        client: client,
        useHocr: true,
        timeout: Duration.zero,
      ).recognize(page),
      throwsA(isA<TesseractOcrTimeoutException>()),
    );
  });
}

class _FakeClient implements TesseractOcrClient {
  _FakeClient({this.hocr = '', this.text = '', this.hocrFuture});

  final String hocr;
  final String text;
  final Future<String>? hocrFuture;
  var hocrCalls = 0;
  var textCalls = 0;

  @override
  Future<String> extractHocr(
    String imagePath, {
    required String language,
    required Map<String, String> args,
  }) {
    hocrCalls++;
    return hocrFuture ?? Future.value(hocr);
  }

  @override
  Future<String> extractText(
    String imagePath, {
    required String language,
    required Map<String, String> args,
  }) async {
    textCalls++;
    return text;
  }
}
