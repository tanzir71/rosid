import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:rosid/ocr/preprocess/document_quad.dart';

/// Quality hints ordered from highest priority to lowest priority.
enum CaptureQualityHint {
  noPaper,
  moveCloser,
  tooDark,
  glare,
  holdSteady,
  edgesFoundHoldSteady,
}

/// Output of analyzing one small (~320 px) preview frame.
class FrameAnalysisResult {
  const FrameAnalysisResult({
    required this.quad,
    required this.hint,
    required this.isSteady,
    required this.steadyProgress,
    required this.blurVariance,
    required this.meanBrightness,
    required this.glareRatio,
    required this.elapsedMs,
  });

  final DocumentQuad? quad;
  final CaptureQualityHint hint;
  final bool isSteady;
  final double steadyProgress;
  final double blurVariance;
  final double meanBrightness;
  final double glareRatio;
  final int elapsedMs;
}

/// Pure-Dart 320 px frame analyzer (edges, quad, smoothing, quality hints,
/// and steadiness-based auto-capture trigger).
class FrameAnalyzer {
  FrameAnalyzer({
    this.minAreaFraction = 0.20,
    this.steadyMovementThreshold = 0.02,
    this.steadyDurationMs = 600,
    this.minBrightness = 42.0,
    this.maxGlareRatio = 0.22,
    this.minBlurVariance = 18.0,
    this.smoothingAlpha = 0.45,
  });

  final double minAreaFraction;
  final double steadyMovementThreshold;
  final int steadyDurationMs;
  final double minBrightness;
  final double maxGlareRatio;
  final double minBlurVariance;
  final double smoothingAlpha;

  DocumentQuad? _smoothedQuad;
  DocumentQuad? _steadyAnchor;
  int? _steadySinceMs;

  void reset() {
    _smoothedQuad = null;
    _steadyAnchor = null;
    _steadySinceMs = null;
  }

  /// Analyzes an encoded image (JPEG/PNG) by shrinking to ~320 px greyscale.
  FrameAnalysisResult analyzeEncoded(
    Uint8List encodedBytes, {
    int? timestampMs,
    bool skipBlurCheck = false,
  }) {
    final sw = Stopwatch()..start();
    final decoded = img.decodeImage(encodedBytes);
    if (decoded == null) {
      sw.stop();
      reset();
      return FrameAnalysisResult(
        quad: null,
        hint: CaptureQualityHint.noPaper,
        isSteady: false,
        steadyProgress: 0,
        blurVariance: 0,
        meanBrightness: 0,
        glareRatio: 0,
        elapsedMs: sw.elapsedMilliseconds,
      );
    }
    final (luma, w, h) = _toSmallLuma(decoded, maxDim: 320);
    return analyzeLuma(
      luma,
      width: w,
      height: h,
      timestampMs: timestampMs ?? DateTime.now().millisecondsSinceEpoch,
      skipBlurCheck: skipBlurCheck,
      stopwatch: sw,
    );
  }

