import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as image;
import 'package:rosid/data/files/private_file_store.dart';
import 'package:rosid/data/repositories/scan_repository.dart';
import 'package:rosid/features/capture/capture_session.dart';
import 'package:rosid/ocr/preprocess/document_quad.dart';
import 'package:rosid/ocr/preprocess/image_preprocessor.dart';

class PreprocessedAsset {
  const PreprocessedAsset({
    required this.originalPath,
    required this.colorPath,
    required this.binaryPath,
    required this.width,
    required this.height,
    required this.deskewAngle,
    required this.generation,
  });

  final String originalPath;
  final String colorPath;
  final String binaryPath;
  final int width;
  final int height;
  final double deskewAngle;
  final int generation;
}

class PreprocessState {
  const PreprocessState({
    this.scanId,
    this.assets = const [],
    this.isProcessing = false,
    this.errorMessage,
  });

  final String? scanId;
  final List<PreprocessedAsset> assets;
  final bool isProcessing;
  final String? errorMessage;

  bool matches(CaptureSession session) {
    if (scanId == null || scanId != session.scanId) return false;
    if (assets.length != session.pagePaths.length) return false;
    for (var index = 0; index < assets.length; index++) {
      if (assets[index].originalPath != session.pagePaths[index]) return false;
    }
    return assets.isNotEmpty;
  }
}

class _PreprocessRequest {
  const _PreprocessRequest({
    required this.bytes,
    required this.quad,
    required this.rotationQuarterTurns,
  });

  final Uint8List bytes;
  final DocumentQuad quad;
  final int rotationQuarterTurns;
}

PreprocessResult _preprocessInBackground(_PreprocessRequest request) {
  return const ImagePreprocessor().process(
    request.bytes,
    quad: request.quad,
    options: PreprocessOptions(
      rotationQuarterTurns: request.rotationQuarterTurns,
    ),
  );
}

Uint8List createThumbnailBytes(Uint8List encoded) {
  const maximumDimension = 480;
  final source = image.decodeImage(encoded);
  if (source == null) throw const FormatException('Unsupported thumbnail');
  final longest = source.width > source.height ? source.width : source.height;
  final thumbnail = longest <= maximumDimension
      ? source
      : image.copyResize(
          source,
          width: source.width >= source.height ? maximumDimension : null,
          height: source.height > source.width ? maximumDimension : null,
          interpolation: image.Interpolation.linear,
        );
  return Uint8List.fromList(image.encodeJpg(thumbnail, quality: 82));
}

typedef PreprocessRunner =
    Future<PreprocessResult> Function(
      Uint8List bytes,
      DocumentQuad quad,
      int rotationQuarterTurns,
    );

final preprocessRunnerProvider = Provider<PreprocessRunner>(
  (ref) =>
      (bytes, quad, rotationQuarterTurns) => compute(
        _preprocessInBackground,
        _PreprocessRequest(
          bytes: bytes,
          quad: quad,
          rotationQuarterTurns: rotationQuarterTurns,
        ),
      ),
);

class _PreprocessCancelled implements Exception {
  const _PreprocessCancelled();
}

class PreprocessController extends Notifier<PreprocessState> {
  var _generation = 0;
  var _requestToken = 0;
  Future<void> _requestBarrier = Future<void>.value();

  @override
  PreprocessState build() => const PreprocessState();

  Future<bool> process({
    required CaptureSession session,
    required List<DocumentQuad> quads,
    int rotationQuarterTurns = 0,
    List<int> pageRotationQuarterTurns = const [],
  }) {
    if (session.scanId == null ||
        session.pagePaths.isEmpty ||
        state.isProcessing) {
      return Future<bool>.value(false);
    }
    final token = ++_requestToken;
    final generation = ++_generation;
    final scanId = session.scanId!;
    final pagePaths = List<String>.unmodifiable(session.pagePaths);
    final quadSnapshot = List<DocumentQuad>.unmodifiable(quads);
    final rotationSnapshot = List<int>.unmodifiable(pageRotationQuarterTurns);
    state = PreprocessState(scanId: scanId, isProcessing: true);

    final work = _requestBarrier.then(
      (_) => _performProcess(
        token: token,
        generation: generation,
        scanId: scanId,
        pagePaths: pagePaths,
        quads: quadSnapshot,
        rotationQuarterTurns: rotationQuarterTurns,
        pageRotationQuarterTurns: rotationSnapshot,
      ),
    );
    _requestBarrier = work.then<void>((_) {});
    return work;
  }

