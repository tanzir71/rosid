import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;
import 'package:rosid/ocr/pipeline/reading_interfaces.dart';

/// PP-OCRv5 mobile line detector backed by `flutter_onnxruntime` (ONNX Runtime
/// 1.28.0). Heavy tensor prep and DB probability-map post-processing run inside
/// background isolates so the UI thread is never blocked.
class OnnxLineDetector implements LineDetector {
  OnnxLineDetector({
    this.modelAssetPath = 'assets/models/ocr/ppocr_v5_mobile_det.onnx',
    this.maxLongSide = 960,
    this.probThreshold = 0.30,
    this.boxThreshold = 0.55,
  });

  final String modelAssetPath;
  final int maxLongSide;
  final double probThreshold;
  final double boxThreshold;

  OrtSession? _session;

  Future<OrtSession> _ensureSession() async {
    return _session ??= await OnnxRuntime().createSessionFromAsset(
      modelAssetPath,
      options: OrtSessionOptions(intraOpNumThreads: 2),
    );
  }

  Future<void> dispose() async {
    final s = _session;
    _session = null;
    if (s != null) await s.close();
  }

  @override
  Future<List<DetectedLineBox>> detect(img.Image greyPage) async {
    final session = await _ensureSession();
    final origW = greyPage.width;
    final origH = greyPage.height;
    final rawPixels = Uint8List.fromList(greyPage.toUint8List());
    final channels = greyPage.numChannels;
    final maxSide = maxLongSide;

    // 1. Prepare NCHW float32 tensor in isolate.
    final prep = await Isolate.run(
      () => _prepareDetTensor(rawPixels, origW, origH, channels, maxSide),
    );

    final inputName = session.inputNames.isNotEmpty
        ? session.inputNames.first
        : 'x';
    final inputTensor = await OrtValue.fromList(prep.tensor, [
      1,
      3,
      prep.nh,
      prep.nw,
    ]);
    Map<String, OrtValue>? outputs;
    try {
      outputs = await session.run({inputName: inputTensor});
      final outVal = outputs.values.first;
      final flat = await outVal.asFlattenedList();
      final probs = Float32List(flat.length);
      for (var i = 0; i < flat.length; i++) {
        probs[i] = (flat[i] as num).toDouble();
      }
      final thresh = probThreshold;
      final boxThresh = boxThreshold;
      return await Isolate.run(
        () => extractLineBoxesFromProbMap(
          probs,
          mapWidth: prep.nw,
          mapHeight: prep.nh,
          origWidth: origW,
          origHeight: origH,
          probThreshold: thresh,
          boxThreshold: boxThresh,
        ),
      );
    } finally {
      await inputTensor.dispose();
      if (outputs != null) {
        for (final v in outputs.values) {
          await v.dispose();
        }
      }
    }
  }
}

class _DetTensorPrep {
  const _DetTensorPrep(this.tensor, this.nw, this.nh);

  final Float32List tensor;
  final int nw;
  final int nh;
}

_DetTensorPrep _prepareDetTensor(
  Uint8List rawPixels,
  int origW,
  int origH,
  int channels,
  int maxLongSide,
) {
  final src = img.Image.fromBytes(
    width: origW,
    height: origH,
    bytes: rawPixels.buffer,
    numChannels: channels,
  );
  final longest = math.max(origW, origH);
  final scale = math.min(1.0, maxLongSide / longest);
  final nh = math.max(32, ((origH * scale) / 32.0).round() * 32);
  final nw = math.max(32, ((origW * scale) / 32.0).round() * 32);
  final resized = img.copyResize(
    src,
    width: nw,
    height: nh,
    interpolation: img.Interpolation.linear,
  );

  // ImageNet BGR normalization per ppocr_v5_mobile_det.yml
  const mean0 = 0.485;
  const mean1 = 0.456;
  const mean2 = 0.406;
  const std0 = 0.229;
  const std1 = 0.224;
  const std2 = 0.225;

  final planeSize = nw * nh;
  final data = Float32List(3 * planeSize);
  for (var y = 0; y < nh; y++) {
    final rowOff = y * nw;
    for (var x = 0; x < nw; x++) {
      final p = resized.getPixel(x, y);
      final b = p.b / 255.0;
      final g = p.g / 255.0;
      final r = p.r / 255.0;
      final idx = rowOff + x;
      data[idx] = (b - mean0) / std0;
      data[planeSize + idx] = (g - mean1) / std1;
      data[2 * planeSize + idx] = (r - mean2) / std2;
    }
  }
  return _DetTensorPrep(data, nw, nh);
}