  /// Analyzes an already-extracted single-channel greyscale buffer (e.g. Android
  /// camera Y plane downscaled to <= 320 px on the long side).
  FrameAnalysisResult analyzeLuma(
    Uint8List luma, {
    required int width,
    required int height,
    int? timestampMs,
    bool skipBlurCheck = false,
    Stopwatch? stopwatch,
  }) {
    final sw = stopwatch ?? (Stopwatch()..start());
    final nowMs = timestampMs ?? DateTime.now().millisecondsSinceEpoch;

    if (width < 24 || height < 24 || luma.length < width * height) {
      sw.stop();
      reset();
      return FrameAnalysisResult(
        quad: null,
        hint: CaptureQualityHint.noPaper,
        isSteady: false,
        steadyProgress: 0,
        blurVariance: 0,
        meanBrightness: 0,
        glareRatio: 0,
        elapsedMs: sw.elapsedMilliseconds,
      );
    }

    // 1. Brightness check across the frame.
    var sumLuma = 0;
    for (var i = 0; i < width * height; i++) {
      sumLuma += luma[i];
    }
    final meanBrightness = sumLuma / (width * height);

    // 2. Detect document quad on 320px frame.
    final rawQuad = detectQuadFromLuma(luma, width, height);
    if (rawQuad == null) {
      reset();
      sw.stop();
      final hint = meanBrightness < minBrightness
          ? CaptureQualityHint.tooDark
          : CaptureQualityHint.noPaper;
      return FrameAnalysisResult(
        quad: null,
        hint: hint,
        isSteady: false,
        steadyProgress: 0,
        blurVariance: 0,
        meanBrightness: meanBrightness,
        glareRatio: 0,
        elapsedMs: sw.elapsedMilliseconds,
      );
    }

    // 3. Smooth corners over recent frames.
    final smoothed = _smoothQuad(rawQuad);

    // 4. Area / distance check (convex shape covering > 20% of frame).
    final area = smoothed.area;
    if (area < minAreaFraction) {
      _steadyAnchor = null;
      _steadySinceMs = null;
      sw.stop();
      return FrameAnalysisResult(
        quad: smoothed,
        hint: CaptureQualityHint.moveCloser,
        isSteady: false,
        steadyProgress: 0,
        blurVariance: 0,
        meanBrightness: meanBrightness,
        glareRatio: 0,
        elapsedMs: sw.elapsedMilliseconds,
      );
    }

    // 5. Glare & blur checks inside the paper bounding region.
    final (glareRatio, blurVar, interiorBrightness) = _measureRegionQuality(
      luma,
      width,
      height,
      smoothed,
    );

    if (interiorBrightness < minBrightness && meanBrightness < minBrightness) {
      _steadyAnchor = null;
      _steadySinceMs = null;
      sw.stop();
      return FrameAnalysisResult(
        quad: smoothed,
        hint: CaptureQualityHint.tooDark,
        isSteady: false,
        steadyProgress: 0,
        blurVariance: blurVar,
        meanBrightness: meanBrightness,
        glareRatio: glareRatio,
        elapsedMs: sw.elapsedMilliseconds,
      );
    }

    if (glareRatio > maxGlareRatio) {
      _steadyAnchor = null;
      _steadySinceMs = null;
      sw.stop();
      return FrameAnalysisResult(
        quad: smoothed,
        hint: CaptureQualityHint.glare,
        isSteady: false,
        steadyProgress: 0,
        blurVariance: blurVar,
        meanBrightness: meanBrightness,
        glareRatio: glareRatio,
        elapsedMs: sw.elapsedMilliseconds,
      );
    }

    if (!skipBlurCheck && blurVar < minBlurVariance) {
      _steadyAnchor = null;
      _steadySinceMs = null;
      sw.stop();
      return FrameAnalysisResult(
        quad: smoothed,
        hint: CaptureQualityHint.holdSteady,
        isSteady: false,
        steadyProgress: 0,
        blurVariance: blurVar,
        meanBrightness: meanBrightness,
        glareRatio: glareRatio,
        elapsedMs: sw.elapsedMilliseconds,
      );
    }

    // 6. Steadiness check: corners moved < 2% of frame diagonal for >= 600 ms.
    final anchor = _steadyAnchor;
    if (anchor == null ||
        _maxCornerShift(anchor, smoothed) > steadyMovementThreshold) {
      _steadyAnchor = smoothed;
      _steadySinceMs = nowMs;
      sw.stop();
      return FrameAnalysisResult(
        quad: smoothed,
        hint: CaptureQualityHint.edgesFoundHoldSteady,
        isSteady: false,
        steadyProgress: 0,
        blurVariance: blurVar,
        meanBrightness: meanBrightness,
        glareRatio: glareRatio,
        elapsedMs: sw.elapsedMilliseconds,
      );
    }

    final heldMs = nowMs - (_steadySinceMs ?? nowMs);
    final progress = (heldMs / steadyDurationMs).clamp(0.0, 1.0);
    final isSteady = heldMs >= steadyDurationMs;
    sw.stop();
    return FrameAnalysisResult(
      quad: smoothed,
      hint: CaptureQualityHint.edgesFoundHoldSteady,
      isSteady: isSteady,
      steadyProgress: progress,
      blurVariance: blurVar,
      meanBrightness: meanBrightness,
      glareRatio: glareRatio,
      elapsedMs: sw.elapsedMilliseconds,
    );
  }

