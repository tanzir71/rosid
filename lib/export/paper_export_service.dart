import 'dart:io';
import 'dart:ui' as ui;

import 'package:csv/csv.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rosid/core/theme/tokens.g.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/database/database_provider.dart';
import 'package:rosid/data/files/private_file_store.dart';
import 'package:rosid/export/docx_writer.dart';
import 'package:rosid/export/export_models.dart';
import 'package:rosid/export/image_redactor.dart';
import 'package:rosid/export/paper_pdf_builder.dart';
import 'package:rosid/features/export/export_service.dart';
import 'package:rosid/features/paper/paper_repository.dart';
import 'package:rosid/translation/bangla_transliterator.dart';
import 'package:rosid/translation/translation_repository.dart';
import 'package:uuid/uuid.dart';

/// Native Android bridge (`MainActivity.kt` -> `PlatformFileBridge.kt`) for
/// Storage Access Framework saving, Android PrintManager printing, and folder opening.
class PlatformFileService {
  static const MethodChannel _channel = MethodChannel('app.rosid.rosid/files');

  Future<({bool saved, String? uri, String? displayName})> saveFileToPhone({
    required String sourcePath,
    required String suggestedName,
    required String mimeType,
  }) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('saveFile', {
        'sourcePath': sourcePath,
        'suggestedName': suggestedName,
        'mimeType': mimeType,
      });
      if (res == null) return (saved: false, uri: null, displayName: null);
      return (
        saved: res['saved'] == true,
        uri: res['uri'] as String?,
        displayName: res['displayName'] as String?,
      );
    } on Object {
      return (saved: false, uri: null, displayName: null);
    }
  }

  Future<bool> printPdf({
    required String filePath,
    required String jobName,
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('printPdf', {
        'filePath': filePath,
        'jobName': jobName,
      });
      return ok ?? false;
    } on Object {
      return false;
    }
  }

  Future<bool> openFolder(String? uri) async {
    try {
      final ok = await _channel.invokeMethod<bool>('openFolder', {
        'uri': uri ?? '',
      });
      return ok ?? false;
    } on Object {
      return false;
    }
  }
}

final platformFileServiceProvider = Provider<PlatformFileService>(
  (ref) => PlatformFileService(),
);

/// Builds temporary exported files (PDF, DOCX, TXT, JPG, CSV) for any paper.
class PaperExportService {
  const PaperExportService(this.fileStore, this.db);

  final PrivateFileStore fileStore;
  final AppDatabase db;
  static const _uuid = Uuid();

  /// Generates a clean ASCII filename like `Khatian-Birulia-English.pdf`.
  static String buildFileName(PaperViewData paper, PaperExportConfig config) {
    final translit = BanglaTransliterator.transliterate(paper.title);
    final slug = translit
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final base = slug.isEmpty ? 'Rosid-Paper' : slug;
    final suffix =
        config.includeEnglish && config.fileType != ExportFileType.jpg
        ? '-English'
        : '';
    return '$base$suffix${config.fileType.extension}';
  }

