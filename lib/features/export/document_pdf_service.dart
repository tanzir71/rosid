import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as image;
import 'package:pdf/widgets.dart' as pdf_widgets;
import 'package:rosid/data/files/private_file_store.dart';
import 'package:rosid/data/repositories/history_repository.dart';
import 'package:uuid/uuid.dart';

const int documentPdfMaxPageCount = 20;
const int documentPdfMaxImageDimension = 1600;
const int _documentPdfJpegQuality = 82;

typedef PdfPagePreparer = Future<Uint8List> Function(String sourcePath);

class PdfPageLimitExceeded implements Exception {
  const PdfPageLimitExceeded({required this.actual, required this.maximum});

  final int actual;
  final int maximum;

  @override
  String toString() =>
      'PDF export supports at most $maximum pages; received $actual.';
}

Future<Uint8List> prepareDocumentPdfPage(String sourcePath) =>
    compute(_loadAndPrepareDocumentPdfPage, sourcePath);

Uint8List prepareDocumentPdfPageBytes(Uint8List sourceBytes) {
  final decoded = image.decodeImage(sourceBytes);
  if (decoded == null) {
    throw const FormatException('Unable to decode an image for PDF export.');
  }

  var prepared = image.bakeOrientation(decoded);
  final longestSide = math.max(prepared.width, prepared.height);
  if (longestSide > documentPdfMaxImageDimension) {
    prepared = prepared.width >= prepared.height
        ? image.copyResize(
            prepared,
            width: documentPdfMaxImageDimension,
            interpolation: image.Interpolation.average,
          )
        : image.copyResize(
            prepared,
            height: documentPdfMaxImageDimension,
            interpolation: image.Interpolation.average,
          );
  }

  return Uint8List.fromList(
    image.encodeJpg(prepared, quality: _documentPdfJpegQuality),
  );
}

Uint8List _loadAndPrepareDocumentPdfPage(String sourcePath) {
  final sourceBytes = File(sourcePath).readAsBytesSync();
  return prepareDocumentPdfPageBytes(sourceBytes);
}

class DocumentPdfService {
  const DocumentPdfService(
    this.fileStore, {
    this.pagePreparer = prepareDocumentPdfPage,
  });

  final PrivateFileStore fileStore;
  final PdfPagePreparer pagePreparer;

  Future<String> create(ScanDetail detail) async {
    final paths = detail.pages
        .map((page) => page.processedPath ?? page.imagePath)
        .toList(growable: false);
    final bytes = await renderPaths(paths, title: detail.entry.title);
    final safeTitle = detail.entry.title
        .replaceAll(RegExp(r'[^A-Za-z0-9\u0980-\u09FF_-]+'), '_')
        .replaceAll(RegExp('_+'), '_');
    final boundedTitle = safeTitle.length > 80
        ? safeTitle.substring(0, 80)
        : safeTitle;
    final path = await fileStore.createExportPath(
      '${boundedTitle.isEmpty ? 'rosid_document' : boundedTitle}_'
      '${const Uuid().v7()}.pdf',
    );
    try {
      await File(path).writeAsBytes(bytes, flush: true);
    } on Object {
      await fileStore.deleteExportIfPresent(path);
      rethrow;
    }
    return path;
  }

  Future<Uint8List> renderPaths(
    List<String> imagePaths, {
    String title = 'Rosid document',
  }) async {
    _checkPageCount(imagePaths.length);
    final document = pdf_widgets.Document(title: title, author: 'Rosid');
    for (final path in imagePaths) {
      final preparedBytes = await pagePreparer(path);
      _addPage(document, preparedBytes);
    }
    return document.save();
  }

  Future<Uint8List> render(
    List<Uint8List> images, {
    String title = 'Rosid document',
  }) async {
    _checkPageCount(images.length);
    final document = pdf_widgets.Document(title: title, author: 'Rosid');
    for (final bytes in images) {
      final preparedBytes = await compute(prepareDocumentPdfPageBytes, bytes);
      _addPage(document, preparedBytes);
    }
    return document.save();
  }

  static void _checkPageCount(int pageCount) {
    if (pageCount > documentPdfMaxPageCount) {
      throw PdfPageLimitExceeded(
        actual: pageCount,
        maximum: documentPdfMaxPageCount,
      );
    }
  }

  static void _addPage(pdf_widgets.Document document, Uint8List preparedBytes) {
    final memoryImage = pdf_widgets.MemoryImage(preparedBytes);
    document.addPage(
      pdf_widgets.Page(
        build: (context) => pdf_widgets.Center(
          child: pdf_widgets.Image(
            memoryImage,
            fit: pdf_widgets.BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

final documentPdfServiceProvider = Provider<DocumentPdfService>(
  (ref) => DocumentPdfService(ref.watch(privateFileStoreProvider)),
);
