import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:rosid/features/capture/frame_analyzer.dart';
import 'package:rosid/ocr/preprocess/document_quad.dart';

/// Synthesizes a photo-like 320x240 greyscale frame containing a tilted,
/// unevenly lit paper polygon with printed text-like bars over a darker desk.
Uint8List _renderSyntheticPaperLuma({
  required int width,
  required int height,
  required List<(double, double)> cornersNorm,
  required math.Random rng,
  double bgBase = 48,
  double paperBase = 215,
  double lightingSlope = 22,
  bool drawTextLines = true,
}) {
  final luma = Uint8List(width * height);
  final poly = cornersNorm
      .map((p) => (p.$1 * (width - 1), p.$2 * (height - 1)))
      .toList(growable: false);

  bool pointInConvexQuad(double px, double py) {
    // Vertices are clockwise (TL, TR, BR, BL) in screen coordinates (y down).
    for (var i = 0; i < 4; i++) {
      final a = poly[i];
      final b = poly[(i + 1) % 4];
      final cross = (b.$1 - a.$1) * (py - a.$2) - (b.$2 - a.$2) * (px - a.$1);
      if (cross < 0) return false;
    }
    return true;
  }

  for (var y = 0; y < height; y++) {
    final fy = y / (height - 1);
    for (var x = 0; x < width; x++) {
      final fx = x / (width - 1);
      final noise = (rng.nextDouble() - 0.5) * 6.0;
      final gradient =
          (fx - 0.5) * lightingSlope + (fy - 0.5) * (lightingSlope * 0.6);
      if (pointInConvexQuad(x.toDouble(), y.toDouble())) {
        var v = paperBase + gradient + noise;
        if (drawTextLines &&
            y % 14 >= 6 &&
            y % 14 <= 8 &&
            fx > 0.25 &&
            fx < 0.75) {
          // Simulated dark Bangla/Latin ink strokes inside paper margins.
          if ((x + y * 3) % 7 != 0) {
            v -= 110;
          }
        }
        luma[y * width + x] = v.round().clamp(0, 255);
      } else {
        final v = bgBase + gradient * 0.4 + noise;
        luma[y * width + x] = v.round().clamp(0, 255);
      }
    }
  }
  return luma;
}

double _maxCornerErrorDiagonalFraction(
  DocumentQuad detected,
  List<(double, double)> truth,
) {
  final det = detected.points;
  var maxErr = 0.0;
  for (var i = 0; i < 4; i++) {
    final dx = det[i].x - truth[i].$1;
    final dy = det[i].y - truth[i].$2;
    final err = math.sqrt(dx * dx + dy * dy) / math.sqrt2;
    if (err > maxErr) maxErr = err;
  }
  return maxErr;
}

