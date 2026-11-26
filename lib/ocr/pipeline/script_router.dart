import 'dart:math' as math;

import 'package:image/image.dart' as img;

enum LineScriptRoute { latin, bangla, unsure }

/// Per-line script router (`handover/02-architecture.md`):
/// Bangla printed lines exhibit a continuous horizontal head-line (matra) band
/// in the upper third of the tight glyph bounding box. When unsure, the
/// pipeline runs both recognisers and keeps the more confident result.
class ScriptRouter {
  const ScriptRouter({this.banglaThreshold = 0.42, this.latinThreshold = 0.28});

  final double banglaThreshold;
  final double latinThreshold;

  /// Measures normalized peak horizontal ink density in the upper 14%–48% band
  /// of the tight ink crop.
  double matraScore(img.Image crop) {
    final w = crop.width;
    final h = crop.height;
    if (w < 12 || h < 8) return 0.0;

    // Compute Otsu-like threshold from mean luminance.
    var sum = 0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        sum += crop.getPixel(x, y).r.toInt();
      }
    }
    final threshold = ((sum / (w * h)) * 0.78).round().clamp(40, 210);

    var minX = w;
    var maxX = -1;
    var minY = h;
    var maxY = -1;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (crop.getPixel(x, y).r < threshold) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    if (maxX <= minX || maxY <= minY) return 0.0;

    final tightW = maxX - minX + 1;
    final tightH = maxY - minY + 1;
    if (tightW < 12 || tightH < 6) return 0.0;

    final bandStart = minY + (tightH * 0.04).floor();
    final bandEnd = math.min(
      maxY,
      math.max(bandStart + 1, minY + (tightH * 0.48).ceil()),
    );

    var maxDensity = 0.0;
    for (var y = bandStart; y <= bandEnd; y++) {
      var dark = 0;
      for (var x = minX; x <= maxX; x++) {
        if (crop.getPixel(x, y).r < threshold) dark++;
      }
      final density = dark / tightW;
      if (density > maxDensity) maxDensity = density;
    }
    return maxDensity;
  }

  /// Estimates stroke-width irregularity (coefficient of variation of horizontal
  /// dark run lengths). Handwriting exhibits significantly higher stroke-width
  /// variance than uniform printed typefaces.
  double strokeWidthVariance(img.Image crop) {
    final w = crop.width;
    final h = crop.height;
    if (w < 12 || h < 8) return 0.0;

    var sum = 0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        sum += crop.getPixel(x, y).r.toInt();
      }
    }
    final threshold = ((sum / (w * h)) * 0.78).round().clamp(40, 210);

    final runs = <int>[];
    for (var y = 0; y < h; y += 2) {
      var run = 0;
      for (var x = 0; x < w; x++) {
        if (crop.getPixel(x, y).r < threshold) {
          run++;
        } else if (run > 0) {
          if (run <= 24) runs.add(run);
          run = 0;
        }
      }
      if (run > 0 && run <= 24) runs.add(run);
    }
    if (runs.length < 8) return 0.0;
    final mean = runs.reduce((a, b) => a + b) / runs.length;
    if (mean <= 0) return 0.0;
    var sq = 0.0;
    for (final r in runs) {
      final d = r - mean;
      sq += d * d;
    }
    final std = math.sqrt(sq / runs.length);
    return std / mean;
  }

  LineScriptRoute route(img.Image crop) {
    final score = matraScore(crop);
    if (score >= banglaThreshold) return LineScriptRoute.bangla;
    if (score <= latinThreshold) return LineScriptRoute.latin;
    return LineScriptRoute.unsure;
  }

  static String classifyTextScript(String text) {
    var bn = 0;
    var latin = 0;
    for (final rune in text.runes) {
      if (rune >= 0x0980 && rune <= 0x09FF) {
        bn++;
      } else if ((rune >= 0x41 && rune <= 0x5A) ||
          (rune >= 0x61 && rune <= 0x7A)) {
        latin++;
      }
    }
    if (bn > 0 && latin > 0) return 'mixed';
    if (bn > 0) return 'bn';
    return 'en';
  }
}
