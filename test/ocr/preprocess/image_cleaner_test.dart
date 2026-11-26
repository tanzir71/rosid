import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:rosid/ocr/preprocess/document_quad.dart';
import 'package:rosid/ocr/preprocess/image_cleaner.dart';

void main() {
  test('ImageCleaner evens out shadow gradient, runs CLAHE and respects 2000px cap', () {
    // Create a synthetic unevenly lit document: left half bright (235), right half
    // in deep shadow (125), with dark text bars across both halves.
    final src = img.Image(width: 600, height: 800);
    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final paperBg = x < 300 ? 235 : 130;
        final isInk = y >= 120 && y <= 680 && (y % 40 < 6) && x > 60 && x < 540;
        final v = isInk ? (paperBg * 0.25).round() : paperBg;
        src.setPixelRgba(x, y, v, v, v, 255);
      }
    }
    final rawJpg = Uint8List.fromList(img.encodeJpg(src, quality: 92));

    const fullQuad = DocumentQuad(
      topLeft: NormalizedPoint(0, 0),
      topRight: NormalizedPoint(1, 0),
      bottomRight: NormalizedPoint(1, 1),
      bottomLeft: NormalizedPoint(0, 1),
    );
    final result = const ImageCleaner().clean(
      rawJpg,
      quad: fullQuad,
      filter: PageFilterMode.auto,
      deskew: false,
      includeBlackAndWhite: true,
    );

    expect(result.colorCorrectedJpeg, isNotEmpty);
    expect(result.greyJpeg, isNotEmpty);
    expect(result.blackAndWhiteJpeg, isNotNull);
    expect(result.width, lessThanOrEqualTo(2000));
    expect(result.height, lessThanOrEqualTo(2000));

    // Check that shadowed right-side paper background was lifted close to left side.
    final cleaned = img.decodeImage(result.colorCorrectedJpeg)!;
    final leftBg = cleaned.getPixel(120, 40).r.toDouble();
    final rightBg = cleaned.getPixel(480, 40).r.toDouble();
    expect((leftBg - rightBg).abs(), lessThan(35));
  });

  test('ImageCleaner applies rotation quarter turns accurately', () {
    final src = img.Image(width: 400, height: 200);
    img.fill(src, color: img.ColorRgb8(240, 240, 240));
    final raw = Uint8List.fromList(img.encodeJpg(src));

    final rotated = const ImageCleaner().clean(
      raw,
      quad: const DocumentQuad(
        topLeft: NormalizedPoint(0, 0),
        topRight: NormalizedPoint(1, 0),
        bottomRight: NormalizedPoint(1, 1),
        bottomLeft: NormalizedPoint(0, 1),
      ),
      rotationQuarterTurns: 1,
      deskew: false,
    );
    expect(rotated.height, greaterThan(rotated.width));
  });
}
