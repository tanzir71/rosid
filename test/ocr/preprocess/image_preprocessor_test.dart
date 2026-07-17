import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:rosid/ocr/preprocess/document_quad.dart';
import 'package:rosid/ocr/preprocess/image_preprocessor.dart';

void main() {
  const preprocessor = ImagePreprocessor();

  image.Image fixture({int width = 80, int height = 120}) {
    final value = image.Image(width: width, height: height);
    value.clear(image.ColorRgb8(240, 238, 225));
    for (var y = 20; y < height - 20; y += 14) {
      for (var x = 12; x < width - 12; x++) {
        value.setPixelRgb(x, y, 25, 30, 27);
      }
    }
    return value;
  }

  test('quad default is valid', () {
    expect(const DocumentQuad.inset().isValid, isTrue);
  });

  test('crossed quad is invalid', () {
    const quad = DocumentQuad(
      topLeft: NormalizedPoint(0, 0),
      topRight: NormalizedPoint(0, 1),
      bottomRight: NormalizedPoint(1, 0),
      bottomLeft: NormalizedPoint(1, 1),
    );
    expect(quad.isValid, isFalse);
  });

  test('warp maps quad to rectangular image', () {
    final warped = preprocessor.warpQuad(fixture(), const DocumentQuad.inset());
    expect(warped.width, greaterThan(60));
    expect(warped.height, greaterThan(100));
  });

  test('adaptive threshold emits black and white pixels', () {
    final threshold = preprocessor.adaptiveThreshold(
      preprocessor.grayscale(fixture()),
      windowSize: 15,
      bias: 8,
    );
    final values = threshold.map((pixel) => pixel.r.toInt()).toSet();
    expect(values, containsAll([0, 255]));
  });

  test('processing upscales a small document', () {
    final encoded = Uint8List.fromList(image.encodeJpg(fixture()));
    final result = preprocessor.process(
      encoded,
      options: const PreprocessOptions(
        minimumDimension: 100,
        maximumDimension: 300,
        deskew: false,
      ),
    );
    expect(result.width, greaterThanOrEqualTo(100));
    expect(result.height, greaterThanOrEqualTo(100));
    expect(image.decodeJpg(result.colorCorrectedJpeg), isNotNull);
    expect(image.decodeJpg(result.binarizedJpeg), isNotNull);
  });

  test('processing caps a large document', () {
    final encoded = Uint8List.fromList(
      image.encodeJpg(fixture(width: 400, height: 600)),
    );
    final result = preprocessor.process(
      encoded,
      options: const PreprocessOptions(
        minimumDimension: 50,
        maximumDimension: 200,
        deskew: false,
      ),
    );
    expect(result.height, lessThanOrEqualTo(200));
  });
}
