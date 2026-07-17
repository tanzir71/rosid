import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:rosid/data/files/private_file_store.dart';
import 'package:rosid/features/export/document_pdf_service.dart';

void main() {
  group('DocumentPdfService', () {
    test('downscales a page before embedding it', () {
      final source = image.Image(width: 2000, height: 1000, numChannels: 3);

      final prepared = prepareDocumentPdfPageBytes(
        Uint8List.fromList(image.encodeJpg(source)),
      );
      final decoded = image.decodeJpg(prepared);

      expect(decoded, isNotNull);
      expect(decoded!.width, documentPdfMaxImageDimension);
      expect(decoded.height, 800);
    });

    test('prepares file-backed pages sequentially', () async {
      var activePreparers = 0;
      var maximumActivePreparers = 0;
      final preparedPaths = <String>[];
      final pageBytes = Uint8List.fromList(
        image.encodeJpg(image.Image(width: 32, height: 32)),
      );
      final service = DocumentPdfService(
        const PrivateFileStore(),
        pagePreparer: (path) async {
          activePreparers += 1;
          maximumActivePreparers = activePreparers > maximumActivePreparers
              ? activePreparers
              : maximumActivePreparers;
          preparedPaths.add(path);
          await Future<void>.delayed(const Duration(milliseconds: 1));
          activePreparers -= 1;
          return pageBytes;
        },
      );

      final result = await service.renderPaths(const [
        'page-1.jpg',
        'page-2.jpg',
        'page-3.jpg',
      ]);

      expect(maximumActivePreparers, 1);
      expect(preparedPaths, ['page-1.jpg', 'page-2.jpg', 'page-3.jpg']);
      expect(result.take(4), [0x25, 0x50, 0x44, 0x46]);
    });

    test('rejects an oversized document before reading a page', () async {
      var prepareCalls = 0;
      final service = DocumentPdfService(
        const PrivateFileStore(),
        pagePreparer: (path) async {
          prepareCalls += 1;
          return Uint8List(0);
        },
      );
      final paths = List<String>.generate(
        documentPdfMaxPageCount + 1,
        (index) => 'page-$index.jpg',
      );

      await expectLater(
        service.renderPaths(paths),
        throwsA(
          isA<PdfPageLimitExceeded>()
              .having((error) => error.actual, 'actual', paths.length)
              .having(
                (error) => error.maximum,
                'maximum',
                documentPdfMaxPageCount,
              ),
        ),
      );
      expect(prepareCalls, 0);
    });
  });
}
