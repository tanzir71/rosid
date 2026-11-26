import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;
import 'package:rosid/ocr/pipeline/reading_interfaces.dart';

/// PP-OCRv5 English mobile line recogniser backed by `flutter_onnxruntime`.
/// Resizes line crops to H=48 (rotating vertical strips where H > 1.5*W),
/// runs ONNX inference, and decodes CTC logits with greedy decoding + mean
/// softmax character confidence.
class OnnxLatinLineRecognizer implements LineRecognizer {
  OnnxLatinLineRecognizer({
    this.modelAssetPath = 'assets/models/ocr/ppocr_v5_en_mobile_rec.onnx',
    this.dictAssetPath = 'assets/models/ocr/ppocr_v5_en_dict.txt',
  });

  final String modelAssetPath;
  final String dictAssetPath;

  OrtSession? _session;
  List<String>? _dict;

  @override
  String get id => 'ppocr-v5-en-onnx';

  Future<OrtSession> _ensureSession() async {
    return _session ??= await OnnxRuntime().createSessionFromAsset(
      modelAssetPath,
      options: OrtSessionOptions(intraOpNumThreads: 2),
    );
  }

  Future<List<String>> _ensureDict() async {
    if (_dict != null) return _dict!;
    final raw = await rootBundle.loadString(dictAssetPath);
    final chars = <String>['<blank>'];
    for (final line in raw.split('\n')) {
      final clean = line.replaceAll('\r', '');
      if (clean.isEmpty && chars.length > 436) continue;
      chars.add(clean.isEmpty ? ' ' : clean);
    }
    _dict = chars;
    return chars;
  }

  Future<void> dispose() async {
    final s = _session;
    _session = null;
    if (s != null) await s.close();
  }

  @override
  Future<LineRecognition> recognize(img.Image lineCrop) async {
    if (lineCrop.width < 4 || lineCrop.height < 4) {
      return LineRecognition(text: '', confidence: 0, engineId: id);
    }
    final session = await _ensureSession();
    final dict = await _ensureDict();

    // Rotate 90 deg if line crop is vertically oriented (height > 1.5 * width).
    final oriented = lineCrop.height > lineCrop.width * 1.5
        ? img.copyRotate(lineCrop, angle: 90)
        : lineCrop;

    const targetH = 48;
    final ratio = oriented.width / oriented.height;
    final targetW = (targetH * ratio).ceil().clamp(32, 1600);
    final resized = img.copyResize(
      oriented,
      width: targetW,
      height: targetH,
      interpolation: img.Interpolation.linear,
    );

    final plane = targetH * targetW;
    final tensor = Float32List(3 * plane);
    for (var y = 0; y < targetH; y++) {
      final row = y * targetW;
      for (var x = 0; x < targetW; x++) {
        final p = resized.getPixel(x, y);
        final idx = row + x;
        tensor[idx] = (p.b / 255.0 - 0.5) / 0.5;
        tensor[plane + idx] = (p.g / 255.0 - 0.5) / 0.5;
        tensor[2 * plane + idx] = (p.r / 255.0 - 0.5) / 0.5;
      }
    }

    final inputName = session.inputNames.isNotEmpty
        ? session.inputNames.first
        : 'x';
    final inputTensor = await OrtValue.fromList(tensor, [
      1,
      3,
      targetH,
      targetW,
    ]);
    Map<String, OrtValue>? outputs;
    try {
      outputs = await session.run({inputName: inputTensor});
      final outVal = outputs.values.first;
      final shape = outVal.shape; // [1, T, C]
      final timeSteps = shape.length >= 2 ? shape[1] : 0;
      final numClasses = shape.length >= 3 ? shape[2] : dict.length;
      final flat = await outVal.asFlattenedList();
      final logits = Float32List(flat.length);
      for (var i = 0; i < flat.length; i++) {
        logits[i] = (flat[i] as num).toDouble();
      }
      final (text, conf) = ctcGreedyDecode(
        logits,
        timeSteps: timeSteps,
        numClasses: numClasses,
        dict: dict,
      );
      return LineRecognition(text: text, confidence: conf, engineId: id);
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

/// Pure-Dart CTC greedy decoder returning `(decodedText, meanCharConfidence)`.
(String, double) ctcGreedyDecode(
  Float32List logits, {
  required int timeSteps,
  required int numClasses,
  required List<String> dict,
}) {
  if (timeSteps <= 0 || numClasses <= 1) return ('', 0.0);
  final buf = StringBuffer();
  var confSum = 0.0;
  var confCount = 0;
  var prevIdx = -1;

  for (var t = 0; t < timeSteps; t++) {
    final base = t * numClasses;
    if (base + numClasses > logits.length) break;

    var maxIdx = 0;
    var maxVal = logits[base];
    for (var c = 1; c < numClasses; c++) {
      final v = logits[base + c];
      if (v > maxVal) {
        maxVal = v;
        maxIdx = c;
      }
    }

    if (maxIdx != 0 && maxIdx != prevIdx && maxIdx < dict.length) {
      // Softmax probability of argmax class for calibrated confidence.
      var expSum = 0.0;
      for (var c = 0; c < numClasses; c++) {
        expSum += math.exp(logits[base + c] - maxVal);
      }
      final prob = expSum > 0 ? 1.0 / expSum : 0.0;
      buf.write(dict[maxIdx]);
      confSum += prob;
      confCount++;
    }
    prevIdx = maxIdx;
  }

  final text = buf.toString().trim();
  final meanConf = confCount == 0 ? 0.0 : (confSum / confCount).clamp(0.0, 1.0);
  return (text, meanConf);
}