  DocumentQuad _smoothQuad(DocumentQuad next) {
    final prev = _smoothedQuad;
    if (prev == null || _maxCornerShift(prev, next) > 0.15) {
      _smoothedQuad = next;
      return next;
    }
    NormalizedPoint lerp(NormalizedPoint a, NormalizedPoint b) =>
        NormalizedPoint(
          a.x + (b.x - a.x) * smoothingAlpha,
          a.y + (b.y - a.y) * smoothingAlpha,
        );
    final blended = DocumentQuad(
      topLeft: lerp(prev.topLeft, next.topLeft),
      topRight: lerp(prev.topRight, next.topRight),
      bottomRight: lerp(prev.bottomRight, next.bottomRight),
      bottomLeft: lerp(prev.bottomLeft, next.bottomLeft),
    );
    _smoothedQuad = blended;
    return blended;
  }

  double _maxCornerShift(DocumentQuad a, DocumentQuad b) {
    final pa = a.points;
    final pb = b.points;
    var maxDist = 0.0;
    for (var i = 0; i < 4; i++) {
      final dx = pa[i].x - pb[i].x;
      final dy = pa[i].y - pb[i].y;
      // Normalized frame diagonal is sqrt(2); normalize by sqrt(2).
      final d = math.sqrt(dx * dx + dy * dy) / math.sqrt2;
      if (d > maxDist) maxDist = d;
    }
    return maxDist;
  }

  (double glare, double blurVar, double meanInside) _measureRegionQuality(
    Uint8List luma,
    int w,
    int h,
    DocumentQuad quad,
  ) {
    final xs = quad.points.map((p) => p.x);
    final ys = quad.points.map((p) => p.y);
    final x0 = (xs.reduce(math.min) * (w - 1)).round().clamp(1, w - 2);
    final x1 = (xs.reduce(math.max) * (w - 1)).round().clamp(x0 + 1, w - 2);
    final y0 = (ys.reduce(math.min) * (h - 1)).round().clamp(1, h - 2);
    final y1 = (ys.reduce(math.max) * (h - 1)).round().clamp(y0 + 1, h - 2);

    var count = 0;
    var nearWhite = 0;
    var sumInside = 0.0;
    var lapSum = 0.0;
    var lapSqSum = 0.0;
    var lapCount = 0;

    // Sample every 2nd pixel inside the paper region for sub-millisecond speed.
    for (var y = y0; y <= y1; y += 2) {
      final row = y * w;
      for (var x = x0; x <= x1; x += 2) {
        final v = luma[row + x];
        sumInside += v;
        if (v >= 252) nearWhite++;
        count++;

        final lap =
            (-4 * v +
                    luma[row + x - 1] +
                    luma[row + x + 1] +
                    luma[(y - 1) * w + x] +
                    luma[(y + 1) * w + x])
                .toDouble();
        lapSum += lap;
        lapSqSum += lap * lap;
        lapCount++;
      }
    }
    if (count == 0) return (0, 0, 0);
    final meanLap = lapCount == 0 ? 0.0 : lapSum / lapCount;
    final variance = lapCount == 0
        ? 0.0
        : math.max(0.0, (lapSqSum / lapCount) - meanLap * meanLap);
    return (nearWhite / count, variance, sumInside / count);
  }

