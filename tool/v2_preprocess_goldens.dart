import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as image;
import 'package:rosid/ocr/preprocess/document_quad.dart';
import 'package:rosid/ocr/preprocess/image_preprocessor.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

const v2AppPreprocessGoldenManifestPath =
    'test/fixtures/v2_preprocessing/app_reference_v1.json';
const v2AppPreprocessGoldenDigestPath =
    'test/fixtures/v2_preprocessing/app_reference_v1.sha256';

const _vectors = <_AppPreprocessVector>[
  _AppPreprocessVector(
    id: 'english-receipt-default',
    sourcePath: 'assets/fixtures/english_receipt.png',
    freezeProductionJpeg: true,
    quad: DocumentQuad(
      topLeft: NormalizedPoint(0.08, 0.07),
      topRight: NormalizedPoint(0.91, 0.10),
      bottomRight: NormalizedPoint(0.88, 0.93),
      bottomLeft: NormalizedPoint(0.10, 0.90),
    ),
    options: PreprocessOptions(),
  ),
  _AppPreprocessVector(
    id: 'mixed-bangla-receipt-quarter-turn',
    sourcePath: 'assets/fixtures/mixed_bangla_receipt.png',
    quad: DocumentQuad(
      topLeft: NormalizedPoint(0.07, 0.09),
      topRight: NormalizedPoint(0.93, 0.06),
      bottomRight: NormalizedPoint(0.90, 0.94),
      bottomLeft: NormalizedPoint(0.09, 0.92),
    ),
    options: PreprocessOptions(
      minimumDimension: 720,
      maximumDimension: 1400,
      adaptiveWindow: 25,
      thresholdBias: 9,
      deskew: false,
      rotationQuarterTurns: 1,
    ),
  ),
  _AppPreprocessVector(
    id: 'handwritten-bangla-deskew',
    sourcePath: 'assets/fixtures/handwritten_bangla_note.png',
    quad: DocumentQuad(
      topLeft: NormalizedPoint(0.06, 0.05),
      topRight: NormalizedPoint(0.94, 0.08),
      bottomRight: NormalizedPoint(0.91, 0.95),
      bottomLeft: NormalizedPoint(0.08, 0.92),
    ),
    options: PreprocessOptions(
      minimumDimension: 800,
      maximumDimension: 1400,
      adaptiveWindow: 21,
      thresholdBias: 8,
    ),
  ),
];

String buildV2AppPreprocessGoldenManifest() {
  const preprocessor = ImagePreprocessor();
  final vectors = <Map<String, Object?>>[];
  for (final vector in _vectors) {
    final encoded = File(vector.sourcePath).readAsBytesSync();
    final decoded = image.decodeImage(encoded);
    if (decoded == null) {
      throw FormatException('Cannot decode ${vector.sourcePath}');
    }
    final oriented = image.bakeOrientation(decoded);
    final sourceRgba = _rgbaBytes(oriented);
    final result = preprocessor.processPlanes(
      encoded,
      quad: vector.quad,
      options: vector.options,
    );
    final productionJpeg = vector.freezeProductionJpeg
        ? preprocessor.process(
            encoded,
            quad: vector.quad,
            options: vector.options,
          )
        : null;
    vectors.add(<String, Object?>{
      'id': vector.id,
      'source_path': vector.sourcePath,
      'source_encoded_byte_count': encoded.length,
      'source_encoded_sha256': _sha256(encoded),
      'source_plane': _planeRecord(
        bytes: sourceRgba,
        width: oriented.width,
        height: oriented.height,
        layout: 'rgba8',
        channels: 4,
      ),
      'quad': _quadRecord(vector.quad),
      'options': _optionsRecord(vector.options),
      'result': <String, Object?>{
        'width': result.width,
        'height': result.height,
        'deskew_half_degree_ticks': (result.deskewAngle * 2).round(),
        'deskew_angle_degrees': result.deskewAngle == 0
            ? 0.0
            : result.deskewAngle,
        'color_corrected_plane': _planeRecord(
          bytes: result.colorCorrectedRgba,
          width: result.width,
          height: result.height,
          layout: 'rgba8',
          channels: 4,
        ),
        'grayscale_plane': _planeRecord(
          bytes: result.grayscaleY8,
          width: result.width,
          height: result.height,
          layout: 'y8',
          channels: 1,
        ),
        'binarized_plane': _planeRecord(
          bytes: result.binarizedY8,
          width: result.width,
          height: result.height,
          layout: 'y8',
          channels: 1,
        ),
        if (productionJpeg != null)
          'v1_production_jpeg_regression': <String, Object>{
            'color_corrected': _blobRecord(productionJpeg.colorCorrectedJpeg),
            'binarized': _blobRecord(productionJpeg.binarizedJpeg),
          },
      },
    });
  }

  final manifest = <String, Object?>{
    'schema': 'rosid-v2-app-preprocess-goldens-v1',
    'scope': 'app_reference_only',
    'python_parity_status': 'not_implemented',
    'fixture_origin': 'synthetic_privacy_safe',
    'implementation':
        'lib/ocr/preprocess/image_preprocessor.dart#ImagePreprocessor.processPlanes',
    'manifest_serialization':
        'NFC UTF-8 JSON, recursively sorted keys, two-space indent, LF terminator',
    'pipeline_stages': <String>[
      'decode and bake orientation',
      'cap input longest dimension',
      'perspective warp from the fixed quad',
      'apply requested quarter-turn rotation',
      'fit configured dimensions with linear interpolation',
      'normalize percentile contrast',
      'convert to grayscale',
      'apply adaptive threshold',
      'estimate skew when enabled',
      'for absolute skew >= 0.5 degrees: rotate color, refit, and recompute grayscale and threshold',
    ],
    'excluded_stages': <String>[
      'document-quad detection',
      'JPEG encode/decode for cross-language parity',
      'line segmentation',
      'model tensor resize, padding, layout, dtype, and normalization',
    ],
    'source_decode': 'package:image decodeImage then bakeOrientation',
    'hash': 'sha256_lowercase_hex',
    'quad_serialization':
        'normalized millionths as integers; divide each value by 1000000',
    'plane_serialization': <String, Object?>{
      'pixel_order': 'top-to-bottom rows, left-to-right pixels',
      'packing': 'tightly packed with no row padding',
      'color': 'R8,G8,B8,A8 channel order',
      'grayscale': 'Y8 from the opaque grayscale pixel red channel',
      'binarized': 'Y8 restricted to 0 or 255',
      'hash_scope': 'plane payload bytes only',
      'jpeg_container_included': false,
    },
    'v1_jpeg_regression_scope':
        'app-code regression only; excluded from cross-language plane parity',
    'vectors': vectors,
  };
  final canonical = _canonicalJsonValue(manifest);
  return '${const JsonEncoder.withIndent('  ').convert(canonical)}\n';
}

