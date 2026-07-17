import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  });

  final String originalPath;
  final String colorPath;
  final String binaryPath;
  final int width;
  final int height;
  final double deskewAngle;
}

class PreprocessState {
  const PreprocessState({
    this.assets = const [],
    this.isProcessing = false,
    this.errorMessage,
  });

  final List<PreprocessedAsset> assets;
  final bool isProcessing;
  final String? errorMessage;
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

class PreprocessController extends Notifier<PreprocessState> {
  @override
  PreprocessState build() => const PreprocessState();

  Future<bool> process({
    required CaptureSession session,
    required List<DocumentQuad> quads,
    int rotationQuarterTurns = 0,
  }) async {
    if (session.scanId == null ||
        session.pagePaths.isEmpty ||
        state.isProcessing) {
      return false;
    }
    state = const PreprocessState(isProcessing: true);
    try {
      final assets = <PreprocessedAsset>[];
      final databasePages = await ref
          .read(scanRepositoryProvider)
          .getPages(session.scanId!);
      for (var index = 0; index < session.pagePaths.length; index++) {
        final originalPath = session.pagePaths[index];
        final bytes = await File(originalPath).readAsBytes();
        final result = await compute(
          _preprocessInBackground,
          _PreprocessRequest(
            bytes: bytes,
            quad: quads.length > index
                ? quads[index]
                : const DocumentQuad.inset(),
            rotationQuarterTurns: rotationQuarterTurns,
          ),
        );
        final fileStore = ref.read(privateFileStoreProvider);
        final colorPath = await fileStore.writeProcessed(
          bytes: result.colorCorrectedJpeg,
          scanId: session.scanId!,
          pageIndex: index,
        );
        final binaryPath = await fileStore.writeProcessed(
          bytes: result.binarizedJpeg,
          scanId: session.scanId!,
          pageIndex: index,
          suffix: 'bw',
        );
        if (databasePages.length > index) {
          await ref
              .read(scanRepositoryProvider)
              .setProcessedPagePath(
                pageId: databasePages[index].id,
                path: colorPath,
              );
        }
        assets.add(
          PreprocessedAsset(
            originalPath: originalPath,
            colorPath: colorPath,
            binaryPath: binaryPath,
            width: result.width,
            height: result.height,
            deskewAngle: result.deskewAngle,
          ),
        );
      }
      state = PreprocessState(assets: assets);
      return true;
    } on Object catch (error) {
      state = PreprocessState(errorMessage: error.toString());
      return false;
    }
  }

  void reset() => state = const PreprocessState();
}

final preprocessProvider =
    NotifierProvider<PreprocessController, PreprocessState>(
      PreprocessController.new,
    );