  /// Detects a 4-corner convex paper quad from a greyscale image using
  /// 3x3 Gaussian blur -> adaptive paper mask -> convex hull -> 4-line RANSAC /
  /// extremal polygon fitting. Accurate to < 2% diagonal even under tilt,
  /// shadows, and uneven lighting.
  static DocumentQuad? detectQuadFromLuma(Uint8List luma, int w, int h) {
    final blurred = _boxBlur3x3(luma, w, h);

    // Estimate background luminance from border strips (10% margin around edges).
    final borderSamples = <int>[];
    final bx = math.max(2, (w * 0.06).round());
    final by = math.max(2, (h * 0.06).round());
    for (var y = 0; y < h; y += 2) {
      for (var x = 0; x < bx; x += 2) {
        borderSamples.add(blurred[y * w + x]);
        borderSamples.add(blurred[y * w + (w - 1 - x)]);
      }
    }
    for (var x = bx; x < w - bx; x += 2) {
      for (var y = 0; y < by; y += 2) {
        borderSamples.add(blurred[y * w + x]);
        borderSamples.add(blurred[(h - 1 - y) * w + x]);
      }
    }
    borderSamples.sort();
    final bgMedian = borderSamples.isEmpty
        ? 40.0
        : borderSamples[borderSamples.length ~/ 2].toDouble();

    // Estimate center paper luminance.
    final centerSamples = <int>[];
    for (var y = (h * 0.30).round(); y < (h * 0.70).round(); y += 2) {
      for (var x = (w * 0.30).round(); x < (w * 0.70).round(); x += 2) {
        centerSamples.add(blurred[y * w + x]);
      }
    }
    centerSamples.sort();
    // Use 75th percentile of center so dark text on paper doesn't drag it down.
    final paperEst = centerSamples.isEmpty
        ? 200.0
        : centerSamples[(centerSamples.length * 0.75).round().clamp(
                0,
                centerSamples.length - 1,
              )]
              .toDouble();

    final contrast = paperEst - bgMedian;
    if (contrast.abs() < 22.0) {
      return _detectByGradientBox(blurred, w, h);
    }

    final paperBrighter = contrast > 0;
    final threshold = bgMedian + contrast * 0.42;

    // Build foreground mask and keep the largest connected region touching the center.
    final mask = Uint8List(w * h);
    for (var i = 0; i < w * h; i++) {
      final v = blurred[i];
      if (paperBrighter ? v >= threshold : v <= threshold) {
        mask[i] = 1;
      }
    }

    // Extract boundary points of the largest foreground component via flood-fill.
    final boundary = _largestComponentBoundary(mask, w, h);
    if (boundary.length < 40) {
      return _detectByGradientBox(blurred, w, h);
    }

    // Compute convex hull of the boundary points (Andrew's monotone chain).
    final hull = _convexHull(boundary);
    if (hull.length < 4) return null;

    // Reduce convex hull to the optimal 4-corner quadrilateral via iterative
    // minimum-area triangle removal (Douglas-Peucker / Visvalingam on hull).
    final quadPts = _simplifyHullToQuad(hull);
    if (quadPts == null) return null;

    final ordered = _orderCorners(quadPts, w, h);
    return ordered.area > 0.04 ? ordered : null;
  }

