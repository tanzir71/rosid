import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:rosid/ocr/preprocess/document_quad.dart';
import 'package:rosid/ocr/preprocess/image_preprocessor.dart';

void main() {
  const preprocessor = ImagePreprocessor();

  test('detects a high-contrast document rectangle', () {
    final source = image.Image(width: 200, height: 120);
    image.fill(source, color: image.ColorRgb8(25, 25, 25));
    image.fillRect(
      source,
      x1: 24,
      y1: 14,
      x2: 176,
      y2: 106,
      color: image.ColorRgb8(245, 245, 245),
    );

    final quad = preprocessor.detectDocumentQuad(
      Uint8List.fromList(image.encodePng(source)),
    );

    expect(quad.topLeft.x, closeTo(0.12, 0.04));
    expect(quad.topLeft.y, closeTo(0.12, 0.04));
    expect(quad.bottomRight.x, closeTo(0.88, 0.04));
    expect(quad.bottomRight.y, closeTo(0.88, 0.04));
  });

  test('processes the bundled perspective receipt fixture', () {
    final encoded = File(
      'assets/fixtures/english_receipt.png',
    ).readAsBytesSync();
    final quad = preprocessor.detectDocumentQuad(encoded);
    final result = preprocessor.process(
      encoded,
      quad: quad,
      options: const PreprocessOptions(
        minimumDimension: 600,
        maximumDimension: 900,
        deskew: false,
      ),
    );

    expect(quad.isValid, isTrue);
    expect(quad.topLeft.x, lessThan(0.3));
    expect(quad.topLeft.y, lessThan(0.3));
    expect(quad.bottomRight.x, greaterThan(0.7));
    expect(quad.bottomRight.y, greaterThan(0.7));
    expect((quad.topLeft.y - quad.topRight.y).abs(), greaterThan(0.005));
    expect((quad.topRight.x - quad.bottomRight.x).abs(), greaterThan(0.005));
    expect(result.width, inInclusiveRange(600, 900));
    expect(result.height, inInclusiveRange(600, 900));
    expect(image.decodeJpg(result.colorCorrectedJpeg), isNotNull);
    expect(image.decodeJpg(result.binarizedJpeg), isNotNull);
  });

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

  test('warp uses a projective map for a trapezoid', () {
    final source = image.Image(width: 101, height: 101);
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        source.setPixelRgb(x, y, y, 0, 0);
      }
    }
    const trapezoid = DocumentQuad(
      topLeft: NormalizedPoint(0.2, 0.1),
      topRight: NormalizedPoint(0.8, 0.1),
      bottomRight: NormalizedPoint(1, 0.9),
      bottomLeft: NormalizedPoint(0, 0.9),
    );

    final warped = preprocessor.warpQuad(source, trapezoid);
    final center = warped.getPixel(warped.width ~/ 2, warped.height ~/ 2);

    // The source diagonals meet at y=0.4. A bilinear corner interpolation
    // would incorrectly sample y=0.5 at the destination center.
    expect(center.r, closeTo(40, 4));
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

  test('raw planes reproduce the production JPEG inputs exactly', () {
    final encoded = Uint8List.fromList(image.encodePng(fixture()));
    const options = PreprocessOptions(
      minimumDimension: 100,
      maximumDimension: 300,
      deskew: false,
    );
    final planes = preprocessor.processPlanes(encoded, options: options);
    final result = preprocessor.process(encoded, options: options);

    final colorRgb = Uint8List(planes.width * planes.height * 3);
    for (
      var source = 0, target = 0;
      source < planes.colorCorrectedRgba.length;
      source += 4
    ) {
      colorRgb[target++] = planes.colorCorrectedRgba[source];
      colorRgb[target++] = planes.colorCorrectedRgba[source + 1];
      colorRgb[target++] = planes.colorCorrectedRgba[source + 2];
    }
    final binaryRgb = Uint8List(planes.binarizedY8.length * 3);
    for (
      var source = 0, target = 0;
      source < planes.binarizedY8.length;
      source++
    ) {
      final value = planes.binarizedY8[source];
      binaryRgb[target++] = value;
      binaryRgb[target++] = value;
      binaryRgb[target++] = value;
    }
    final color = image.Image.fromBytes(
      width: planes.width,
      height: planes.height,
      bytes: colorRgb.buffer,
      numChannels: 3,
    );
    final binary = image.Image.fromBytes(
      width: planes.width,
      height: planes.height,
      bytes: binaryRgb.buffer,
      numChannels: 3,
    );

    expect(
      result.colorCorrectedJpeg,
      orderedEquals(image.encodeJpg(color, quality: 92)),
    );
    expect(
      result.binarizedJpeg,
      orderedEquals(image.encodeJpg(binary, quality: 95)),
    );
    expect(result.deskewAngle, planes.deskewAngle);
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

  test('minimum upscale never breaks the maximum dimension', () {
    final encoded = Uint8List.fromList(
      image.encodeJpg(fixture(width: 20, height: 200)),
    );
    final result = preprocessor.process(
      encoded,
      options: const PreprocessOptions(
        minimumDimension: 100,
        maximumDimension: 150,
        deskew: false,
      ),
    );

    expect(result.width, lessThanOrEqualTo(150));
    expect(result.height, lessThanOrEqualTo(150));
  });
}
