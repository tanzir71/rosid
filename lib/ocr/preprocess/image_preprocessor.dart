import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as image;
import 'package:rosid/ocr/preprocess/document_quad.dart';

class PreprocessOptions {
  const PreprocessOptions({
    this.minimumDimension = 1000,
    this.maximumDimension = 3200,
    this.adaptiveWindow = 31,
    this.thresholdBias = 12,
    this.deskew = true,
    this.rotationQuarterTurns = 0,
  });

  final int minimumDimension;
  final int maximumDimension;
  final int adaptiveWindow;
  final int thresholdBias;
  final bool deskew;
  final int rotationQuarterTurns;
}

class PreprocessResult {
  const PreprocessResult({
    required this.colorCorrectedJpeg,
    required this.binarizedJpeg,
    required this.width,
    required this.height,
    required this.deskewAngle,
  });

  final Uint8List colorCorrectedJpeg;
  final Uint8List binarizedJpeg;
  final int width;
  final int height;
  final double deskewAngle;
}

class ImagePreprocessor {
  const ImagePreprocessor();

  PreprocessResult process(
    Uint8List encoded, {
    DocumentQuad quad = const DocumentQuad.inset(),
    PreprocessOptions options = const PreprocessOptions(),
  }) {
    var source = image.decodeImage(encoded);
    if (source == null) throw const FormatException('Unsupported image');
    source = image.bakeOrientation(source);
    source = _capSize(source, options.maximumDimension);

    var corrected = warpQuad(
      source,
      quad.isValid ? quad : const DocumentQuad.inset(),
    );
    if (options.rotationQuarterTurns % 4 != 0) {
      corrected = image.copyRotate(
        corrected,
        angle: 90 * (options.rotationQuarterTurns % 4),
        interpolation: image.Interpolation.linear,
      );
    }
    corrected = _ensureMinimum(corrected, options.minimumDimension);
    corrected = normalizeContrast(corrected);

    var gray = grayscale(corrected);
    var binary = adaptiveThreshold(
      gray,
      windowSize: options.adaptiveWindow,
      bias: options.thresholdBias,
    );
    var angle = 0.0;
    if (options.deskew) {
      angle = estimateSkewAngle(binary);
      if (angle.abs() >= 0.5) {
        corrected = image.copyRotate(
          corrected,
          angle: -angle,
          interpolation: image.Interpolation.linear,
        );
        gray = grayscale(corrected);
        binary = adaptiveThreshold(
          gray,
          windowSize: options.adaptiveWindow,
          bias: options.thresholdBias,
        );
      }
    }

    return PreprocessResult(
      colorCorrectedJpeg: Uint8List.fromList(
        image.encodeJpg(corrected, quality: 92),
      ),
      binarizedJpeg: Uint8List.fromList(image.encodeJpg(binary, quality: 95)),
      width: corrected.width,
      height: corrected.height,
      deskewAngle: angle,
    );
  }

  image.Image _capSize(image.Image source, int maximum) {
    final longest = math.max(source.width, source.height);
    if (longest <= maximum) return source;
    final scale = maximum / longest;
    return image.copyResize(
      source,
      width: (source.width * scale).round(),
      height: (source.height * scale).round(),
      interpolation: image.Interpolation.linear,
    );
  }

  image.Image _ensureMinimum(image.Image source, int minimum) {
    final shortest = math.min(source.width, source.height);
    if (shortest >= minimum) return source;
    final scale = minimum / shortest;
    return image.copyResize(
      source,
      width: (source.width * scale).round(),
      height: (source.height * scale).round(),
      interpolation: image.Interpolation.linear,
    );
  }

  image.Image warpQuad(image.Image source, DocumentQuad quad) {
    final width = quad
        .widthFor(source.width, source.height)
        .round()
        .clamp(2, 5000);
    final height = quad
        .heightFor(source.width, source.height)
        .round()
        .clamp(2, 5000);
    final destination = image.Image(width: width, height: height);

    for (var y = 0; y < height; y++) {
      final v = height == 1 ? 0.0 : y / (height - 1);
      for (var x = 0; x < width; x++) {
        final u = width == 1 ? 0.0 : x / (width - 1);
        final topX = _lerp(quad.topLeft.x, quad.topRight.x, u);
        final topY = _lerp(quad.topLeft.y, quad.topRight.y, u);
        final bottomX = _lerp(quad.bottomLeft.x, quad.bottomRight.x, u);
        final bottomY = _lerp(quad.bottomLeft.y, quad.bottomRight.y, u);
        final sourceX = (_lerp(topX, bottomX, v) * (source.width - 1))
            .round()
            .clamp(0, source.width - 1);
        final sourceY = (_lerp(topY, bottomY, v) * (source.height - 1))
            .round()
            .clamp(0, source.height - 1);
        destination.setPixel(x, y, source.getPixel(sourceX, sourceY));
      }
    }
    return destination;
  }