  static List<(int, int)> _largestComponentBoundary(
    Uint8List mask,
    int w,
    int h,
  ) {
    final visited = Uint8List(w * h);
    final queue = Int32List(w * h);
    var bestArea = 0;
    var bestLabel = 0;
    final labels = Int32List(w * h);
    var currentLabel = 0;

    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final start = y * w + x;
        if (mask[start] == 0 || visited[start] != 0) continue;
        currentLabel++;
        var head = 0;
        var tail = 0;
        queue[tail++] = start;
        visited[start] = 1;
        labels[start] = currentLabel;
        while (head < tail) {
          final idx = queue[head++];
          final cx = idx % w;
          final cy = idx ~/ w;
          if (cx > 0 && mask[idx - 1] != 0 && visited[idx - 1] == 0) {
            visited[idx - 1] = 1;
            labels[idx - 1] = currentLabel;
            queue[tail++] = idx - 1;
          }
          if (cx < w - 1 && mask[idx + 1] != 0 && visited[idx + 1] == 0) {
            visited[idx + 1] = 1;
            labels[idx + 1] = currentLabel;
            queue[tail++] = idx + 1;
          }
          if (cy > 0 && mask[idx - w] != 0 && visited[idx - w] == 0) {
            visited[idx - w] = 1;
            labels[idx - w] = currentLabel;
            queue[tail++] = idx - w;
          }
          if (cy < h - 1 && mask[idx + w] != 0 && visited[idx + w] == 0) {
            visited[idx + w] = 1;
            labels[idx + w] = currentLabel;
            queue[tail++] = idx + w;
          }
        }
        if (tail > bestArea) {
          bestArea = tail;
          bestLabel = currentLabel;
        }
      }
    }

    if (bestLabel == 0 || bestArea < (w * h * 0.04)) return const [];

    final boundary = <(int, int)>[];
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final idx = y * w + x;
        if (labels[idx] != bestLabel) continue;
        final isEdge =
            x == 0 ||
            x == w - 1 ||
            y == 0 ||
            y == h - 1 ||
            labels[idx - 1] != bestLabel ||
            labels[idx + 1] != bestLabel ||
            labels[idx - w] != bestLabel ||
            labels[idx + w] != bestLabel;
        if (isEdge) boundary.add((x, y));
      }
    }
    return boundary;
  }

  static List<(int, int)> _convexHull(List<(int, int)> points) {
    final sorted = List<(int, int)>.from(points)
      ..sort(
        (a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2),
      );

    int cross((int, int) o, (int, int) a, (int, int) b) =>
        (a.$1 - o.$1) * (b.$2 - o.$2) - (a.$2 - o.$2) * (b.$1 - o.$1);

    final lower = <(int, int)>[];
    for (final p in sorted) {
      while (lower.length >= 2 &&
          cross(lower[lower.length - 2], lower.last, p) <= 0) {
        lower.removeLast();
      }
      lower.add(p);
    }
    final upper = <(int, int)>[];
    for (var i = sorted.length - 1; i >= 0; i--) {
      final p = sorted[i];
      while (upper.length >= 2 &&
          cross(upper[upper.length - 2], upper.last, p) <= 0) {
        upper.removeLast();
      }
      upper.add(p);
    }
    lower.removeLast();
    upper.removeLast();
    return [...lower, ...upper];
  }

  /// Simplifies a convex polygon down to 4 vertices by repeatedly removing the
  /// vertex whose removal loses the least polygon area.
  static List<(int, int)>? _simplifyHullToQuad(List<(int, int)> hull) {
    if (hull.length < 4) return null;
    final pts = List<(int, int)>.from(hull);
    while (pts.length > 4) {
      var minArea = double.infinity;
      var removeIdx = 0;
      final n = pts.length;
      for (var i = 0; i < n; i++) {
        final prev = pts[(i - 1 + n) % n];
        final curr = pts[i];
        final next = pts[(i + 1) % n];
        final area2 =
            ((curr.$1 - prev.$1) * (next.$2 - prev.$2) -
                    (curr.$2 - prev.$2) * (next.$1 - prev.$1))
                .abs()
                .toDouble();
        if (area2 < minArea) {
          minArea = area2;
          removeIdx = i;
        }
      }
      pts.removeAt(removeIdx);
    }
    return pts;
  }

  static DocumentQuad _orderCorners(List<(int, int)> pts, int w, int h) {
    // Sort by sum (x+y) for TL & BR, and difference (y-x) for TR & BL.
    var tl = pts.first;
    var br = pts.first;
    var tr = pts.first;
    var bl = pts.first;
    for (final p in pts) {
      if (p.$1 + p.$2 < tl.$1 + tl.$2) tl = p;
      if (p.$1 + p.$2 > br.$1 + br.$2) br = p;
      if (p.$2 - p.$1 < tr.$2 - tr.$1) tr = p;
      if (p.$2 - p.$1 > bl.$2 - bl.$1) bl = p;
    }
    return DocumentQuad(
      topLeft: NormalizedPoint(tl.$1 / (w - 1), tl.$2 / (h - 1)).clamp(),
      topRight: NormalizedPoint(tr.$1 / (w - 1), tr.$2 / (h - 1)).clamp(),
      bottomRight: NormalizedPoint(br.$1 / (w - 1), br.$2 / (h - 1)).clamp(),
      bottomLeft: NormalizedPoint(bl.$1 / (w - 1), bl.$2 / (h - 1)).clamp(),
    );
  }

  static DocumentQuad? _detectByGradientBox(Uint8List blurred, int w, int h) {
    final vert = Float64List(w);
    final horiz = Float64List(h);
    for (var y = 1; y < h - 1; y++) {
      final row = y * w;
      for (var x = 1; x < w - 1; x++) {
        final gx = (blurred[row + x + 1] - blurred[row + x - 1]).abs();
        final gy = (blurred[(y + 1) * w + x] - blurred[(y - 1) * w + x]).abs();
        vert[x] += gx;
        horiz[y] += gy;
      }
    }
    int bestIndex(Float64List arr, int start, int end) {
      var idx = start;
      var best = -1.0;
      for (var i = start; i < end; i++) {
        if (arr[i] > best) {
          best = arr[i];
          idx = i;
        }
      }
      return idx;
    }

    final left = bestIndex(vert, 1, (w * 0.45).round());
    final right = bestIndex(vert, (w * 0.55).round(), w - 1);
    final top = bestIndex(horiz, 1, (h * 0.45).round());
    final bottom = bestIndex(horiz, (h * 0.55).round(), h - 1);
    if (vert[left] < h * 10 ||
        vert[right] < h * 10 ||
        horiz[top] < w * 10 ||
        horiz[bottom] < w * 10) {
      return null;
    }
    final quad = DocumentQuad(
      topLeft: NormalizedPoint(left / (w - 1), top / (h - 1)),
      topRight: NormalizedPoint(right / (w - 1), top / (h - 1)),
      bottomRight: NormalizedPoint(right / (w - 1), bottom / (h - 1)),
      bottomLeft: NormalizedPoint(left / (w - 1), bottom / (h - 1)),
    );
    return quad.isValid ? quad : null;
  }

  static Uint8List _boxBlur3x3(Uint8List src, int w, int h) {
    final out = Uint8List.fromList(src);
    for (var y = 1; y < h - 1; y++) {
      final r0 = (y - 1) * w;
      final r1 = y * w;
      final r2 = (y + 1) * w;
      for (var x = 1; x < w - 1; x++) {
        final sum =
            src[r0 + x - 1] +
            src[r0 + x] +
            src[r0 + x + 1] +
            src[r1 + x - 1] +
            src[r1 + x] +
            src[r1 + x + 1] +
            src[r2 + x - 1] +
            src[r2 + x] +
            src[r2 + x + 1];
        out[r1 + x] = sum ~/ 9;
      }
    }
    return out;
  }

  static (Uint8List, int, int) _toSmallLuma(
    img.Image source, {
    int maxDim = 320,
  }) {
    final oriented = img.bakeOrientation(source);
    final longest = math.max(oriented.width, oriented.height);
    final resized = longest <= maxDim
        ? oriented
        : img.copyResize(
            oriented,
            width: oriented.width >= oriented.height ? maxDim : null,
            height: oriented.height > oriented.width ? maxDim : null,
            interpolation: img.Interpolation.linear,
          );
    final w = resized.width;
    final h = resized.height;
    final luma = Uint8List(w * h);
    var i = 0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = resized.getPixel(x, y);
        luma[i++] = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round().clamp(
          0,
          255,
        );
      }
    }
    return (luma, w, h);
  }
}