/// Pure-Dart DBNet probability-map postprocessor: connected-component grouping,
/// box-score filtering, Bangla-safe vertical unclipping (preserves tall ি/ী/ৌ
/// ascenders and ু/ূ/ৃ descenders), horizontal same-line merging, and vertical
/// midpoint clamping.
List<DetectedLineBox> extractLineBoxesFromProbMap(
  Float32List probMap, {
  required int mapWidth,
  required int mapHeight,
  required int origWidth,
  required int origHeight,
  double probThreshold = 0.30,
  double boxThreshold = 0.55,
}) {
  final n = mapWidth * mapHeight;
  if (probMap.length < n || mapWidth <= 0 || mapHeight <= 0) {
    return const [];
  }

  final visited = Uint8List(n);
  final queue = Int32List(n);
  final sx = origWidth / mapWidth;
  final sy = origHeight / mapHeight;

  final rawBoxes = <List<double>>[]; // [x0, y0, x1, y1, score]

  for (var y = 0; y < mapHeight; y++) {
    for (var x = 0; x < mapWidth; x++) {
      final start = y * mapWidth + x;
      if (visited[start] != 0 || probMap[start] <= probThreshold) continue;

      var head = 0;
      var tail = 0;
      queue[tail++] = start;
      visited[start] = 1;

      var minX = x;
      var maxX = x;
      var minY = y;
      var maxY = y;
      var probSum = 0.0;

      while (head < tail) {
        final idx = queue[head++];
        final cx = idx % mapWidth;
        final cy = idx ~/ mapWidth;
        probSum += probMap[idx];
        if (cx < minX) minX = cx;
        if (cx > maxX) maxX = cx;
        if (cy < minY) minY = cy;
        if (cy > maxY) maxY = cy;

        if (cx > 0 &&
            visited[idx - 1] == 0 &&
            probMap[idx - 1] > probThreshold) {
          visited[idx - 1] = 1;
          queue[tail++] = idx - 1;
        }
        if (cx + 1 < mapWidth &&
            visited[idx + 1] == 0 &&
            probMap[idx + 1] > probThreshold) {
          visited[idx + 1] = 1;
          queue[tail++] = idx + 1;
        }
        if (cy > 0 &&
            visited[idx - mapWidth] == 0 &&
            probMap[idx - mapWidth] > probThreshold) {
          visited[idx - mapWidth] = 1;
          queue[tail++] = idx - mapWidth;
        }
        if (cy + 1 < mapHeight &&
            visited[idx + mapWidth] == 0 &&
            probMap[idx + mapWidth] > probThreshold) {
          visited[idx + mapWidth] = 1;
          queue[tail++] = idx + mapWidth;
        }
      }

      if (tail < 12) continue;
      final meanScore = probSum / tail;
      if (meanScore < boxThreshold) continue;

      final bh = (maxY - minY + 1).toDouble();
      final padTop = math.max(8.0, bh * 0.90);
      final padBot = math.max(6.0, bh * 0.65);
      final padX = math.max(8.0, bh * 0.60);

      final x0 = math.max(0.0, (minX - padX) * sx);
      final y0 = math.max(0.0, (minY - padTop) * sy);
      final x1 = math.min(origWidth.toDouble(), (maxX + 1 + padX) * sx);
      final y1 = math.min(origHeight.toDouble(), (maxY + 1 + padBot) * sy);
      if (x1 - x0 >= 8 && y1 - y0 >= 8) {
        rawBoxes.add([x0, y0, x1, y1, meanScore]);
      }
    }
  }

  rawBoxes.sort((a, b) {
    final cmp = a[1].compareTo(b[1]);
    return cmp != 0 ? cmp : a[0].compareTo(b[0]);
  });

  // Merge horizontally aligned fragments on the same text line.
  final merged = <List<double>>[];
  for (final b in rawBoxes) {
    final cy = (b[1] + b[3]) / 2.0;
    final bh = b[3] - b[1];
    var placed = false;
    for (final m in merged) {
      final mcy = (m[1] + m[3]) / 2.0;
      final mh = m[3] - m[1];
      if ((cy - mcy).abs() < math.max(bh, mh) * 0.36) {
        m[0] = math.min(m[0], b[0]);
        m[1] = math.min(m[1], b[1]);
        m[2] = math.max(m[2], b[2]);
        m[3] = math.max(m[3], b[3]);
        m[4] = math.max(m[4], b[4]);
        placed = true;
        break;
      }
    }
    if (!placed) merged.add(List<double>.from(b));
  }

  merged.sort((a, b) => ((a[1] + a[3]) / 2).compareTo((b[1] + b[3]) / 2));
  for (var i = 0; i < merged.length - 1; i++) {
    if (merged[i][3] > merged[i + 1][1]) {
      final mid = (merged[i][3] + merged[i + 1][1]) / 2.0;
      merged[i][3] = math.max(merged[i][1] + 8.0, mid);
      merged[i + 1][1] = math.min(merged[i + 1][3] - 8.0, mid);
    }
  }

  return [
    for (final m in merged)
      DetectedLineBox(
        topLeft: (m[0], m[1]),
        topRight: (m[2], m[1]),
        bottomRight: (m[2], m[3]),
        bottomLeft: (m[0], m[3]),
        score: m[4].clamp(0.0, 1.0),
      ),
  ];
}
