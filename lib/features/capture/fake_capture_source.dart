import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Compile-time flag for debug/test fake capture injection.
/// Always evaluates to `false` in release builds so AOT tree-shaking strips
/// [FakeCaptureSource] completely from release APKs.
const bool kRosidFakeCameraEnabled =
    !kReleaseMode && bool.fromEnvironment('ROSID_FAKE_CAMERA');

/// A single frame emitted by a capture source (camera stream or fake fixture).
class CaptureFrame {
  const CaptureFrame({
    required this.bytes,
    required this.width,
    required this.height,
    this.isSteady = false,
    this.label = '',
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final bool isSteady;
  final String label;
}

/// Abstract source of preview frames and still captures.
abstract interface class CaptureFrameSource {
  Stream<CaptureFrame> get frames;

  Future<Uint8List> captureStill();

  Future<void> dispose();
}

/// Debug- and test-only capture source that feeds fixture images through the
/// same pipeline as a live camera. Never instantiated in release builds.
class FakeCaptureSource implements CaptureFrameSource {
  FakeCaptureSource({
    required List<CaptureFrame> sequence,
    this.frameInterval = const Duration(milliseconds: 50),
  }) : _sequence = List<CaptureFrame>.unmodifiable(sequence) {
    if (kReleaseMode) {
      throw UnsupportedError(
        'FakeCaptureSource is not permitted in release builds.',
      );
    }
    if (_sequence.isEmpty) {
      throw ArgumentError.value(
        sequence,
        'sequence',
        'At least one fixture frame is required.',
      );
    }
  }

  /// Creates a [FakeCaptureSource] from image files on disk.
  static Future<FakeCaptureSource> fromFiles(
    List<File> files, {
    int width = 320,
    int height = 240,
    Duration frameInterval = const Duration(milliseconds: 50),
  }) async {
    if (kReleaseMode) {
      throw UnsupportedError(
        'FakeCaptureSource is not permitted in release builds.',
      );
    }
    final frames = <CaptureFrame>[];
    for (var i = 0; i < files.length; i++) {
      final bytes = await files[i].readAsBytes();
      frames.add(
        CaptureFrame(
          bytes: bytes,
          width: width,
          height: height,
          isSteady: i == files.length - 1,
          label: files[i].uri.pathSegments.last,
        ),
      );
    }
    return FakeCaptureSource(sequence: frames, frameInterval: frameInterval);
  }

  final List<CaptureFrame> _sequence;
  final Duration frameInterval;
  final StreamController<CaptureFrame> _controller =
      StreamController<CaptureFrame>.broadcast();
  Timer? _timer;
  int _index = 0;
  bool _disposed = false;

  @override
  Stream<CaptureFrame> get frames {
    _ensureStarted();
    return _controller.stream;
  }

  void _ensureStarted() {
    if (_timer != null || _disposed) return;
    _timer = Timer.periodic(frameInterval, (_) {
      if (_disposed || _controller.isClosed) return;
      final frame = _sequence[_index];
      _controller.add(frame);
      if (_index < _sequence.length - 1) {
        _index++;
      }
    });
  }

  @override
  Future<Uint8List> captureStill() async {
    if (kReleaseMode) {
      throw UnsupportedError(
        'FakeCaptureSource is not permitted in release builds.',
      );
    }
    if (_disposed) {
      throw StateError('FakeCaptureSource has been disposed.');
    }
    final idx = _index.clamp(0, _sequence.length - 1);
    return _sequence[idx].bytes;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    await _controller.close();
  }
}

/// Factory that only returns a [FakeCaptureSource] when compiled with
/// `--dart-define=ROSID_FAKE_CAMERA=true` in non-release mode.
CaptureFrameSource? maybeCreateFakeCaptureSource({
  required List<CaptureFrame> sequence,
  Duration frameInterval = const Duration(milliseconds: 50),
}) {
  if (!kRosidFakeCameraEnabled) {
    return null;
  }
  return FakeCaptureSource(sequence: sequence, frameInterval: frameInterval);
}
