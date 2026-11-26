import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Interface for on-device Bangla -> English neural translation engines.
abstract class TranslationEngine {
  Future<void> warmUp();

  /// Translates a batch of Bangla strings into English on the device.
  /// Returns a list of the same length as [lines].
  Future<List<String>> translateBatch(List<String> lines);

  /// Releases runtime memory (e.g., destroys the hidden WebView when the
  /// English tab is closed).
  Future<void> release();
}

/// Integration A: Android hidden WebView running Mozilla's Bergamot
/// WebAssembly (`bn -> en`) model strictly from local Flutter assets.
class WebViewBergamotEngine implements TranslationEngine {
  WebViewBergamotEngine({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('app.rosid.rosid/translate');

  final MethodChannel _channel;

  @override
  Future<void> warmUp() async {
    try {
      await _channel.invokeMethod<dynamic>('warmUp');
    } on MissingPluginException {
      // Non-Android / unit test environment without native WebView channel.
    }
  }

  @override
  Future<List<String>> translateBatch(List<String> lines) async {
    if (lines.isEmpty) return const [];
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'translateBatch',
        <String, dynamic>{'lines': lines},
      );
      if (raw == null || raw.length != lines.length) {
        return List<String>.filled(lines.length, '');
      }
      return raw.map((e) => (e ?? '').toString()).toList();
    } on MissingPluginException {
      return List<String>.filled(lines.length, '');
    } on PlatformException {
      return List<String>.filled(lines.length, '');
    }
  }

  @override
  Future<void> release() async {
    try {
      await _channel.invokeMethod<void>('release');
    } on Object {
      // Best-effort cleanup.
    }
  }
}

final translationEngineProvider = Provider<TranslationEngine>((ref) {
  final engine = WebViewBergamotEngine();
  ref.onDispose(() {
    engine.release();
  });
  return engine;
});