void main() {
  group('FrameAnalyzer corner accuracy & speed', () {
    test('detects corners within 2% of frame diagonal on >= 90% of 24 synthetic photo-like papers', () {
      final rng = math.Random(42);
      const total = 24;
      const w = 320;
      const h = 240;
      var withinTwoPercent = 0;
      final timingsMs = <int>[];

      for (var i = 0; i < total; i++) {
        // Vary scale, translation, and perspective tilt realistically.
        final cx = 0.50 + (rng.nextDouble() - 0.5) * 0.08;
        final cy = 0.50 + (rng.nextDouble() - 0.5) * 0.08;
        final halfW = 0.24 + rng.nextDouble() * 0.12;
        final halfH = 0.28 + rng.nextDouble() * 0.12;
        final tiltTop = (rng.nextDouble() - 0.5) * 0.06;
        final tiltSide = (rng.nextDouble() - 0.5) * 0.05;
        final perspectiveShrink = rng.nextDouble() * 0.04;

        final truth = <(double, double)>[
          (cx - halfW + perspectiveShrink + tiltSide, cy - halfH + tiltTop),
          (cx + halfW - perspectiveShrink + tiltSide, cy - halfH - tiltTop),
          (cx + halfW - tiltSide, cy + halfH - tiltTop * 0.5),
          (cx - halfW - tiltSide, cy + halfH + tiltTop * 0.5),
        ];

        final luma = _renderSyntheticPaperLuma(
          width: w,
          height: h,
          cornersNorm: truth,
          rng: rng,
          bgBase: 36 + rng.nextDouble() * 35,
          paperBase: 195 + rng.nextDouble() * 35,
          lightingSlope: (rng.nextDouble() - 0.5) * 36,
        );

        final analyzer = FrameAnalyzer();
        final res = analyzer.analyzeLuma(
          luma,
          width: w,
          height: h,
          timestampMs: 1000,
        );
        timingsMs.add(res.elapsedMs);

        if (res.quad != null) {
          final err = _maxCornerErrorDiagonalFraction(res.quad!, truth);
          if (err <= 0.02) {
            withinTwoPercent++;
          }
        }
      }

      timingsMs.sort();
      final medianMs = timingsMs[timingsMs.length ~/ 2];
      final passRate = withinTwoPercent / total;
      // Print exact measured values for M2 evidence.
      // ignore: avoid_print
      print(
        'M2 host corner accuracy: $withinTwoPercent/$total '
        '(${(passRate * 100).toStringAsFixed(1)}%), median=${medianMs}ms',
      );

      expect(passRate, greaterThanOrEqualTo(0.90));
      expect(medianMs, lessThanOrEqualTo(40));
    });

    test('quality hints trigger in priority order', () {
      const w = 320;
      const h = 240;
      final rng = math.Random(7);

      // 1. Uniform grey -> no paper found
      final blank = Uint8List.fromList(List<int>.filled(w * h, 110));
      final rNoPaper = FrameAnalyzer().analyzeLuma(
        blank,
        width: w,
        height: h,
        timestampMs: 0,
      );
      expect(rNoPaper.hint, CaptureQualityHint.noPaper);

      // 2. Very dark blank -> too dark
      final dark = Uint8List.fromList(List<int>.filled(w * h, 18));
      final rDark = FrameAnalyzer().analyzeLuma(
        dark,
        width: w,
        height: h,
        timestampMs: 0,
      );
      expect(rDark.hint, CaptureQualityHint.tooDark);

      // 3. Tiny paper (< 20% area) -> move closer
      final smallPaper = _renderSyntheticPaperLuma(
        width: w,
        height: h,
        cornersNorm: const [
          (0.36, 0.36),
          (0.64, 0.36),
          (0.64, 0.64),
          (0.36, 0.64),
        ],
        rng: rng,
      );
      final rCloser = FrameAnalyzer().analyzeLuma(
        smallPaper,
        width: w,
        height: h,
        timestampMs: 0,
      );
      expect(rCloser.hint, CaptureQualityHint.moveCloser);

      // 4. High glare (>= 22% near-white pixels inside paper) -> glare
      final glarePaper = _renderSyntheticPaperLuma(
        width: w,
        height: h,
        cornersNorm: const [
          (0.15, 0.12),
          (0.85, 0.12),
          (0.85, 0.88),
          (0.15, 0.88),
        ],
        rng: rng,
        paperBase: 255,
        lightingSlope: 0,
        drawTextLines: false,
      );
      final rGlare = FrameAnalyzer().analyzeLuma(
        glarePaper,
        width: w,
        height: h,
        timestampMs: 0,
      );
      expect(rGlare.hint, CaptureQualityHint.glare);
    });

    test('steadiness rule does not fire while moving, fires once steady >= 600ms', () {
      const w = 320;
      const h = 240;
      final rng = math.Random(11);
      final analyzer = FrameAnalyzer();

      // Moving sequence: shift paper by 5% each frame across 4 frames (800 ms)
      for (var step = 0; step < 4; step++) {
        final shift = step * 0.05;
        final luma = _renderSyntheticPaperLuma(
          width: w,
          height: h,
          cornersNorm: [
            (0.12 + shift, 0.12),
            (0.72 + shift, 0.12),
            (0.72 + shift, 0.86),
            (0.12 + shift, 0.86),
          ],
          rng: rng,
        );
        final res = analyzer.analyzeLuma(
          luma,
          width: w,
          height: h,
          timestampMs: step * 250,
        );
        expect(res.isSteady, isFalse);
      }

      // Now hold steady at fixed position for >= 600 ms.
      final steadyLuma = _renderSyntheticPaperLuma(
        width: w,
        height: h,
        cornersNorm: const [
          (0.18, 0.12),
          (0.82, 0.12),
          (0.82, 0.88),
          (0.18, 0.88),
        ],
        rng: rng,
      );
      var fired = false;
      for (var t = 1000; t <= 2000; t += 150) {
        final res = analyzer.analyzeLuma(
          steadyLuma,
          width: w,
          height: h,
          timestampMs: t,
        );
        if (res.isSteady) {
          fired = true;
          expect(t, greaterThanOrEqualTo(1600));
          break;
        }
      }
      expect(fired, isTrue);
    });

    test(
      'FrameAnalyzerIsolate processes encoded JPEGs in background isolate',
      () async {
        final image = img.Image(width: 320, height: 240);
        img.fill(image, color: img.ColorRgb8(40, 40, 40));
        img.fillRect(
          image,
          x1: 50,
          y1: 30,
          x2: 270,
          y2: 210,
          color: img.ColorRgb8(230, 228, 220),
        );
        final jpg = Uint8List.fromList(img.encodeJpg(image, quality: 85));

        final isolate = await FrameAnalyzerIsolate.spawn();
        addTearDown(isolate.dispose);

        final res = await isolate.analyzeEncoded(
          jpg,
          timestampMs: 100,
          skipBlurCheck: true,
        );
        expect(res.quad, isNotNull);
        expect(res.quad!.isValid, isTrue);
        expect(res.elapsedMs, lessThanOrEqualTo(100));
      },
    );
  });
}
