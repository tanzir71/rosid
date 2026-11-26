import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosid/features/capture/fake_capture_source.dart';

void main() {
  group('FakeCaptureSource', () {
    test('emits fixture frames and returns still bytes', () async {
      final fixtureFile = File('assets/fixtures/english_receipt.png');
      expect(fixtureFile.existsSync(), isTrue);

      final source = await FakeCaptureSource.fromFiles([
        fixtureFile,
      ], frameInterval: const Duration(milliseconds: 10));
      addTearDown(source.dispose);

      final frame = await source.frames.first;
      expect(frame.bytes, isNotEmpty);
      expect(frame.label, 'english_receipt.png');
      expect(frame.isSteady, isTrue);

      final still = await source.captureStill();
      expect(still, equals(frame.bytes));
    });

    test('advances through multi-frame sequence to steady frame', () async {
      final f1 = CaptureFrame(
        bytes: Uint8List.fromList([1, 2, 3]),
        width: 320,
        height: 240,
        isSteady: false,
        label: 'moving',
      );
      final f2 = CaptureFrame(
        bytes: Uint8List.fromList([4, 5, 6]),
        width: 320,
        height: 240,
        isSteady: true,
        label: 'steady',
      );
      final source = FakeCaptureSource(
        sequence: [f1, f2],
        frameInterval: const Duration(milliseconds: 10),
      );
      addTearDown(source.dispose);

      final emitted = await source.frames.take(2).toList();
      expect(emitted.map((e) => e.label), ['moving', 'steady']);
      expect(emitted.last.isSteady, isTrue);
    });

    test('kRosidFakeCameraEnabled is guarded by !kReleaseMode', () {
      // In debug/test without --dart-define=ROSID_FAKE_CAMERA=true, factory
      // returns null, proving fake capture stays dormant by default.
      expect(kReleaseMode, isFalse);
      if (!kRosidFakeCameraEnabled) {
        final maybe = maybeCreateFakeCaptureSource(
          sequence: [
            CaptureFrame(bytes: Uint8List.fromList([1]), width: 1, height: 1),
          ],
        );
        expect(maybe, isNull);
      }
    });
  });
}