  image.Image normalizeContrast(image.Image source) {
    final histogram = List<int>.filled(256, 0);
    for (final pixel in source) {
      histogram[_luminance(pixel.r, pixel.g, pixel.b)]++;
    }
    final total = source.width * source.height;
    final low = _percentile(histogram, total, 0.02);
    final high = _percentile(histogram, total, 0.98);
    if (high <= low + 4) return image.Image.from(source);

    final output = image.Image.from(source);
    for (final pixel in output) {
      pixel
        ..r = _stretch(pixel.r, low, high)
        ..g = _stretch(pixel.g, low, high)
        ..b = _stretch(pixel.b, low, high);
    }
    return output;
  }

  image.Image grayscale(image.Image source) {
    final output = image.Image(width: source.width, height: source.height);
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        final pixel = source.getPixel(x, y);
        final value = _luminance(pixel.r, pixel.g, pixel.b);
        output.setPixelRgba(x, y, value, value, value, 255);
      }
    }
    return output;
  }

  image.Image adaptiveThreshold(
    image.Image gray, {
    int windowSize = 31,
    int bias = 12,
  }) {
    final width = gray.width;
    final height = gray.height;
    final stride = width + 1;
    final integral = List<int>.filled((width + 1) * (height + 1), 0);
    for (var y = 1; y <= height; y++) {
      var rowSum = 0;
      for (var x = 1; x <= width; x++) {
        rowSum += gray.getPixel(x - 1, y - 1).r.toInt();
        integral[y * stride + x] = integral[(y - 1) * stride + x] + rowSum;
      }
    }

    final output = image.Image(width: width, height: height);
    final radius = math.max(1, windowSize ~/ 2);
    for (var y = 0; y < height; y++) {
      final top = math.max(0, y - radius);
      final bottom = math.min(height - 1, y + radius);
      for (var x = 0; x < width; x++) {
        final left = math.max(0, x - radius);
        final right = math.min(width - 1, x + radius);
        final area = (right - left + 1) * (bottom - top + 1);
        final sum =
            integral[(bottom + 1) * stride + right + 1] -
            integral[top * stride + right + 1] -
            integral[(bottom + 1) * stride + left] +
            integral[top * stride + left];
        final mean = sum / area;
        final value = gray.getPixel(x, y).r < mean - bias ? 0 : 255;
        output.setPixelRgba(x, y, value, value, value, 255);
      }
    }
    return output;
  }

  double estimateSkewAngle(image.Image binary) {
    final points = <(int, int)>[];
    final step = math.max(1, math.max(binary.width, binary.height) ~/ 800);
    for (var y = 0; y < binary.height; y += step) {
      for (var x = 0; x < binary.width; x += step) {
        if (binary.getPixel(x, y).r < 64) points.add((x, y));
      }
    }
    if (points.length < 20) return 0;

    var bestAngle = 0.0;
    var bestScore = -1.0;
    for (var candidate = -5.0; candidate <= 5.0; candidate += 0.5) {
      final radians = candidate * math.pi / 180;
      final sine = math.sin(radians);
      final cosine = math.cos(radians);
      final bins = <int, int>{};
      for (final point in points) {
        final row = (point.$2 * cosine - point.$1 * sine).round();
        bins[row] = (bins[row] ?? 0) + 1;
      }
      final score = bins.values.fold<double>(
        0,
        (sum, count) => sum + count * count,
      );
      if (score > bestScore) {
        bestScore = score;
        bestAngle = candidate;
      }
    }
    return bestAngle;
  }

  int _percentile(List<int> histogram, int total, double percentile) {
    final target = (total * percentile).round();
    var seen = 0;
    for (var i = 0; i < histogram.length; i++) {
      seen += histogram[i];
      if (seen >= target) return i;
    }
    return 255;
  }

  int _stretch(num value, int low, int high) =>
      (((value - low) * 255) / (high - low)).round().clamp(0, 255);

  int _luminance(num red, num green, num blue) =>
      (0.299 * red + 0.587 * green + 0.114 * blue).round().clamp(0, 255);

  double _lerp(double a, double b, double amount) => a + (b - a) * amount;
}