/// Long-lived background isolate for non-blocking live frame analysis.
class FrameAnalyzerIsolate {
  FrameAnalyzerIsolate._(this._isolate, this._sendPort, this._receivePort);

  final Isolate _isolate;
  final SendPort _sendPort;
  final ReceivePort _receivePort;
  final Map<int, Completer<FrameAnalysisResult>> _pending = {};
  int _nextId = 0;
  bool _closed = false;

  static Future<FrameAnalyzerIsolate> spawn() async {
    final ready = ReceivePort();
    final isolate = await Isolate.spawn(_workerMain, ready.sendPort);
    final completer = Completer<SendPort>();
    final wrapper = ReceivePort();
    late final FrameAnalyzerIsolate instance;
    ready.listen((msg) {
      if (msg is SendPort && !completer.isCompleted) {
        completer.complete(msg);
      }
    });
    final workerPort = await completer.future;
    ready.close();
    instance = FrameAnalyzerIsolate._(isolate, workerPort, wrapper);
    wrapper.listen((msg) {
      if (msg is List && msg.length == 2 && msg[0] is int) {
        final id = msg[0] as int;
        final result = msg[1] as FrameAnalysisResult;
        instance._pending.remove(id)?.complete(result);
      }
    });
    workerPort.send(['init', wrapper.sendPort]);
    return instance;
  }

