import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Composes front and back scans of an ID card (ISO/IEC 7810 ID-1: 85.6 x 54 mm)
/// onto a single A4 sheet (210 x 297 mm) at true physical card scale.
class IdCardComposer {
  const IdCardComposer();

  static const double a4WidthMm = 210.0;
  static const double a4HeightMm = 297.0;
  static const double cardWidthMm = 85.6;
  static const double cardHeightMm = 54.0;

  /// Composes [frontBytes] and [backBytes] onto a white A4 JPEG at [dpi]
  /// (defaults to 200 DPI -> 1654 x 2339 px; card = 674 x 425 px).
  Uint8List composeA4Jpeg({
    required Uint8List frontBytes,
    required Uint8List backBytes,
    int dpi = 200,
    bool blackAndWhite = false,
  }) {
    final front = _decodeCard(frontBytes);
    final back = _decodeCard(backBytes);

    final pageWidth = (a4WidthMm / 25.4 * dpi).round();
    final pageHeight = (a4HeightMm / 25.4 * dpi).round();
    final cardWidth = (cardWidthMm / 25.4 * dpi).round();
    final cardHeight = (cardHeightMm / 25.4 * dpi).round();

    final canvas = img.Image(width: pageWidth, height: pageHeight);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));

    final fittedFront = _fitCard(front, cardWidth, cardHeight);
    final fittedBack = _fitCard(back, cardWidth, cardHeight);

    final x = (pageWidth - cardWidth) ~/ 2;
    final topY = (pageHeight * 0.16).round();
    final gap = (24.0 / 25.4 * dpi).round(); // 24 mm clean vertical spacing
    final bottomY = topY + cardHeight + gap;

    img.compositeImage(canvas, fittedFront, dstX: x, dstY: topY);
    img.compositeImage(canvas, fittedBack, dstX: x, dstY: bottomY);

    // Subtle 1px light grey outline around both cards for crisp cutting/printing.
    final border = img.ColorRgb8(205, 208, 200);
    img.drawRect(
      canvas,
      x1: x - 1,
      y1: topY - 1,
      x2: x + cardWidth,
      y2: topY + cardHeight,
      color: border,
    );
    img.drawRect(
      canvas,
      x1: x - 1,
      y1: bottomY - 1,
      x2: x + cardWidth,
      y2: bottomY + cardHeight,
      color: border,
    );

    final finalImage = blackAndWhite ? img.grayscale(canvas) : canvas;
    return Uint8List.fromList(img.encodeJpg(finalImage, quality: 92));
  }

  img.Image _decodeCard(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Unable to decode ID card image.');
    }
    var oriented = img.bakeOrientation(decoded);
    // Rotate portrait card photo to landscape ID-1 orientation.
    if (oriented.height > oriented.width) {
      oriented = img.copyRotate(oriented, angle: 90);
    }
    return oriented;
  }

  img.Image _fitCard(img.Image source, int targetW, int targetH) {
    return img.copyResize(
      source,
      width: targetW,
      height: targetH,
      interpolation: img.Interpolation.linear,
    );
  }
}
