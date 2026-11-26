import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/database/database_provider.dart';
import 'package:rosid/data/files/private_file_store.dart';
import 'package:rosid/data/repositories/bundle_repository.dart';
import 'package:rosid/export/export_models.dart';
import 'package:rosid/export/paper_pdf_builder.dart';
import 'package:rosid/translation/bangla_transliterator.dart';
import 'package:rosid/translation/translation_repository.dart';
import 'package:uuid/uuid.dart';

enum BundlePackMode { onePdf, separateFiles }

class BundlePaperInput {
  const BundlePaperInput({
    required this.title,
    required this.scanImages,
    required this.englishLines,
  });

  final String title;
  final List<Uint8List> scanImages;
  final List<DraftLineView> englishLines;

  int get totalPages {
    final scanCount = scanImages.isEmpty ? 1 : scanImages.length;
    final enCount = englishLines.isEmpty
        ? 0
        : (englishLines.length / 24).ceil();
    return scanCount + enCount;
  }
}

class BundleContentsEntry {
  const BundleContentsEntry({
    required this.index,
    required this.title,
    required this.startPage,
    required this.pageCount,
  });

  final int index;
  final String title;
  final int startPage;
  final int pageCount;
}

class BuiltBundlePdf {
  const BuiltBundlePdf({
    required this.bytes,
    required this.totalPages,
    required this.contents,
    required this.exceededSizeLimit,
  });

  final Uint8List bytes;
  final int totalPages;
  final List<BundleContentsEntry> contents;
  final bool exceededSizeLimit;
}

