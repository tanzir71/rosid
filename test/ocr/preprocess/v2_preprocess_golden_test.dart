import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/v2_preprocess_goldens.dart';

void main() {
  test('tracked V2 app preprocessing reference matches exact raw planes', () {
    final generated = buildV2AppPreprocessGoldenManifest();
    final tracked = File(v2AppPreprocessGoldenManifestPath).readAsStringSync();
    expect(
      generated,
      tracked,
      reason:
          'Run dart run tool/generate_v2_preprocess_goldens.dart and review '
          'every changed plane hash.',
    );
    expect(
      File(v2AppPreprocessGoldenDigestPath).readAsStringSync(),
      buildV2AppPreprocessGoldenDigestRecord(tracked),
    );

    final manifest = jsonDecode(tracked) as Map<String, dynamic>;
    expect(manifest['schema'], 'rosid-v2-app-preprocess-goldens-v1');
    expect(manifest['scope'], 'app_reference_only');
    expect(manifest['python_parity_status'], 'not_implemented');
    final vectors = manifest['vectors'] as List<dynamic>;
    expect(
      vectors.map((value) => (value as Map<String, dynamic>)['id']),
      orderedEquals(<String>[
        'english-receipt-default',
        'mixed-bangla-receipt-quarter-turn',
        'handwritten-bangla-deskew',
      ]),
    );
    for (final value in vectors) {
      final vector = value as Map<String, dynamic>;
      _expectPlane(vector['source_plane'] as Map<String, dynamic>);
      final options = vector['options'] as Map<String, dynamic>;
      final result = vector['result'] as Map<String, dynamic>;
      final deskewAngle = (result['deskew_angle_degrees'] as num).toDouble();
      final deskewTicks = result['deskew_half_degree_ticks'] as int;
      expect(deskewAngle, deskewTicks / 2);
      if (vector['id'] == 'handwritten-bangla-deskew') {
        expect(deskewAngle.abs(), greaterThanOrEqualTo(0.5));
      }
      if (vector['id'] == 'mixed-bangla-receipt-quarter-turn') {
        expect(options['rotation_quarter_turns'], 1);
        expect(options['deskew'], isFalse);
        expect(result['width'] as int, greaterThan(result['height'] as int));
      }
      final color = result['color_corrected_plane'] as Map<String, dynamic>;
      final grayscale = result['grayscale_plane'] as Map<String, dynamic>;
      final binarized = result['binarized_plane'] as Map<String, dynamic>;
      _expectPlane(color);
      _expectPlane(grayscale);
      _expectPlane(binarized);
      expect(
        (grayscale['channel_minimums'] as List<dynamic>).single,
        lessThan(128),
      );
      expect(
        (grayscale['channel_maximums'] as List<dynamic>).single,
        greaterThan(128),
      );
      final pixelCount = binarized['byte_count'] as int;
      final blackPixels = binarized['zero_count'] as int;
      final whitePixels = binarized['full_scale_count'] as int;
      expect(blackPixels + whitePixels, pixelCount);
      expect(blackPixels, greaterThan(pixelCount ~/ 1000));
      expect(whitePixels, greaterThan(pixelCount ~/ 10));
      final jpegRegression = result['v1_production_jpeg_regression'];
      if (vector['id'] == 'english-receipt-default') {
        expect(jpegRegression, isA<Map<String, dynamic>>());
        final blobs = jpegRegression as Map<String, dynamic>;
        _expectBlob(blobs['color_corrected'] as Map<String, dynamic>);
        _expectBlob(blobs['binarized'] as Map<String, dynamic>);
      } else {
        expect(jpegRegression, isNull);
      }
    }
  });
}

void _expectPlane(Map<String, dynamic> plane) {
  final width = plane['width'] as int;
  final height = plane['height'] as int;
  final channels = plane['channels'] as int;
  expect(width, greaterThan(0));
  expect(height, greaterThan(0));
  expect(channels, anyOf(1, 4));
  expect(plane['byte_count'], width * height * channels);
  final minimums = plane['channel_minimums'] as List<dynamic>;
  final maximums = plane['channel_maximums'] as List<dynamic>;
  expect(minimums, hasLength(channels));
  expect(maximums, hasLength(channels));
  for (var index = 0; index < channels; index++) {
    expect(minimums[index] as int, inInclusiveRange(0, 255));
    expect(maximums[index] as int, inInclusiveRange(0, 255));
    expect(minimums[index] as int, lessThanOrEqualTo(maximums[index] as int));
  }
  expect(
    plane['sha256'],
    isA<String>().having(
      (value) => RegExp(r'^[0-9a-f]{64}$').hasMatch(value),
      'lowercase SHA-256',
      isTrue,
    ),
  );
}

void _expectBlob(Map<String, dynamic> blob) {
  expect(blob['byte_count'] as int, greaterThan(0));
  expect(
    blob['sha256'],
    isA<String>().having(
      (value) => RegExp(r'^[0-9a-f]{64}$').hasMatch(value),
      'lowercase SHA-256',
      isTrue,
    ),
  );
}