  Future<bool> _performProcess({
    required int token,
    required int generation,
    required String scanId,
    required List<String> pagePaths,
    required List<DocumentQuad> quads,
    required int rotationQuarterTurns,
    required List<int> pageRotationQuarterTurns,
  }) async {
    final repository = ref.read(scanRepositoryProvider);
    final fileStore = ref.read(privateFileStoreProvider);
    final runner = ref.read(preprocessRunnerProvider);
    final createdPaths = <String>[];
    final updatedPages = <({String id, String? previousPath})>[];
    String? previousThumbnailPath;
    var thumbnailUpdated = false;

    try {
      _ensureCurrent(token);
      final assets = <PreprocessedAsset>[];
      final databasePages = await repository.getPages(scanId);
      _ensureCurrent(token);
      final databaseScan = await repository.getScan(scanId);
      previousThumbnailPath = databaseScan.thumbPath;
      _ensureCurrent(token);

      String? thumbnailPath;
      for (var index = 0; index < pagePaths.length; index++) {
        final originalPath = pagePaths[index];
        final bytes = await File(originalPath).readAsBytes();
        _ensureCurrent(token);
        final result = await runner(
          bytes,
          quads.length > index ? quads[index] : const DocumentQuad.inset(),
          pageRotationQuarterTurns.length > index
              ? pageRotationQuarterTurns[index]
              : rotationQuarterTurns,
        );
        _ensureCurrent(token);
        final colorPath = await fileStore.writeProcessed(
          bytes: result.colorCorrectedJpeg,
          scanId: scanId,
          pageIndex: index,
          suffix: 'color_g$generation',
        );
        createdPaths.add(colorPath);
        _ensureCurrent(token);
        final binaryPath = await fileStore.writeProcessed(
          bytes: result.binarizedJpeg,
          scanId: scanId,
          pageIndex: index,
          suffix: 'bw_g$generation',
        );
        createdPaths.add(binaryPath);
        _ensureCurrent(token);
        if (index == 0) {
          final thumbnailBytes = await compute(
            createThumbnailBytes,
            result.colorCorrectedJpeg,
          );
          _ensureCurrent(token);
          thumbnailPath = await fileStore.writeThumbnail(
            bytes: thumbnailBytes,
            scanId: scanId,
            generation: generation,
          );
          createdPaths.add(thumbnailPath);
          _ensureCurrent(token);
        }
        assets.add(
          PreprocessedAsset(
            originalPath: originalPath,
            colorPath: colorPath,
            binaryPath: binaryPath,
            width: result.width,
            height: result.height,
            deskewAngle: result.deskewAngle,
            generation: generation,
          ),
        );
      }

      for (var index = 0; index < assets.length; index++) {
        if (databasePages.length <= index) continue;
        _ensureCurrent(token);
        final page = databasePages[index];
        await repository.setProcessedPagePath(
          pageId: page.id,
          path: assets[index].colorPath,
        );
        updatedPages.add((id: page.id, previousPath: page.processedPath));
        _ensureCurrent(token);
      }
      if (thumbnailPath != null) {
        _ensureCurrent(token);
        await repository.setThumbnailPath(scanId: scanId, path: thumbnailPath);
        thumbnailUpdated = true;
        _ensureCurrent(token);
      }

      await fileStore.deleteObsoleteDerivedArtifacts(
        scanId: scanId,
        keepPaths: createdPaths,
      );
      _ensureCurrent(token);
      state = PreprocessState(scanId: scanId, assets: assets);
      return true;
    } on Object catch (error) {
      await _rollback(
        repository: repository,
        fileStore: fileStore,
        scanId: scanId,
        createdPaths: createdPaths,
        updatedPages: updatedPages,
        thumbnailUpdated: thumbnailUpdated,
        previousThumbnailPath: previousThumbnailPath,
      );
      if (token == _requestToken) {
        state = error is _PreprocessCancelled
            ? const PreprocessState()
            : PreprocessState(errorMessage: error.toString());
      }
      return false;
    }
  }

  void _ensureCurrent(int token) {
    if (token != _requestToken) throw const _PreprocessCancelled();
  }

  Future<void> _rollback({
    required ScanRepository repository,
    required PrivateFileStore fileStore,
    required String scanId,
    required List<String> createdPaths,
    required List<({String id, String? previousPath})> updatedPages,
    required bool thumbnailUpdated,
    required String? previousThumbnailPath,
  }) async {
    for (final page in updatedPages.reversed) {
      try {
        await repository.setProcessedPagePath(
          pageId: page.id,
          path: page.previousPath,
        );
      } on Object {
        // A concurrent discard may already have removed the database row.
      }
    }
    if (thumbnailUpdated) {
      try {
        await repository.setThumbnailPath(
          scanId: scanId,
          path: previousThumbnailPath,
        );
      } on Object {
        // A concurrent discard may already have removed the database row.
      }
    }
    for (final path in createdPaths.reversed) {
      try {
        await fileStore.deleteIfPresent(path);
      } on Object {
        // Cleanup is best-effort; delete-scan also sweeps by scan identifier.
      }
    }
  }

  void reset() {
    _requestToken++;
    state = const PreprocessState();
  }
}

final preprocessProvider =
    NotifierProvider<PreprocessController, PreprocessState>(
      PreprocessController.new,
    );