String buildV2AppPreprocessGoldenDigestRecord(String manifest) {
  final digest = _sha256(Uint8List.fromList(utf8.encode(manifest)));
  return '$digest  app_reference_v1.json\n';
}

Map<String, Object> _planeRecord({
  required Uint8List bytes,
  required int width,
  required int height,
  required String layout,
  required int channels,
}) {
  final expectedBytes = width * height * channels;
  if (bytes.length != expectedBytes) {
    throw StateError(
      '$layout plane has ${bytes.length} bytes; expected $expectedBytes',
    );
  }
  final minimums = List<int>.filled(channels, 255);
  final maximums = List<int>.filled(channels, 0);
  var zeroCount = 0;
  var fullScaleCount = 0;
  for (var offset = 0; offset < bytes.length; offset += channels) {
    for (var channel = 0; channel < channels; channel++) {
      final value = bytes[offset + channel];
      if (value < minimums[channel]) minimums[channel] = value;
      if (value > maximums[channel]) maximums[channel] = value;
      if (channels == 1 && value == 0) zeroCount++;
      if (channels == 1 && value == 255) fullScaleCount++;
    }
  }
  final result = <String, Object>{
    'layout': layout,
    'width': width,
    'height': height,
    'channels': channels,
    'byte_count': bytes.length,
    'channel_minimums': minimums,
    'channel_maximums': maximums,
    'sha256': _sha256(bytes),
  };
  if (channels == 1) {
    result['zero_count'] = zeroCount;
    result['full_scale_count'] = fullScaleCount;
  }
  return result;
}

Map<String, Object> _blobRecord(Uint8List bytes) => <String, Object>{
  'byte_count': bytes.length,
  'sha256': _sha256(bytes),
};

Map<String, Object> _quadRecord(DocumentQuad quad) => <String, Object>{
  'top_left': <int>[_millionths(quad.topLeft.x), _millionths(quad.topLeft.y)],
  'top_right': <int>[
    _millionths(quad.topRight.x),
    _millionths(quad.topRight.y),
  ],
  'bottom_right': <int>[
    _millionths(quad.bottomRight.x),
    _millionths(quad.bottomRight.y),
  ],
  'bottom_left': <int>[
    _millionths(quad.bottomLeft.x),
    _millionths(quad.bottomLeft.y),
  ],
};

int _millionths(double value) => (value * 1000000).round();

Map<String, Object> _optionsRecord(PreprocessOptions options) =>
    <String, Object>{
      'minimum_dimension': options.minimumDimension,
      'maximum_dimension': options.maximumDimension,
      'adaptive_window': options.adaptiveWindow,
      'threshold_bias': options.thresholdBias,
      'deskew': options.deskew,
      'rotation_quarter_turns': options.rotationQuarterTurns,
    };

Uint8List _rgbaBytes(image.Image source) {
  final bytes = Uint8List(source.width * source.height * 4);
  var offset = 0;
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      final pixel = source.getPixel(x, y);
      bytes[offset++] = pixel.r.toInt();
      bytes[offset++] = pixel.g.toInt();
      bytes[offset++] = pixel.b.toInt();
      bytes[offset++] = pixel.a.toInt();
    }
  }
  return bytes;
}

String _sha256(Uint8List bytes) => sha256.convert(bytes).toString();

Object? _canonicalJsonValue(Object? value) {
  if (value == null || value is bool || value is int) return value;
  if (value is double) {
    if (!value.isFinite) {
      throw StateError('Canonical JSON cannot contain a non-finite number');
    }
    return value;
  }
  if (value is String) return unorm.nfc(value);
  if (value is List<Object?>) {
    return value.map<Object?>(_canonicalJsonValue).toList(growable: false);
  }
  if (value is Map<String, Object?>) {
    final result = SplayTreeMap<String, Object?>();
    for (final entry in value.entries) {
      final key = unorm.nfc(entry.key);
      if (result.containsKey(key)) {
        throw StateError('Canonical JSON keys collide after NFC normalization');
      }
      result[key] = _canonicalJsonValue(entry.value);
    }
    return result;
  }
  throw StateError('Unsupported canonical JSON value: ${value.runtimeType}');
}

class _AppPreprocessVector {
  const _AppPreprocessVector({
    required this.id,
    required this.sourcePath,
    required this.quad,
    required this.options,
    this.freezeProductionJpeg = false,
  });

  final String id;
  final String sourcePath;
  final DocumentQuad quad;
  final PreprocessOptions options;
  final bool freezeProductionJpeg;
}