/// Pure-Dart bundle PDF packer:
/// - **One PDF**: builds Page 1 as a numbered Contents table in checklist order
///   with exact starting page numbers, followed by each paper's scan + English
///   draft pages (with `DRAFT TRANSLATION` stamp on English pages, page numbers
///   in every footer, optional diagonal watermark, and size-limit compression).
/// - **Separate files**: builds numbered PDFs (`01-Passport.pdf`, `02-...pdf`)
///   packed into a ZIP archive with per-file size limit.
abstract final class BundlePdfBuilder {
  static Future<BuiltBundlePdf> buildOnePdf({
    required String bundleTitle,
    required List<BundlePaperInput> papers,
    int? maxSizeBytes,
    String watermarkText = '',
  }) async {
    const qualitySteps = <(int quality, int maxEdge)>[
      (80, 2200),
      (65, 1900),
      (52, 1754),
      (38, 1500),
      (28, 1240),
    ];
    final steps = maxSizeBytes == null ? const [(80, 2200)] : qualitySteps;

    // Precompute exact Contents table: Page 1 is Contents, papers start at Page 2.
    final contents = <BundleContentsEntry>[];
    var nextPage = 2;
    for (var i = 0; i < papers.length; i++) {
      final count = papers[i].totalPages;
      contents.add(
        BundleContentsEntry(
          index: i + 1,
          title: papers[i].title,
          startPage: nextPage,
          pageCount: count,
        ),
      );
      nextPage += count;
    }
    final totalPages = nextPage - 1;

    Uint8List? lastBytes;
    for (final (quality, maxEdge) in steps) {
      final doc = pw.Document(
        title: _asciiSafe(bundleTitle, fallback: 'Rosid Bundle'),
        creator: 'Rosid 2.0 (Offline)',
        compress: false,
      );
      final ink = PdfColor.fromHex('#1A1B2E');
      final muted = PdfColor.fromHex('#55586A');
      final accent = PdfColor.fromHex('#4333B0');
      final line = PdfColor.fromHex('#DCE0D3');

      // Page 1: Contents page
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(44, 46, 44, 40),
          build: (_) => pw.Stack(
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'CONTENTS',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.2,
                      color: accent,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    _asciiSafe(bundleTitle, fallback: 'Application Bundle'),
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: ink,
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Divider(color: line, thickness: 1),
                  pw.SizedBox(height: 12),
                  for (final entry in contents) ...[
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 7),
                      child: pw.Row(
                        children: [
                          pw.SizedBox(
                            width: 28,
                            child: pw.Text(
                              entry.index.toString().padLeft(2, '0'),
                              style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                                color: accent,
                              ),
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Text(
                              _asciiSafe(
                                entry.title,
                                fallback: 'Paper ${entry.index}',
                              ),
                              style: pw.TextStyle(fontSize: 12.5, color: ink),
                            ),
                          ),
                          pw.Text(
                            'Page ${entry.startPage}',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.Divider(color: line, thickness: 0.5),
                  ],
                  pw.Spacer(),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '${papers.length} papers, $totalPages pages',
                        style: pw.TextStyle(fontSize: 9.5, color: muted),
                      ),
                      pw.Text(
                        'Page 1 of $totalPages',
                        style: pw.TextStyle(fontSize: 9.5, color: muted),
                      ),
                    ],
                  ),
                ],
              ),
              if (watermarkText.trim().isNotEmpty)
                _watermarkOverlay(watermarkText.trim()),
            ],
          ),
        ),
      );

      // Paper pages in exact checklist order
      var currentPageNo = 2;
      for (var i = 0; i < papers.length; i++) {
        final paper = papers[i];
        final scans = paper.scanImages;
        if (scans.isEmpty) {
          final pNo = currentPageNo++;
          doc.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              margin: const pw.EdgeInsets.all(36),
              build: (_) => pw.Stack(
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        _asciiSafe(paper.title, fallback: 'Paper ${i + 1}'),
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: ink,
                        ),
                      ),
                      pw.Spacer(),
                      pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text(
                          'Page $pNo of $totalPages',
                          style: pw.TextStyle(fontSize: 9, color: muted),
                        ),
                      ),
                    ],
                  ),
                  if (watermarkText.trim().isNotEmpty)
                    _watermarkOverlay(watermarkText.trim()),
                ],
              ),
            ),
          );
        } else {
          for (final rawImg in scans) {
            final jpg = _compressImage(
              rawImg,
              quality: quality,
              maxEdge: maxEdge,
            );
            final mem = pw.MemoryImage(jpg);
            final pNo = currentPageNo++;
            doc.addPage(
              pw.Page(
                pageFormat: PdfPageFormat.a4,
                margin: const pw.EdgeInsets.fromLTRB(20, 20, 20, 28),
                build: (_) => pw.Stack(
                  children: [
                    pw.Column(
                      children: [
                        pw.Expanded(
                          child: pw.Center(
                            child: pw.Image(mem, fit: pw.BoxFit.contain),
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              _asciiSafe(paper.title),
                              style: pw.TextStyle(fontSize: 8.5, color: muted),
                            ),
                            pw.Text(
                              'Page $pNo of $totalPages',
                              style: pw.TextStyle(fontSize: 8.5, color: muted),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (watermarkText.trim().isNotEmpty)
                      _watermarkOverlay(watermarkText.trim()),
                  ],
                ),
              ),
            );
          }
        }

        // English draft pages if present (always carries DRAFT TRANSLATION stamp!)
        if (paper.englishLines.isNotEmpty) {
          const perPage = 24;
          for (var s = 0; s < paper.englishLines.length; s += perPage) {
            final chunk = paper.englishLines.skip(s).take(perPage).toList();
            final pNo = currentPageNo++;
            doc.addPage(
              pw.Page(
                pageFormat: PdfPageFormat.a4,
                margin: const pw.EdgeInsets.fromLTRB(44, 42, 44, 34),
                build: (_) => pw.Stack(
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Expanded(
                              child: pw.Text(
                                _asciiSafe(
                                  paper.title,
                                  fallback: 'English Draft',
                                ),
                                style: pw.TextStyle(
                                  fontSize: 15,
                                  fontWeight: pw.FontWeight.bold,
                                  color: ink,
                                ),
                              ),
                            ),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(
                                  color: accent,
                                  width: 1.4,
                                ),
                              ),
                              child: pw.Text(
                                'DRAFT TRANSLATION',
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 10),
                        pw.Divider(color: line, thickness: 0.8),
                        pw.SizedBox(height: 10),
                        for (final l in chunk) ...[
                          pw.Text(
                            _asciiSafe(l.englishText),
                            style: pw.TextStyle(fontSize: 11.5, color: ink),
                          ),
                          pw.SizedBox(height: 6),
                        ],
                        pw.Spacer(),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Draft translation from Bangla',
                              style: pw.TextStyle(fontSize: 8.5, color: accent),
                            ),
                            pw.Text(
                              'Page $pNo of $totalPages',
                              style: pw.TextStyle(fontSize: 8.5, color: muted),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (watermarkText.trim().isNotEmpty)
                      _watermarkOverlay(watermarkText.trim()),
                  ],
                ),
              ),
            );
          }
        }
      }

      final bytes = Uint8List.fromList(await doc.save());
      lastBytes = bytes;
      if (maxSizeBytes == null || bytes.length <= maxSizeBytes) {
        return BuiltBundlePdf(
          bytes: bytes,
          totalPages: totalPages,
          contents: contents,
          exceededSizeLimit: false,
        );
      }
    }

    return BuiltBundlePdf(
      bytes: lastBytes!,
      totalPages: totalPages,
      contents: contents,
      exceededSizeLimit: true,
    );
  }

  static Uint8List _compressImage(
    Uint8List raw, {
    required int quality,
    required int maxEdge,
  }) {
    final decoded = img.decodeImage(raw);
    if (decoded == null) return raw;
    var w = decoded;
    final longest = math.max(w.width, w.height);
    if (longest > maxEdge) {
      final scale = maxEdge / longest;
      w = img.copyResize(
        w,
        width: math.max(1, (w.width * scale).round()),
        height: math.max(1, (w.height * scale).round()),
      );
    }
    return Uint8List.fromList(img.encodeJpg(w, quality: quality));
  }

  static pw.Widget _watermarkOverlay(String text) {
    return pw.Positioned.fill(
      child: pw.Center(
        child: pw.Transform.rotate(
          angle: 0.52,
          child: pw.Opacity(
            opacity: 0.14,
            child: pw.Text(
              _asciiSafe(text),
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#4333B0'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _asciiSafe(String input, {String fallback = ''}) {
    final translit = RegExp(r'[\u0980-\u09FF]').hasMatch(input)
        ? BanglaTransliterator.transliterate(input)
        : input;
    final clean = translit
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '')
        .replaceAll(RegExp(r' {2,}'), ' ')
        .trim();
    return clean.isEmpty ? fallback : clean;
  }
}

class BundleExportService {
  const BundleExportService(this.db, this.fileStore);

  final AppDatabase db;
  final PrivateFileStore fileStore;
  static const _uuid = Uuid();

  static String fileNameForBundle(String bundleTitle, BundlePackMode mode) {
    final translit = BanglaTransliterator.transliterate(bundleTitle);
    final slug = translit
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final base = slug.isEmpty ? 'Rosid-Bundle' : slug;
    return mode == BundlePackMode.onePdf ? '$base.pdf' : '$base.zip';
  }

  Future<PaperExportResult> exportBundle({
    required BundleDetailView detail,
    required BundlePackMode mode,
    int? maxSizeBytes,
    bool watermarkEnabled = false,
    String watermarkText = '',
  }) async {
    final attached = detail.attachedItems;
    final papers = <BundlePaperInput>[];

    for (final it in attached) {
      final scan = it.linkedScan!;
      final pages =
          await (db.select(db.scanPages)
                ..where((p) => p.scanId.equals(scan.id))
                ..orderBy([(p) => OrderingTerm.asc(p.pageIndex)]))
              .get();
      final images = <Uint8List>[];
      if (pages.isNotEmpty) {
        for (final p in pages) {
          final f = File(p.processedPath ?? p.imagePath);
          if (f.existsSync()) images.add(await f.readAsBytes());
        }
      } else {
        final f = File(scan.imagePath);
        if (f.existsSync()) images.add(await f.readAsBytes());
      }

      final transRows =
          await (db.select(db.translations)
                ..where((t) => t.scanId.equals(scan.id))
                ..orderBy([(t) => OrderingTerm.asc(t.lineOrder)]))
              .get();
      final englishLines = [
        for (final r in transRows)
          DraftLineView(
            translationId: r.id,
            lineOrder: r.lineOrder,
            sourceText: r.sourceText,
            englishText: r.englishText,
            edited: r.edited,
            nameMarks: const [],
            termMentions: const [],
          ),
      ];

      papers.add(
        BundlePaperInput(
          title: it.item.title,
          scanImages: images,
          englishLines: englishLines,
        ),
      );
    }

    final fileName = fileNameForBundle(detail.bundle.title, mode);
    final prefix = _uuid.v7().substring(0, 8);
    final outPath = await fileStore.createExportPath('${prefix}_$fileName');
    final wm = watermarkEnabled ? watermarkText : '';

    if (mode == BundlePackMode.onePdf) {
      final built = await BundlePdfBuilder.buildOnePdf(
        bundleTitle: detail.bundle.title,
        papers: papers,
        maxSizeBytes: maxSizeBytes,
        watermarkText: wm,
      );
      await File(outPath).writeAsBytes(built.bytes, flush: true);
      return PaperExportResult(
        tempFilePath: outPath,
        fileName: fileName,
        mimeType: 'application/pdf',
        pageCount: built.totalPages,
        sizeBytes: built.bytes.length,
        exceededSizeLimit: built.exceededSizeLimit,
      );
    }

    // Separate numbered PDFs (`01-Passport.pdf`, `02-National-ID.pdf`, ...) packed into a ZIP.
    final archive = Archive();
    var anyExceeded = false;
    var totalPages = 0;

    for (var i = 0; i < papers.length; i++) {
      final p = papers[i];
      final built = await PaperPdfBuilder.build(
        title: p.title,
        scanPageImages: p.scanImages,
        englishLines: p.englishLines,
        banglaRasterPages: const [],
        config: PaperExportConfig(
          includeScan: true,
          includeEnglish: p.englishLines.isNotEmpty,
          includeBangla: false,
          includeTranslatorPage: false,
          maxSizeBytes: maxSizeBytes,
          watermarkEnabled: watermarkEnabled,
          watermarkText: wm,
        ),
      );
      if (built.exceededSizeLimit) anyExceeded = true;
      totalPages += built.pageCount;

      final slug = BanglaTransliterator.transliterate(p.title)
          .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
      final numStr = (i + 1).toString().padLeft(2, '0');
      final entryName = '$numStr-${slug.isEmpty ? "Paper" : slug}.pdf';
      archive.addFile(ArchiveFile(entryName, built.bytes.length, built.bytes));
    }

    final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));
    await File(outPath).writeAsBytes(zipBytes, flush: true);
    return PaperExportResult(
      tempFilePath: outPath,
      fileName: fileName,
      mimeType: 'application/zip',
      pageCount: totalPages,
      sizeBytes: zipBytes.length,
      exceededSizeLimit: anyExceeded,
    );
  }
}

final bundleExportServiceProvider = Provider<BundleExportService>(
  (ref) => BundleExportService(
    ref.watch(databaseProvider),
    ref.watch(privateFileStoreProvider),
  ),
);