  /// Renders Bangla lines into crisp Flutter-shaped PNG page images (used when
  /// Bangla text is included in PDF exports, per `02-architecture.md`).
  static Future<List<Uint8List>> renderBanglaPagesToPng(
    String title,
    List<String> lines,
  ) async {
    if (lines.isEmpty) return const [];
    const width = 1240;
    const height = 1754;
    const linesPerPage = 24;
    final pages = <Uint8List>[];

    for (var start = 0; start < lines.length; start += linesPerPage) {
      final chunk = lines.skip(start).take(linesPerPage).toList();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 1240, 1754));
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 1240, 1754),
        Paint()..color = RosidColorTokens.paperSheetLight,
      );

      var y = 96.0;
      if (start == 0 && title.trim().isNotEmpty) {
        final titlePb =
            ui.ParagraphBuilder(
                ui.ParagraphStyle(
                  fontFamily: 'Tiro Bangla',
                  fontSize: 38,
                  height: 1.45,
                ),
              )
              ..pushStyle(ui.TextStyle(color: RosidColorTokens.paperInkLight))
              ..addText(title);
        final titleP = titlePb.build()
          ..layout(const ui.ParagraphConstraints(width: 1060));
        canvas.drawParagraph(titleP, Offset(90, y));
        y += titleP.height + 28;
      }

      for (final line in chunk) {
        final pb =
            ui.ParagraphBuilder(
                ui.ParagraphStyle(
                  fontFamily: 'Tiro Bangla',
                  fontSize: 30,
                  height: 1.55,
                ),
              )
              ..pushStyle(ui.TextStyle(color: RosidColorTokens.paperInkLight))
              ..addText(line);
        final p = pb.build()
          ..layout(const ui.ParagraphConstraints(width: 1060));
        canvas.drawParagraph(p, Offset(90, y));
        y += p.height + 16;
      }

      final picture = recorder.endRecording();
      final image = await picture.toImage(width, height);
      final bd = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bd != null) {
        pages.add(bd.buffer.asUint8List());
      }
    }
    return pages;
  }

  /// Generates the export file in the app's temporary export directory.
  Future<PaperExportResult> createExport({
    required PaperViewData paper,
    required List<DraftLineView> englishLines,
    required PaperExportConfig config,
  }) async {
    final fileName = buildFileName(paper, config);
    final uniquePrefix = _uuid.v7().substring(0, 8);
    final outPath = await fileStore.createExportPath(
      '${uniquePrefix}_$fileName',
    );

    final scanBytes = <Uint8List>[];
    if (paper.pages.isNotEmpty) {
      for (final p in paper.pages) {
        final path = p.processedPath ?? p.imagePath;
        final f = File(path);
        if (f.existsSync()) {
          scanBytes.add(await f.readAsBytes());
        }
      }
    } else {
      final f = File(paper.scan.imagePath);
      if (f.existsSync()) {
        scanBytes.add(await f.readAsBytes());
      }
    }

    final banglaLines = paper.lines.isNotEmpty
        ? paper.lines.map((l) => l.textContent).toList()
        : paper.displayBody
              .split('\n')
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty)
              .toList();

    switch (config.fileType) {
      case ExportFileType.pdf:
        final banglaPngs = config.includeBangla
            ? await renderBanglaPagesToPng(paper.title, banglaLines)
            : const <Uint8List>[];
        final latinLines = paper.lines
            .where((l) => l.script == 'en')
            .map((l) => l.textContent)
            .toList();
        final built = await PaperPdfBuilder.build(
          title: paper.title,
          scanPageImages: scanBytes,
          englishLines: englishLines,
          banglaRasterPages: banglaPngs,
          config: config,
          latinSearchableLines: latinLines,
        );
        await File(outPath).writeAsBytes(built.bytes, flush: true);
        return PaperExportResult(
          tempFilePath: outPath,
          fileName: fileName,
          mimeType: ExportFileType.pdf.mimeType,
          pageCount: built.pageCount,
          sizeBytes: built.bytes.length,
          exceededSizeLimit: built.exceededSizeLimit,
        );

      case ExportFileType.docx:
        final bytes = DocxWriter.build(
          title: paper.title,
          banglaLines: banglaLines,
          englishLines: englishLines,
          includeBangla: config.includeBangla || !config.includeEnglish,
          includeEnglish: config.includeEnglish,
          includeTranslatorPage: config.includeTranslatorPage,
          watermarkText: config.watermarkEnabled
              ? config.fullWatermarkLine
              : null,
        );
        await File(outPath).writeAsBytes(bytes, flush: true);
        final pages = 1 + (config.includeTranslatorPage ? 1 : 0);
        return PaperExportResult(
          tempFilePath: outPath,
          fileName: fileName,
          mimeType: ExportFileType.docx.mimeType,
          pageCount: pages,
          sizeBytes: bytes.length,
          exceededSizeLimit:
              config.maxSizeBytes != null &&
              bytes.length > config.maxSizeBytes!,
        );

      case ExportFileType.txt:
        final sb = StringBuffer();
        if (config.includeEnglish && englishLines.isNotEmpty) {
          sb.writeln('DRAFT TRANSLATION — Draft translation from Bangla');
          sb.writeln(
            'This draft was made on your phone. Check names and numbers before you use it.',
          );
          sb.writeln();
          for (final l in englishLines) {
            if (config.includeBangla) {
              sb.writeln(l.sourceText);
            }
            sb.writeln(l.englishText);
            sb.writeln();
          }
        } else {
          for (final line in banglaLines) {
            sb.writeln(line);
          }
        }
        final content = sb.toString().trimRight();
        await File(outPath).writeAsString('$content\n', flush: true);
        final sz = await File(outPath).length();
        return PaperExportResult(
          tempFilePath: outPath,
          fileName: fileName,
          mimeType: ExportFileType.txt.mimeType,
          pageCount: 1,
          sizeBytes: sz,
          exceededSizeLimit: false,
        );

      case ExportFileType.jpg:
        final extras = <String>[];
        var totalSize = 0;
        if (scanBytes.isEmpty) {
          await File(outPath).writeAsBytes(const [], flush: true);
        } else {
          for (var i = 0; i < scanBytes.length; i++) {
            final pageRegions = config.coverRegions
                .where((r) => r.pageIndex == i)
                .toList();
            final redacted = ImageRedactor.applyToBytes(
              scanBytes[i],
              regions: pageRegions,
              blackAndWhite: config.blackAndWhite,
            );
            final p = i == 0
                ? outPath
                : await fileStore.createExportPath(
                    '${uniquePrefix}_page_${i + 1}_$fileName',
                  );
            await File(p).writeAsBytes(redacted, flush: true);
            totalSize += redacted.length;
            if (i > 0) extras.add(p);
          }
        }
        return PaperExportResult(
          tempFilePath: outPath,
          fileName: fileName,
          mimeType: ExportFileType.jpg.mimeType,
          pageCount: scanBytes.isEmpty ? 1 : scanBytes.length,
          sizeBytes: totalSize,
          exceededSizeLimit:
              config.maxSizeBytes != null && totalSize > config.maxSizeBytes!,
          extraFilePaths: extras,
        );

      case ExportFileType.csv:
        final receipt = await (db.select(
          db.receipts,
        )..where((r) => r.scanId.equals(paper.scan.id))).getSingleOrNull();
        final rows = <List<Object?>>[
          const [
            'Date',
            'Merchant',
            'Category',
            'Total',
            'Currency',
            'VAT',
            'Payment method',
            'Note',
          ],
          if (receipt != null)
            [
              DateFormat('yyyy-MM-dd').format(receipt.dateOfPurchase),
              sanitizeCsvTextCell(receipt.merchant),
              sanitizeCsvTextCell(receipt.categoryId ?? 'Other'),
              receipt.total.toStringAsFixed(2),
              sanitizeCsvTextCell(receipt.currency),
              receipt.tax?.toStringAsFixed(2) ?? '',
              sanitizeCsvTextCell(receipt.paymentMethod ?? ''),
              sanitizeCsvTextCell(receipt.note ?? ''),
            ],
        ];
        await File(outPath)
            .writeAsString('\ufeff${csv.encode(rows)}', flush: true);
        final sz = await File(outPath).length();
        return PaperExportResult(
          tempFilePath: outPath,
          fileName: fileName,
          mimeType: ExportFileType.csv.mimeType,
          pageCount: 1,
          sizeBytes: sz,
          exceededSizeLimit: false,
        );
    }
  }
}

final paperExportServiceProvider = Provider<PaperExportService>(
  (ref) => PaperExportService(
    ref.watch(privateFileStoreProvider),
    ref.watch(databaseProvider),
  ),
);
