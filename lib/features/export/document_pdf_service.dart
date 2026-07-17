import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pdf_widgets;
import 'package:rosid/data/files/private_file_store.dart';
import 'package:rosid/data/repositories/history_repository.dart';

class DocumentPdfService {
  const DocumentPdfService(this.fileStore);

  final PrivateFileStore fileStore;

  Future<String> create(ScanDetail detail) async {
    final images = <Uint8List>[];
    for (final page in detail.pages) {
      final path = page.processedPath ?? page.imagePath;
      images.add(await File(path).readAsBytes());
    }
    final bytes = await render(images, title: detail.entry.title);
    final safeTitle = detail.entry.title
        .replaceAll(RegExp(r'[^A-Za-z0-9\u0980-\u09FF_-]+'), '_')
        .replaceAll(RegExp('_+'), '_');
    final path = await fileStore.createExportPath(
      '${safeTitle.isEmpty ? 'rosid_document' : safeTitle}.pdf',
    );
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  Future<Uint8List> render(
    List<Uint8List> images, {
    String title = 'Rosid document',
  }) async {
    final document = pdf_widgets.Document(title: title, author: 'Rosid');
    for (final bytes in images) {
      final memoryImage = pdf_widgets.MemoryImage(bytes);
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
    return document.save();
  }
}

final documentPdfServiceProvider = Provider<DocumentPdfService>(
  (ref) => DocumentPdfService(ref.watch(privateFileStoreProvider)),
);
