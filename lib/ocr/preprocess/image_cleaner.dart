import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:rosid/ocr/preprocess/document_quad.dart';
import 'package:rosid/ocr/preprocess/image_preprocessor.dart';

/// Filter options presented on Adjust page (`scan-adjust-page.png`).
enum PageFilterMode {
  auto('auto'),
  original('original'),
  grey('grey'),
  blackAndWhite('bw');

  const PageFilterMode(this.id);

  final String id;

  static PageFilterMode byId(String value) {
    for (final mode in values) {
      if (mode.id == value) return mode;
    }
    return PageFilterMode.auto;
  }
}

/// Output of the M2 cleaning pipeline: colour-corrected + CLAHE grey version
/// (fed to OCR recognisers) and optional black-and-white export filter.
class CleanedPageResult {
  const CleanedPageResult({
    required this.colorCorrectedJpeg,
    required this.greyJpeg,
    required this.width,
    required this.height,
    required this.deskewAngle,
    this.blackAndWhiteJpeg,
  });

  final Uint8List colorCorrectedJpeg;
  final Uint8List greyJpeg;
  final Uint8List? blackAndWhiteJpeg;
  final int width;
  final int height;
  final double deskewAngle;
}

/// M2 cleaning pipeline: perspective warp -> uneven lighting division ->
/// CLAHE (clip 2.0, 8x8 tiles) -> light denoise -> deskew.
/// Runs cleanly in pure Dart at <= 2,000 px working resolution (documented M2
/// fallback when `opencv_dart` CMake build fails on host).
class ImageCleaner {
  const ImageCleaner({this.maxWorkingDimension = 2000});

  final int maxWorkingDimension;
  static const _legacy = ImagePreprocessor();

  CleanedPageResult clean(
    Uint8List originalBytes, {
    DocumentQuad quad = const DocumentQuad.inset(),
    int rotationQuarterTurns = 0,
    PageFilterMode filter = PageFilterMode.auto,
    bool deskew = true,
    bool includeBlackAndWhite = false,
  }) {
    var decoded = img.decodeImage(originalBytes);
    if (decoded == null) {
      throw const FormatException('Unable to decode captured image.');
    }
    decoded = img.bakeOrientation(decoded);

    // Cap working resolution at 2,000 px on the longest side.
    final longest = math.max(decoded.width, decoded.height);
    if (longest > maxWorkingDimension) {
      final scale = maxWorkingDimension / longest;
      decoded = img.copyResize(
        decoded,
        width: (decoded.width * scale).round(),
        height: (decoded.height * scale).round(),
        interpolation: img.Interpolation.linear,
      );
    }

    // 1. Perspective warp to quad.
    var warped = _legacy.warpQuad(
      decoded,
      quad.isValid ? quad : const DocumentQuad.inset(),
      maximumDimension: maxWorkingDimension,
    );

    // 2. Apply user quarter-turn rotation.
    final turns = ((rotationQuarterTurns % 4) + 4) % 4;
    if (turns != 0) {
      warped = img.copyRotate(
        warped,
        angle: 90 * turns,
        interpolation: img.Interpolation.linear,
      );
    }

    // 3. Even out lighting (divide by large background estimate) + light denoise.
    final colorCleaned = filter == PageFilterMode.original
        ? img.Image.from(warped)
        : _evenOutLightingColor(warped);

    // 4. Greyscale + CLAHE (clip 2.0, 8x8 tiles) + light 3x3 denoise for OCR.
    var grey = _legacy.grayscale(colorCleaned);
    grey = applyClahe(grey, clipLimit: 2.0, tilesX: 8, tilesY: 8);
    grey = _lightDenoise(grey);

    // 5. Deskew if angle >= 0.5 deg.
    var deskewAngle = 0.0;
    var finalColor = colorCleaned;
    if (deskew) {
      final binaryProbe = _legacy.adaptiveThreshold(
        grey,
        windowSize: 25,
        bias: 10,
      );
      deskewAngle = _legacy.estimateSkewAngle(binaryProbe);
      if (deskewAngle.abs() >= 0.5) {
        finalColor = img.copyRotate(
          finalColor,
          angle: -deskewAngle,
          interpolation: img.Interpolation.linear,
        );
        grey = img.copyRotate(
          grey,
          angle: -deskewAngle,
          interpolation: img.Interpolation.linear,
        );
      }
    }

    Uint8List? bwBytes;
    if (includeBlackAndWhite || filter == PageFilterMode.blackAndWhite) {
      final bw = _legacy.adaptiveThreshold(grey, windowSize: 31, bias: 12);
      bwBytes = Uint8List.fromList(img.encodeJpg(bw, quality: 92));
    }

    final displayColor = switch (filter) {
      PageFilterMode.original => warped,
      PageFilterMode.grey => grey,
      PageFilterMode.blackAndWhite => _legacy.adaptiveThreshold(
        grey,
        windowSize: 31,
        bias: 12,
      ),
      PageFilterMode.auto => finalColor,
    };

    return CleanedPageResult(
      colorCorrectedJpeg: Uint8List.fromList(
        img.encodeJpg(displayColor, quality: 90),
      ),
      greyJpeg: Uint8List.fromList(img.encodeJpg(grey, quality: 92)),
      blackAndWhiteJpeg: bwBytes,
      width: grey.width,
      height: grey.height,
      deskewAngle: deskewAngle,
    );
  }