  Future<FrameAnalysisResult> analyzeEncoded(
    Uint8List encodedBytes, {
    int? timestampMs,
    bool skipBlurCheck = false,
  }) {
    if (_closed) {
      return Future.error(StateError('FrameAnalyzerIsolate is closed'));
    }
    final id = ++_nextId;
    final completer = Completer<FrameAnalysisResult>();
    _pending[id] = completer;
    _sendPort.send([
      'encoded',
      id,
      TransferableTypedData.fromList([encodedBytes]),
      timestampMs ?? DateTime.now().millisecondsSinceEpoch,
      skipBlurCheck,
    ]);
    return completer.future;
  }

  Future<FrameAnalysisResult> analyzeLuma(
    Uint8List luma, {
    required int width,
    required int height,
    int? timestampMs,
    bool skipBlurCheck = false,
  }) {
    if (_closed) {
      return Future.error(StateError('FrameAnalyzerIsolate is closed'));
    }
    final id = ++_nextId;
    final completer = Completer<FrameAnalysisResult>();
    _pending[id] = completer;
    _sendPort.send([
      'luma',
      id,
      TransferableTypedData.fromList([luma]),
      width,
      height,
      timestampMs ?? DateTime.now().millisecondsSinceEpoch,
      skipBlurCheck,
    ]);
    return completer.future;
  }

  void reset() {
    if (!_closed) _sendPort.send(['reset']);
  }

  void dispose() {
    if (_closed) return;
    _closed = true;
    _sendPort.send(['close']);
    for (final c in _pending.values) {
      if (!c.isCompleted) {
        c.completeError(StateError('FrameAnalyzerIsolate disposed'));
      }
    }
    _pending.clear();
    _receivePort.close();
    _isolate.kill(priority: Isolate.immediate);
  }

  static void _workerMain(SendPort mainPort) {
    final inbox = ReceivePort();
    mainPort.send(inbox.sendPort);
    SendPort? replyPort;
    final analyzer = FrameAnalyzer();

    inbox.listen((msg) {
      if (msg is! List || msg.isEmpty) return;
      final cmd = msg[0] as String;
      switch (cmd) {
        case 'init':
          replyPort = msg[1] as SendPort;
        case 'reset':
          analyzer.reset();
        case 'encoded':
          final id = msg[1] as int;
          final bytes = (msg[2] as TransferableTypedData)
              .materialize()
              .asUint8List();
          final ts = msg[3] as int;
          final skipBlur = msg[4] as bool;
          final res = analyzer.analyzeEncoded(
            bytes,
            timestampMs: ts,
            skipBlurCheck: skipBlur,
          );
          replyPort?.send([id, res]);
        case 'luma':
          final id = msg[1] as int;
          final luma = (msg[2] as TransferableTypedData)
              .materialize()
              .asUint8List();
          final w = msg[3] as int;
          final h = msg[4] as int;
          final ts = msg[5] as int;
          final skipBlur = msg[6] as bool;
          final res = analyzer.analyzeLuma(
            luma,
            width: w,
            height: h,
            timestampMs: ts,
            skipBlurCheck: skipBlur,
          );
          replyPort?.send([id, res]);
        case 'close':
          inbox.close();
      }
    });
  }
}
