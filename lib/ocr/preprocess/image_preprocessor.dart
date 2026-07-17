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

  /// Finds a conservative document rectangle from strong vertical and
  /// horizontal luminance edges. The draggable crop UI remains the final
  /// authority, so uncertain images fall back to a safe inset rectangle.
  DocumentQuad detectDocumentQuad(
    Uint8List encoded, {
    int analysisDimension = 640,
  }) {
    var source = image.decodeImage(encoded);
    if (source == null) return const DocumentQuad.inset();
    source = image.bakeOrientation(source);
    source = _capSize(source, analysisDimension);
    if (source.width < 16 || source.height < 16) {
      return const DocumentQuad.inset();
    }

    final gray = grayscale(source);
    final contrastRectangle = _detectContrastRectangle(gray);
    if (contrastRectangle != null) return contrastRectangle;

    final vertical = List<double>.filled(gray.width, 0);
    final horizontal = List<double>.filled(gray.height, 0);
    for (var y = 1; y < gray.height - 1; y++) {
      for (var x = 1; x < gray.width - 1; x++) {
        final left = gray.getPixel(x - 1, y).r.toDouble();
        final right = gray.getPixel(x + 1, y).r.toDouble();
        final top = gray.getPixel(x, y - 1).r.toDouble();
        final bottom = gray.getPixel(x, y + 1).r.toDouble();
        vertical[x] += (right - left).abs();
        horizontal[y] += (bottom - top).abs();
      }
    }

    final left = _strongestEdge(vertical, 1, (gray.width * 0.45).round());
    final right = _strongestEdge(
      vertical,
      (gray.width * 0.55).round(),
      gray.width - 1,
    );
    final top = _strongestEdge(horizontal, 1, (gray.height * 0.45).round());
    final bottom = _strongestEdge(
      horizontal,
      (gray.height * 0.55).round(),
      gray.height - 1,
    );
    final minimumVerticalScore = gray.height * 12;
    final minimumHorizontalScore = gray.width * 12;
    if (left == null ||
        right == null ||
        top == null ||
        bottom == null ||
        vertical[left] < minimumVerticalScore ||
        vertical[right] < minimumVerticalScore ||
        horizontal[top] < minimumHorizontalScore ||
        horizontal[bottom] < minimumHorizontalScore) {
      return const DocumentQuad.inset();
    }

    final quad = DocumentQuad(
      topLeft: NormalizedPoint(left / gray.width, top / gray.height),
      topRight: NormalizedPoint(right / gray.width, top / gray.height),
      bottomRight: NormalizedPoint(right / gray.width, bottom / gray.height),
      bottomLeft: NormalizedPoint(left / gray.width, bottom / gray.height),
    );
    return quad.isValid ? quad : const DocumentQuad.inset();
  }

  DocumentQuad? _detectContrastRectangle(image.Image gray) {
    final sampleWidth = math.max(2, (gray.width * 0.12).round());
    final sampleHeight = math.max(2, (gray.height * 0.12).round());
    final background =
        <double>[
          _meanLuminance(gray, 0, 0, sampleWidth, sampleHeight),
          _meanLuminance(
            gray,
            gray.width - sampleWidth,
            0,
            gray.width,
            sampleHeight,
          ),
          _meanLuminance(
            gray,
            0,
            gray.height - sampleHeight,
            sampleWidth,
            gray.height,
          ),
          _meanLuminance(
            gray,
            gray.width - sampleWidth,
            gray.height - sampleHeight,
            gray.width,
            gray.height,
          ),
        ].reduce((a, b) => a + b) /
        4;
    final center = _meanLuminance(
      gray,
      (gray.width * 0.35).round(),
      (gray.height * 0.35).round(),
      (gray.width * 0.65).round(),
      (gray.height * 0.65).round(),
    );
    if ((center - background).abs() < 28) return null;

    final threshold = (center + background) / 2;
    final paperIsBrighter = center > background;
    bool isPaper(int x, int y) {
      final value = gray.getPixel(x, y).r;
      return paperIsBrighter ? value >= threshold : value <= threshold;
    }

    final minimumRowPixels = math.max(4, (gray.width * 0.12).round());
    final minimumColumnPixels = math.max(4, (gray.height * 0.12).round());
    final leftSamples = <_LineSample>[];
    final rightSamples = <_LineSample>[];
    int? top;
    int? bottom;
    for (var y = 0; y < gray.height; y++) {
      var count = 0;
      var first = -1;
      var last = -1;
      for (var x = 0; x < gray.width; x++) {
        if (isPaper(x, y)) {
          first = first < 0 ? x : first;
          last = x;
          count++;
        }
      }
      if (count >= minimumRowPixels) {
        top ??= y;
        bottom = y;
        leftSamples.add(_LineSample(y.toDouble(), first.toDouble()));
        rightSamples.add(_LineSample(y.toDouble(), last.toDouble()));
      }
    }
    final topSamples = <_LineSample>[];
    final bottomSamples = <_LineSample>[];
    int? left;
    int? right;
    for (var x = 0; x < gray.width; x++) {
      var count = 0;
      var first = -1;
      var last = -1;
      for (var y = 0; y < gray.height; y++) {
        if (isPaper(x, y)) {
          first = first < 0 ? y : first;
          last = y;
          count++;
        }
      }
      if (count >= minimumColumnPixels) {
        left ??= x;
        right = x;
        topSamples.add(_LineSample(x.toDouble(), first.toDouble()));
        bottomSamples.add(_LineSample(x.toDouble(), last.toDouble()));
      }
    }
    if (left == null || right == null || top == null || bottom == null) {
      return null;
    }
    if (right - left < gray.width * 0.35 || bottom - top < gray.height * 0.35) {
      return null;
    }
    final leftLine = _fitLine(leftSamples);
    final rightLine = _fitLine(rightSamples);
    final topLine = _fitLine(topSamples);
    final bottomLine = _fitLine(bottomSamples);
    if (leftLine != null &&
        rightLine != null &&
        topLine != null &&
        bottomLine != null) {
      final topLeft = _intersect(leftLine, topLine);
      final topRight = _intersect(rightLine, topLine);
      final bottomRight = _intersect(rightLine, bottomLine);
      final bottomLeft = _intersect(leftLine, bottomLine);
      if (topLeft != null &&
          topRight != null &&
          bottomRight != null &&
          bottomLeft != null) {
        final quad = DocumentQuad(
          topLeft: NormalizedPoint(
            topLeft.x / gray.width,
            topLeft.y / gray.height,
          ).clamp(),
          topRight: NormalizedPoint(
            topRight.x / gray.width,
            topRight.y / gray.height,
          ).clamp(),
          bottomRight: NormalizedPoint(
            bottomRight.x / gray.width,
            bottomRight.y / gray.height,
          ).clamp(),
          bottomLeft: NormalizedPoint(
            bottomLeft.x / gray.width,
            bottomLeft.y / gray.height,
          ).clamp(),
        );
        if (quad.isValid) return quad;
      }
    }

    const padding = 2;
    final safeLeft = math.max(0, left - padding);
    final safeRight = math.min(gray.width - 1, right + padding);
    final safeTop = math.max(0, top - padding);
    final safeBottom = math.min(gray.height - 1, bottom + padding);
    return DocumentQuad(
      topLeft: NormalizedPoint(safeLeft / gray.width, safeTop / gray.height),
      topRight: NormalizedPoint(safeRight / gray.width, safeTop / gray.height),
      bottomRight: NormalizedPoint(
        safeRight / gray.width,
        safeBottom / gray.height,
      ),
      bottomLeft: NormalizedPoint(
        safeLeft / gray.width,
        safeBottom / gray.height,
      ),
    );
  }

  _LineFit? _fitLine(List<_LineSample> samples) {
    if (samples.length < 4) return null;
    final meanIndependent =
        samples.fold<double>(0, (sum, item) => sum + item.independent) /
        samples.length;
    final meanDependent =
        samples.fold<double>(0, (sum, item) => sum + item.dependent) /
        samples.length;
    var numerator = 0.0;
    var denominator = 0.0;
    for (final sample in samples) {
      final independent = sample.independent - meanIndependent;
      numerator += independent * (sample.dependent - meanDependent);
      denominator += independent * independent;
    }
    if (denominator.abs() < 1e-9) return null;
    final slope = numerator / denominator;
    return _LineFit(
      slope: slope,
      intercept: meanDependent - slope * meanIndependent,
    );
  }

  ({double x, double y})? _intersect(_LineFit xForY, _LineFit yForX) {
    final denominator = 1 - yForX.slope * xForY.slope;
    if (denominator.abs() < 1e-9) return null;
    final y = (yForX.slope * xForY.intercept + yForX.intercept) / denominator;
    return (x: xForY.slope * y + xForY.intercept, y: y);
  }

  double _meanLuminance(
    image.Image gray,
    int left,
    int top,
    int right,
    int bottom,
  ) {
    var sum = 0.0;
    var count = 0;
    for (var y = top; y < bottom; y++) {
      for (var x = left; x < right; x++) {
        sum += gray.getPixel(x, y).r;
        count++;
      }
    }
    return count == 0 ? 0 : sum / count;
  }

  PreprocessResult process(
    Uint8List encoded, {
    DocumentQuad quad = const DocumentQuad.inset(),
    PreprocessOptions options = const PreprocessOptions(),
  }) {
    if (options.minimumDimension < 1) {
      throw ArgumentError.value(
        options.minimumDimension,
        'minimumDimension',
        'Must be at least 1',
      );
    }
    if (options.maximumDimension < 2) {
      throw ArgumentError.value(
        options.maximumDimension,
        'maximumDimension',
        'Must be at least 2',
      );
    }
    var source = image.decodeImage(encoded);
    if (source == null) throw const FormatException('Unsupported image');
    source = image.bakeOrientation(source);
    source = _capSize(source, options.maximumDimension);

    var corrected = warpQuad(
      source,
      quad.isValid ? quad : const DocumentQuad.inset(),
      maximumDimension: options.maximumDimension,
    );
    if (options.rotationQuarterTurns % 4 != 0) {
      corrected = image.copyRotate(
        corrected,
        angle: 90 * (options.rotationQuarterTurns % 4),
        interpolation: image.Interpolation.linear,
      );
    }
    corrected = _fitDimensions(
      corrected,
      minimum: options.minimumDimension,
      maximum: options.maximumDimension,
    );
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
        corrected = _fitDimensions(
          corrected,
          minimum: options.minimumDimension,
          maximum: options.maximumDimension,
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

  int? _strongestEdge(List<double> scores, int start, int end) {
    if (scores.isEmpty || start >= end) return null;
    var bestIndex = start.clamp(0, scores.length - 1);
    var bestScore = double.negativeInfinity;
    final safeEnd = end.clamp(bestIndex + 1, scores.length);
    for (var index = bestIndex; index < safeEnd; index++) {
      final score = scores[index];
      if (score > bestScore) {
        bestScore = score;
        bestIndex = index;
      }
    }
    return bestIndex;
  }

  image.Image _fitDimensions(
    image.Image source, {
    required int minimum,
    required int maximum,
  }) {
    final shortest = math.min(source.width, source.height);
    final longest = math.max(source.width, source.height);
    if (shortest >= minimum && longest <= maximum) return source;

    final maximumScale = maximum / longest;
    final scale = longest > maximum
        ? maximumScale
        : math.min(minimum / shortest, maximumScale);
    return image.copyResize(
      source,
      width: (source.width * scale).round().clamp(1, maximum),
      height: (source.height * scale).round().clamp(1, maximum),
      interpolation: image.Interpolation.linear,
    );
  }

  image.Image warpQuad(
    image.Image source,
    DocumentQuad quad, {
    int maximumDimension = 5000,
  }) {
    if (maximumDimension < 2) {
      throw ArgumentError.value(
        maximumDimension,
        'maximumDimension',
        'Must be at least 2',
      );
    }
    final naturalWidth = math.max(
      2,
      quad.widthFor(source.width, source.height).round(),
    );
    final naturalHeight = math.max(
      2,
      quad.heightFor(source.width, source.height).round(),
    );
    final outputScale = math.min(
      1.0,
      maximumDimension / math.max(naturalWidth, naturalHeight),
    );
    final width = (naturalWidth * outputScale).round().clamp(
      2,
      maximumDimension,
    );
    final height = (naturalHeight * outputScale).round().clamp(
      2,
      maximumDimension,
    );
    final destination = image.Image(width: width, height: height);
    final transform = _ProjectiveTransform.fromUnitSquare(quad);

    for (var y = 0; y < height; y++) {
      final v = height == 1 ? 0.0 : y / (height - 1);
      for (var x = 0; x < width; x++) {
        final u = width == 1 ? 0.0 : x / (width - 1);
        final sourcePoint = transform.map(u, v);
        final sourceX = (sourcePoint.x * (source.width - 1)).round().clamp(
          0,
          source.width - 1,
        );
        final sourceY = (sourcePoint.y * (source.height - 1)).round().clamp(
          0,
          source.height - 1,
        );
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
}

class _LineSample {
  const _LineSample(this.independent, this.dependent);

  final double independent;
  final double dependent;
}

class _LineFit {
  const _LineFit({required this.slope, required this.intercept});

  final double slope;
  final double intercept;
}

class _ProjectiveTransform {
  const _ProjectiveTransform({
    required this.a,
    required this.b,
    required this.c,
    required this.d,
    required this.e,
    required this.f,
    required this.g,
    required this.h,
  });

  factory _ProjectiveTransform.fromUnitSquare(DocumentQuad quad) {
    final x0 = quad.topLeft.x;
    final y0 = quad.topLeft.y;
    final x1 = quad.topRight.x;
    final y1 = quad.topRight.y;
    final x2 = quad.bottomRight.x;
    final y2 = quad.bottomRight.y;
    final x3 = quad.bottomLeft.x;
    final y3 = quad.bottomLeft.y;
    final diagonalX = x0 - x1 + x2 - x3;
    final diagonalY = y0 - y1 + y2 - y3;

    if (diagonalX.abs() < 1e-12 && diagonalY.abs() < 1e-12) {
      return _ProjectiveTransform(
        a: x1 - x0,
        b: x3 - x0,
        c: x0,
        d: y1 - y0,
        e: y3 - y0,
        f: y0,
        g: 0,
        h: 0,
      );
    }

    final rightX = x1 - x2;
    final bottomX = x3 - x2;
    final rightY = y1 - y2;
    final bottomY = y3 - y2;
    final determinant = rightX * bottomY - bottomX * rightY;
    if (determinant.abs() < 1e-12) {
      throw ArgumentError.value(quad, 'quad', 'Cannot be projectively mapped');
    }
    final g = (diagonalX * bottomY - bottomX * diagonalY) / determinant;
    final h = (rightX * diagonalY - diagonalX * rightY) / determinant;
    return _ProjectiveTransform(
      a: x1 - x0 + g * x1,
      b: x3 - x0 + h * x3,
      c: x0,
      d: y1 - y0 + g * y1,
      e: y3 - y0 + h * y3,
      f: y0,
      g: g,
      h: h,
    );
  }

  final double a;
  final double b;
  final double c;
  final double d;
  final double e;
  final double f;
  final double g;
  final double h;

  NormalizedPoint map(double x, double y) {
    final denominator = g * x + h * y + 1;
    return NormalizedPoint(
      (a * x + b * y + c) / denominator,
      (d * x + e * y + f) / denominator,
    );
  }
}