  /// Estimates uneven background illumination at 1/8 scale using a wide blur
  /// and divides the full-resolution image by it to remove shadows cleanly.
  img.Image _evenOutLightingColor(img.Image src) {
    final sw = math.max(8, src.width ~/ 8);
    final sh = math.max(8, src.height ~/ 8);
    final small = img.copyResize(
      src,
      width: sw,
      height: sh,
      interpolation: img.Interpolation.average,
    );
    // Morphological-like bright dilation (max filter 5x5) removes dark text ink
    // from the background illumination estimate.
    final dilated = _dilateMax(small, radius: 3);
    final bgSmall = img.gaussianBlur(dilated, radius: 5);
    final bg = img.copyResize(
      bgSmall,
      width: src.width,
      height: src.height,
      interpolation: img.Interpolation.linear,
    );

    final out = img.Image(width: src.width, height: src.height);
    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final p = src.getPixel(x, y);
        final b = bg.getPixel(x, y);
        final nr = _divideChannel(p.r, b.r);
        final ng = _divideChannel(p.g, b.g);
        final nb = _divideChannel(p.b, b.b);
        out.setPixelRgba(x, y, nr, ng, nb, 255);
      }
    }
    return _legacy.normalizeContrast(out);
  }

  int _divideChannel(num fg, num bg) {
    final safeBg = math.max(40.0, bg.toDouble());
    return ((fg.toDouble() / safeBg) * 245.0).round().clamp(0, 255);
  }

  img.Image _dilateMax(img.Image src, {int radius = 3}) {
    final w = src.width;
    final h = src.height;
    final out = img.Image(width: w, height: h);
    for (var y = 0; y < h; y++) {
      final y0 = math.max(0, y - radius);
      final y1 = math.min(h - 1, y + radius);
      for (var x = 0; x < w; x++) {
        final x0 = math.max(0, x - radius);
        final x1 = math.min(w - 1, x + radius);
        var mr = 0;
        var mg = 0;
        var mb = 0;
        for (var ky = y0; ky <= y1; ky++) {
          for (var kx = x0; kx <= x1; kx++) {
            final p = src.getPixel(kx, ky);
            if (p.r > mr) mr = p.r.toInt();
            if (p.g > mg) mg = p.g.toInt();
            if (p.b > mb) mb = p.b.toInt();
          }
        }
        out.setPixelRgba(x, y, mr, mg, mb, 255);
      }
    }
    return out;
  }

  /// Contrast-Limited Adaptive Histogram Equalization (CLAHE) with bilinear
  /// tile interpolation (clipLimit 2.0, 8x8 tiles).
  img.Image applyClahe(
    img.Image grey, {
    double clipLimit = 2.0,
    int tilesX = 8,
    int tilesY = 8,
  }) {
    final w = grey.width;
    final h = grey.height;
    if (w < tilesX * 2 || h < tilesY * 2) return img.Image.from(grey);

    final tileW = w / tilesX;
    final tileH = h / tilesY;
    final luts = List<List<Uint8List>>.generate(
      tilesY,
      (_) => List<Uint8List>.generate(tilesX, (_) => Uint8List(256)),
    );

    for (var ty = 0; ty < tilesY; ty++) {
      final y0 = (ty * tileH).floor();
      final y1 = ty == tilesY - 1 ? h : ((ty + 1) * tileH).floor();
      for (var tx = 0; tx < tilesX; tx++) {
        final x0 = (tx * tileW).floor();
        final x1 = tx == tilesX - 1 ? w : ((tx + 1) * tileW).floor();
        final hist = Int32List(256);
        var count = 0;
        for (var y = y0; y < y1; y++) {
          for (var x = x0; x < x1; x++) {
            hist[grey.getPixel(x, y).r.toInt().clamp(0, 255)]++;
            count++;
          }
        }
        if (count == 0) continue;

        final limit = math.max(1, (clipLimit * count / 256.0).round());
        var excess = 0;
        for (var i = 0; i < 256; i++) {
          if (hist[i] > limit) {
            excess += hist[i] - limit;
            hist[i] = limit;
          }
        }
        final bonus = excess ~/ 256;
        final rem = excess % 256;
        for (var i = 0; i < 256; i++) {
          hist[i] += bonus + (i < rem ? 1 : 0);
        }

        final lut = luts[ty][tx];
        var cdf = 0;
        for (var i = 0; i < 256; i++) {
          cdf += hist[i];
          lut[i] = ((cdf * 255) / count).round().clamp(0, 255);
        }
      }
    }

    final out = img.Image(width: w, height: h);
    for (var y = 0; y < h; y++) {
      final fy = ((y + 0.5) / tileH) - 0.5;
      final ty0 = fy.floor().clamp(0, tilesY - 1);
      final ty1 = (ty0 + 1).clamp(0, tilesY - 1);
      final wy = (fy - ty0).clamp(0.0, 1.0);
      for (var x = 0; x < w; x++) {
        final fx = ((x + 0.5) / tileW) - 0.5;
        final tx0 = fx.floor().clamp(0, tilesX - 1);
        final tx1 = (tx0 + 1).clamp(0, tilesX - 1);
        final wx = (fx - tx0).clamp(0.0, 1.0);
        final v = grey.getPixel(x, y).r.toInt().clamp(0, 255);

        final top = luts[ty0][tx0][v] * (1.0 - wx) + luts[ty0][tx1][v] * wx;
        final bot = luts[ty1][tx0][v] * (1.0 - wx) + luts[ty1][tx1][v] * wx;
        final mapped = (top * (1.0 - wy) + bot * wy).round().clamp(0, 255);
        out.setPixelRgba(x, y, mapped, mapped, mapped, 255);
      }
    }
    return out;
  }

  /// Edge-preserving light denoise (weighted 3x3 smoothing that preserves sharp
  /// ink strokes while reducing paper grain).
  img.Image _lightDenoise(img.Image grey) {
    final w = grey.width;
    final h = grey.height;
    final out = img.Image.from(grey);
    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final center = grey.getPixel(x, y).r.toInt();
        var sum = center * 4;
        var weight = 4;
        for (final (dx, dy) in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
          final n = grey.getPixel(x + dx, y + dy).r.toInt();
          if ((n - center).abs() < 24) {
            sum += n;
            weight++;
          }
        }
        final v = (sum / weight).round().clamp(0, 255);
        out.setPixelRgba(x, y, v, v, v, 255);
      }
    }
    return out;
  }
}
