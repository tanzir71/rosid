import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:rosid/core/profile/app_profile.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/files/private_file_store.dart';
import 'package:rosid/data/repositories/scan_repository.dart';
import 'package:rosid/features/capture/capture_session.dart';
import 'package:rosid/features/crop/preprocess_controller.dart';
import 'package:rosid/ocr/preprocess/document_quad.dart';
import 'package:rosid/ocr/preprocess/image_preprocessor.dart';

void main() {
  test('thumbnail keeps aspect ratio within 480 pixels', () {
    final source = image.Image(width: 1600, height: 900);
    source.clear(image.ColorRgb8(240, 240, 240));

    final bytes = createThumbnailBytes(
      Uint8List.fromList(image.encodeJpg(source)),
    );
    final thumbnail = image.decodeJpg(bytes)!;

    expect(thumbnail.width, 480);
    expect(thumbnail.height, 270);
  });

  test('processed assets only match their originating scan and paths', () {
    const asset = PreprocessedAsset(
      originalPath: '/private/a.jpg',
      colorPath: '/private/a-color.jpg',
      binaryPath: '/private/a-bw.jpg',
      width: 800,
      height: 1200,
      deskewAngle: 0,
      generation: 1,
    );
    const state = PreprocessState(scanId: 'scan-a', assets: [asset]);

    expect(
      state.matches(
        const CaptureSession(
          mode: ScanMode.receipt,
          languageHint: CaptureLanguageHint.automatic,
          scanId: 'scan-a',
          pagePaths: ['/private/a.jpg'],
        ),
      ),
      isTrue,
    );
    expect(
      state.matches(
        const CaptureSession(
          mode: ScanMode.receipt,
          languageHint: CaptureLanguageHint.automatic,
          scanId: 'scan-b',
          pagePaths: ['/private/b.jpg'],
        ),
      ),
      isFalse,
    );
  });

  test('a reset cancels stale writes before a queued reprocess starts', () async {
    final root = await Directory.systemTemp.createTemp(
      'rosid_preprocess_race_',
    );
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final scans = ScanRepository(database);
    final files = _DelayedPrivateFileStore(rootDirectory: root);
    final source = File(
      '${root.path}${Platform.pathSeparator}receipt-source.jpg',
    );
    final encoded = Uint8List.fromList(
      image.encodeJpg(
        image.Image(width: 48, height: 72)
          ..clear(image.ColorRgb8(240, 240, 240)),
      ),
    );
    await source.writeAsBytes(encoded);
    await scans.createScan(
      id: 'scan-race',
      mode: ScanMode.receipt,
      imagePath: source.path,
      langHint: 'automatic',
      createdAt: DateTime(2026, 7, 17),
    );
    final result = PreprocessResult(
      colorCorrectedJpeg: encoded,
      binarizedJpeg: encoded,
      width: 48,
      height: 72,
      deskewAngle: 0,
    );
    final container = ProviderContainer(
      overrides: [
        scanRepositoryProvider.overrideWithValue(scans),
        privateFileStoreProvider.overrideWithValue(files),
        preprocessRunnerProvider.overrideWithValue(
          (bytes, quad, turns) async => result,
        ),
      ],
    );
    const session = CaptureSession(
      mode: ScanMode.receipt,
      languageHint: CaptureLanguageHint.automatic,
      scanId: 'scan-race',
      pagePaths: [],
    );
    final liveSession = CaptureSession(
      mode: session.mode,
      languageHint: session.languageHint,
      scanId: session.scanId,
      pagePaths: [source.path],
    );

    try {
      final controller = container.read(preprocessProvider.notifier);
      final first = controller.process(
        session: liveSession,
        quads: const [DocumentQuad.inset()],
      );
      await files.firstWriteStarted.future;

      controller.reset();
      final second = controller.process(
        session: liveSession,
        quads: const [DocumentQuad.inset()],
      );
      expect(container.read(preprocessProvider).isProcessing, isTrue);

      files.resumeFirstWrite.complete();
      expect(await first, isFalse);
      expect(await second, isTrue);

      final state = container.read(preprocessProvider);
      expect(state.matches(liveSession), isTrue);
      expect(state.assets.single.generation, 2);
      expect(state.assets.single.colorPath, contains('color_g2'));
      final page = (await scans.getPages('scan-race')).single;
      expect(page.processedPath, state.assets.single.colorPath);

      final processed = Directory(
        '${root.path}${Platform.pathSeparator}rosid${Platform.pathSeparator}processed',
      ).listSync().whereType<File>().toList();
      expect(processed, hasLength(2));
      expect(
        processed.map((file) => file.path),
        everyElement(contains('_g2.jpg')),
      );
      final thumbnails = Directory(
        '${root.path}${Platform.pathSeparator}rosid${Platform.pathSeparator}thumbnails',
      ).listSync().whereType<File>().toList();
      expect(thumbnails, hasLength(1));
      expect(thumbnails.single.path, contains('_g2.jpg'));
    } finally {
      container.dispose();
      await database.close();
      if (await root.exists()) await root.delete(recursive: true);
    }
  });
}

class _DelayedPrivateFileStore extends PrivateFileStore {
  _DelayedPrivateFileStore({required super.rootDirectory});

  final firstWriteStarted = Completer<void>();
  final resumeFirstWrite = Completer<void>();
  var _didDelay = false;

  @override
  Future<String> writeProcessed({
    required List<int> bytes,
    required String scanId,
    required int pageIndex,
    String suffix = 'color',
  }) async {
    final destination = await super.writeProcessed(
      bytes: bytes,
      scanId: scanId,
      pageIndex: pageIndex,
      suffix: suffix,
    );
    if (!_didDelay) {
      _didDelay = true;
      firstWriteStarted.complete();
      await resumeFirstWrite.future;
    }
    return destination;
  }
}
