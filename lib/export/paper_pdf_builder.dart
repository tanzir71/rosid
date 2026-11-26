import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:rosid/export/export_models.dart';
import 'package:rosid/export/image_redactor.dart';
import 'package:rosid/translation/translation_repository.dart';

/// Builds Rosid PDF exports for Scan, English draft, Bangla text (as rasterized
/// PNG pages), and the Translator's certification page, with optional diagonal
/// watermark and size-limit compression loop (`handover/02-architecture.md` Export).
abstract final class PaperPdfBuilder {
  /// Minimum readable A4 width at 150 DPI equivalent (`8.27 in * 150 = 1240 px`).
  static const int minReadableA4LongEdgePx = 1754;

  static Future<BuiltExportBytes> build({
    required String title,
    required List<Uint8List> scanPageImages,
    required List<DraftLineView> englishLines,
    required List<Uint8List> banglaRasterPages,
    required PaperExportConfig config,
    List<String> latinSearchableLines = const [],
  }) async {
    // Compression steps: lower JPEG quality first, then resolution down to 150 DPI eq.
    const qualitySteps = <(int quality, int maxLongEdge)>[
      (84, 2480), // ~300 DPI A4
      (72, 2200),
      (60, 2000),
      (48, 1850),
      (38, minReadableA4LongEdgePx), // 150 DPI A4 floor
      (28, minReadableA4LongEdgePx),
    ];

    final steps = config.maxSizeBytes == null
        ? const [(84, 2480)]
        : qualitySteps;

    Uint8List? lastBytes;
    var lastPageCount = 0;

    for (final (quality, maxEdge) in steps) {
      final preparedScanPages = <Uint8List>[];
      if (config.includeScan) {
        for (var i = 0; i < scanPageImages.length; i++) {
          final pageRegions = config.coverRegions
              .where((r) => r.pageIndex == i)
              .toList();
          preparedScanPages.add(
            _prepareScanImage(
              scanPageImages[i],
              regions: pageRegions,
              blackAndWhite: config.blackAndWhite,
              quality: quality,
              maxLongEdge: maxEdge,
            ),
          );
        }
      }

      final (bytes, pageCount) = await _renderPdf(
        title: title,
        scanPages: preparedScanPages,
        englishLines: englishLines,
        banglaRasterPages: banglaRasterPages,
        config: config,
        latinSearchableLines: latinSearchableLines,
      );
      lastBytes = bytes;
      lastPageCount = pageCount;

      if (config.maxSizeBytes == null || bytes.length <= config.maxSizeBytes!) {
        return BuiltExportBytes(
          bytes: bytes,
          pageCount: pageCount,
          exceededSizeLimit: false,
        );
      }
    }

    return BuiltExportBytes(
      bytes: lastBytes!,
      pageCount: lastPageCount,
      exceededSizeLimit: true,
    );
  }

  static Uint8List _prepareScanImage(
    Uint8List rawBytes, {
    required List<CoverRegion> regions,
    required bool blackAndWhite,
    required int quality,
    required int maxLongEdge,
  }) {
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) return rawBytes;

    var working = decoded.clone();
    final longEdge = math.max(working.width, working.height);
    if (longEdge > maxLongEdge) {
      final scale = maxLongEdge / longEdge;
      working = img.copyResize(
        working,
        width: math.max(1, (working.width * scale).round()),
        height: math.max(1, (working.height * scale).round()),
        interpolation: img.Interpolation.linear,
      );
    }

    if (regions.isNotEmpty || blackAndWhite) {
      working = ImageRedactor.applyToImage(
        working,
        regions: regions,
        blackAndWhite: blackAndWhite,
      );
    }

