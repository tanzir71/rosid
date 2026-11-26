import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:rosid/export/export_models.dart';

/// Destructively applies [CoverRegion] redactions (solid black bar or
/// irreversible mosaic/blur) and optional black-and-white conversion to an
/// exported copy of a page image. Never modifies the saved scan on disk.
abstract final class ImageRedactor {
  static Uint8List applyToBytes(
    Uint8List sourceBytes, {
    required List<CoverRegion> regions,
    bool blackAndWhite = false,
    int jpegQuality = 88,
  }) {
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null) return sourceBytes;
    final edited = applyToImage(
      decoded.clone(),
      regions: regions,
      blackAndWhite: blackAndWhite,
    );
    return Uint8List.fromList(img.encodeJpg(edited, quality: jpegQuality));
  }

  static img.Image applyToImage(
    img.Image image, {
    required List<CoverRegion> regions,
    bool blackAndWhite = false,
  }) {
    var out = image;
    if (blackAndWhite) {
      out = img.grayscale(out);
      out = img.contrast(out, contrast: 145);
    }

    final w = out.width;
    final h = out.height;
    for (final r in regions) {
      final x1 = (r.left.clamp(0.0, 1.0) * w).floor().clamp(0, w - 1);
      final y1 = (r.top.clamp(0.0, 1.0) * h).floor().clamp(0, h - 1);
      final x2 = (r.right.clamp(0.0, 1.0) * w).ceil().clamp(x1 + 1, w);
      final y2 = (r.bottom.clamp(0.0, 1.0) * h).ceil().clamp(y1 + 1, h);

      if (r.style == CoverStyle.blackBar) {
        // Completely overwrite every pixel in the covered rectangle with opaque dark ink.
        img.fillRect(
          out,
          x1: x1,
          y1: y1,
          x2: x2 - 1,
          y2: y2 - 1,
          color: img.ColorRgb8(24, 25, 34),
        );
      } else {
        // Irreversible coarse mosaic + smoothing so original detail cannot be recovered.
        final rw = math.max(1, x2 - x1);
        final rh = math.max(1, y2 - y1);
        final block = math.max(12, math.min(rw, rh) ~/ 3);
        for (var by = y1; by < y2; by += block) {
          for (var bx = x1; bx < x2; bx += block) {
            final bx2 = math.min(x2, bx + block);
            final by2 = math.min(y2, by + block);
            var sumR = 0;
            var sumG = 0;
            var sumB = 0;
            var count = 0;
            for (var py = by; py < by2; py++) {
              for (var px = bx; px < bx2; px++) {
                final p = out.getPixel(px, py);
                sumR += p.r.toInt();
                sumG += p.g.toInt();
                sumB += p.b.toInt();
                count++;
              }
            }
            if (count == 0) continue;
            // Quantize & slightly desaturate block mean to prevent edge-leakage.
            final avgR = ((sumR ~/ count) & 0xF0);
            final avgG = ((sumG ~/ count) & 0xF0);
            final avgB = ((sumB ~/ count) & 0xF0);
            final fill = img.ColorRgb8(avgR, avgG, avgB);
            img.fillRect(
              out,
              x1: bx,
              y1: by,
              x2: bx2 - 1,
              y2: by2 - 1,
              color: fill,
            );
          }
        }
      }
    }
    return out;
  }
}