    return Uint8List.fromList(img.encodeJpg(working, quality: quality));
  }

  static PdfPageFormat _pageFormatFor(
    ExportPageSize size, {
    Uint8List? scanImageBytes,
  }) {
    switch (size) {
      case ExportPageSize.a4:
        return PdfPageFormat.a4;
      case ExportPageSize.letter:
        return PdfPageFormat.letter;
      case ExportPageSize.asScanned:
        if (scanImageBytes != null) {
          final decoded = img.decodeImage(scanImageBytes);
          if (decoded != null && decoded.width > 0 && decoded.height > 0) {
            // Map pixel aspect ratio to a clean A4-width PDF page.
            final wPt = PdfPageFormat.a4.width;
            final hPt = wPt * (decoded.height / decoded.width);
            return PdfPageFormat(wPt, hPt, marginAll: 18);
          }
        }
        return PdfPageFormat.a4;
    }
  }

  static Future<(Uint8List, int)> _renderPdf({
    required String title,
    required List<Uint8List> scanPages,
    required List<DraftLineView> englishLines,
    required List<Uint8List> banglaRasterPages,
    required PaperExportConfig config,
    required List<String> latinSearchableLines,
  }) async {
    final doc = pw.Document(
      title: _asciiSafe(title, fallback: 'Rosid Export'),
      creator: 'Rosid 2.0 (Offline)',
      compress: false,
    );

    final watermark = config.watermarkEnabled ? config.fullWatermarkLine : '';
    var pageCount = 0;

    // 1. Scan pages
    if (config.includeScan) {
      for (var i = 0; i < scanPages.length; i++) {
        final bytes = scanPages[i];
        final format = _pageFormatFor(config.pageSize, scanImageBytes: bytes);
        final memImage = pw.MemoryImage(bytes);
        doc.addPage(
          pw.Page(
            pageFormat: format,
            margin: const pw.EdgeInsets.all(20),
            build: (ctx) => pw.Stack(
              fit: pw.StackFit.expand,
              children: [
                // Invisible searchable Latin text layer (never Bangla — pdf pkg cannot shape Bangla).
                if (i == 0 && latinSearchableLines.isNotEmpty)
                  pw.Positioned.fill(
                    child: pw.Opacity(
                      opacity: 0.01,
                      child: pw.Text(
                        latinSearchableLines.map(_asciiSafe).join('\n'),
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ),
                  ),
                pw.Center(child: pw.Image(memImage, fit: pw.BoxFit.contain)),
                if (watermark.isNotEmpty) _watermarkOverlay(watermark),
              ],
            ),
          ),
        );
        pageCount++;
      }
    }

    // 2. English draft pages (real selectable English text + DRAFT TRANSLATION stamp + footer)
    if (config.includeEnglish && englishLines.isNotEmpty) {
      final format = _pageFormatFor(
        config.pageSize == ExportPageSize.asScanned
            ? ExportPageSize.a4
            : config.pageSize,
      );
      const linesPerPage = 24;
      final totalEnPages = (englishLines.length / linesPerPage).ceil();
      final accent = PdfColor.fromHex('#4333B0');
      final ink = PdfColor.fromHex('#1A1B2E');
      final muted = PdfColor.fromHex('#55586A');

      for (var p = 0; p < totalEnPages; p++) {
        final chunk = englishLines
            .skip(p * linesPerPage)
            .take(linesPerPage)
            .toList();
        doc.addPage(
          pw.Page(
            pageFormat: format,
            margin: const pw.EdgeInsets.fromLTRB(44, 42, 44, 38),
            build: (ctx) => pw.Stack(
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'ENGLISH DRAFT',
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: muted,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                _asciiSafe(
                                  title,
                                  fallback: 'Translated Document',
                                ),
                                style: pw.TextStyle(
                                  fontSize: 16,
                                  fontWeight: pw.FontWeight.bold,
                                  color: ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.Transform.rotate(
                          angle: -0.07,
                          child: pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: accent, width: 1.6),
                              borderRadius: pw.BorderRadius.circular(4),
                            ),
                            child: pw.Text(
                              'DRAFT TRANSLATION',
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: accent,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 12),
                    pw.Divider(
                      color: PdfColor.fromHex('#DCE0D3'),
                      thickness: 0.8,
                    ),
                    pw.SizedBox(height: 12),
                    for (final line in chunk) ...[
                      pw.Text(
                        _asciiSafe(line.englishText),
                        style: pw.TextStyle(
                          fontSize: 12,
                          lineSpacing: 4,
                          color: ink,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                    ],
                    pw.Spacer(),
                    pw.Divider(
                      color: PdfColor.fromHex('#DCE0D3'),
                      thickness: 0.6,
                    ),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Draft translation from Bangla',
                          style: pw.TextStyle(fontSize: 9, color: accent),
                        ),
                        pw.Text(
                          'Page ${p + 1} of $totalEnPages',
                          style: pw.TextStyle(fontSize: 9, color: muted),
                        ),
                      ],
                    ),
                  ],
                ),
                if (watermark.isNotEmpty) _watermarkOverlay(watermark),
              ],
            ),
          ),
        );
        pageCount++;
      }
    }

    // 3. Bangla text pages (pre-rendered as Flutter-shaped PNG images)
    if (config.includeBangla && banglaRasterPages.isNotEmpty) {
      final format = _pageFormatFor(
        config.pageSize == ExportPageSize.asScanned
            ? ExportPageSize.a4
            : config.pageSize,
      );
      for (final png in banglaRasterPages) {
        final mem = pw.MemoryImage(png);
        doc.addPage(
          pw.Page(
            pageFormat: format,
            margin: const pw.EdgeInsets.all(28),
            build: (ctx) => pw.Stack(
              fit: pw.StackFit.expand,
              children: [
                pw.Center(child: pw.Image(mem, fit: pw.BoxFit.contain)),
                if (watermark.isNotEmpty) _watermarkOverlay(watermark),
              ],
            ),
          ),
        );
        pageCount++;
      }
    }

    // 4. Translator's signature / certification page
    if (config.includeTranslatorPage) {
      final format = _pageFormatFor(
        config.pageSize == ExportPageSize.asScanned
            ? ExportPageSize.a4
            : config.pageSize,
      );
      final ink = PdfColor.fromHex('#1A1B2E');
      final muted = PdfColor.fromHex('#55586A');
      final lineColor = PdfColor.fromHex('#B9BFAE');

      doc.addPage(
        pw.Page(
          pageFormat: format,
          margin: const pw.EdgeInsets.all(48),
          build: (ctx) => pw.Stack(
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "Translator's Certification",
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: ink,
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Text(
                    'I certify that I am competent in Bangla and English, and that '
                    'the attached English draft has been reviewed and verified as '
                    'a true and accurate translation of the original Bangla document.',
                    style: pw.TextStyle(
                      fontSize: 11.5,
                      lineSpacing: 5,
                      color: ink,
                    ),
                  ),
                  pw.SizedBox(height: 36),
                  _signField('Translator full name', lineColor, muted),
                  pw.SizedBox(height: 24),
                  _signField(
                    'Qualification / Notary registration no.',
                    lineColor,
                    muted,
                  ),
                  pw.SizedBox(height: 24),
                  _signField('Signature', lineColor, muted),
                  pw.SizedBox(height: 24),
                  _signField('Date', lineColor, muted),
                  pw.SizedBox(height: 32),
                  pw.Container(
                    width: 180,
                    height: 96,
                    alignment: pw.Alignment.center,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                        color: lineColor,
                        style: pw.BorderStyle.dashed,
                      ),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Text(
                      'Official Seal / Stamp',
                      style: pw.TextStyle(fontSize: 10, color: muted),
                    ),
                  ),
                  pw.Spacer(),
                  pw.Text(
                    'Prepared on device with Rosid. Must be signed and sealed to certify.',
                    style: pw.TextStyle(fontSize: 9, color: muted),
                  ),
                ],
              ),
              if (watermark.isNotEmpty) _watermarkOverlay(watermark),
            ],
          ),
        ),
      );
      pageCount++;
    }

    // Guarantee at least one page if user unchecked everything.
    if (pageCount == 0) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (_) => pw.Center(
            child: pw.Text(_asciiSafe(title, fallback: 'Rosid Export')),
          ),
        ),
      );
      pageCount = 1;
    }

    final bytes = await doc.save();
    return (Uint8List.fromList(bytes), pageCount);
  }

  static pw.Widget _signField(
    String label,
    PdfColor lineColor,
    PdfColor muted,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 10, color: muted)),
        pw.SizedBox(height: 24),
        pw.Container(height: 0.8, color: lineColor),
      ],
    );
  }

  static pw.Widget _watermarkOverlay(String text) {
    return pw.Positioned.fill(
      child: pw.Center(
        child: pw.Transform.rotate(
          angle: 0.52,
          child: pw.Opacity(
            opacity: 0.16,
            child: pw.Text(
              _asciiSafe(text),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#4333B0'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Strips non-Latin-1 glyphs for standard PDF Type1 Helvetica font so `pdf`
  /// never crashes on Bangla characters in titles or mixed lines.
  static String _asciiSafe(String input, {String fallback = ''}) {
    final cleaned = input
        .replaceAll('\u2014', '-')
        .replaceAll('\u2013', '-')
        .replaceAll('\u2018', "'")
        .replaceAll('\u2019', "'")
        .replaceAll('\u201C', '"')
        .replaceAll('\u201D', '"')
        .replaceAll('৳', 'BDT ')
        .replaceAll(RegExp(r'[^\x20-\x7E\n]'), '')
        .replaceAll(RegExp(r' {2,}'), ' ')
        .trim();
    return cleaned.isEmpty ? fallback : cleaned;
  }
}
