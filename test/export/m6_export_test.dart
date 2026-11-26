import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:rosid/export/docx_writer.dart';
import 'package:rosid/export/export_models.dart';
import 'package:rosid/export/image_redactor.dart';
import 'package:rosid/export/paper_pdf_builder.dart';
import 'package:rosid/translation/translation_repository.dart';

Uint8List _makeSyntheticPageJpg({
  int width = 1200,
  int height = 1600,
  int seed = 1,
}) {
  final rng = math.Random(seed);
  final im = img.Image(width: width, height: height);
  img.fill(im, color: img.ColorRgb8(245, 245, 240));
  // Draw dense text-like horizontal lines and subtle texture so JPEG size is realistic.
  for (var y = 60; y < height - 60; y += 22) {
    final len = width - 160 - rng.nextInt(240);
    img.fillRect(
      im,
      x1: 80,
      y1: y,
      x2: 80 + len,
      y2: y + 6,
      color: img.ColorRgb8(30 + rng.nextInt(40), 30, 35),
    );
  }
  return Uint8List.fromList(img.encodeJpg(im, quality: 92));
}

/// Extracts readable text tokens from PDF `[(...)]TJ` content streams.
String extractPdfText(Uint8List pdfBytes) {
  final raw = latin1.decode(pdfBytes, allowInvalid: true);
  final matches = RegExp(r'\[\(([^)]*(?:\\.[^)]*)*)\)\]TJ').allMatches(raw);
  final words = <String>[];
  for (final m in matches) {
    final token = m
        .group(1)!
        .replaceAll(r'\(', '(')
        .replaceAll(r'\)', ')')
        .replaceAll(r'\\', r'\');
    words.add(token);
  }
  return words.join(' ');
}

void main() {
  final sampleDraft = <DraftLineView>[
    const DraftLineView(
      translationId: 't0',
      lineOrder: 0,
      sourceText: 'খতিয়ান নং ১২৪৫',
      englishText: 'Khatian (record of rights) No. 1245',
      edited: false,
      nameMarks: [],
      termMentions: [],
    ),
    const DraftLineView(
      translationId: 't1',
      lineOrder: 1,
      sourceText: 'মালিকের নাম: মোঃ আব্দুর রহমান',
      englishText: 'Owner: MD ABDUR RAHMAN',
      edited: false,
      nameMarks: [],
      termMentions: [],
    ),
    const DraftLineView(
      translationId: 't2',
      lineOrder: 2,
      sourceText: 'জমির পরিমাণ: ১২.৫০ শতাংশ',
      englishText: 'Area: 12.50 decimals (about 5,445 sq ft)',
      edited: false,
      nameMarks: [],
      termMentions: [],
    ),
  ];

  group('PaperPdfBuilder (M6 PDF gates)', () {
    test('checks page count, A4 vs Letter MediaBox size, DRAFT text on every English page, and watermark toggle', () async {
      final scanImg = _makeSyntheticPageJpg(width: 600, height: 800, seed: 7);

      // 1. With watermark + translator page + A4
      final builtA4 = await PaperPdfBuilder.build(
        title: 'Khatian Birulia',
        scanPageImages: [scanImg],
        englishLines: sampleDraft,
        banglaRasterPages: const [],
        config: const PaperExportConfig(
          includeScan: true,
          includeEnglish: true,
          includeBangla: false,
          includeTranslatorPage: true,
          pageSize: ExportPageSize.a4,
          watermarkEnabled: true,
          watermarkText: 'For visa application only',
          watermarkDateText: '26 Nov 2026',
        ),
      );
      expect(builtA4.pageCount, 3);
      final rawA4 = latin1.decode(builtA4.bytes, allowInvalid: true);
      final pdfText = extractPdfText(builtA4.bytes);
      expect(rawA4.startsWith('%PDF-'), isTrue);
      // A4 page MediaBox: 595.28 x 841.89 pt
      expect(rawA4, contains('595.2'));
      expect(rawA4, contains('841.8'));
      // DRAFT stamp & footer & English content present as real text in PDF
      expect(pdfText, contains('DRAFT TRANSLATION'));
      expect(pdfText, contains('Draft translation from Bangla'));
      expect(pdfText, contains('Owner: MD ABDUR RAHMAN'));
      expect(pdfText, contains("Translator's Certification"));
      expect(pdfText, contains('For visa application only, 26 Nov 2026'));

      // 2. Without watermark + Letter page size
      final builtLetter = await PaperPdfBuilder.build(
        title: 'Khatian Birulia',
        scanPageImages: [scanImg],
        englishLines: sampleDraft,
        banglaRasterPages: const [],
        config: const PaperExportConfig(
          includeScan: false,
          includeEnglish: true,
          includeBangla: false,
          includeTranslatorPage: false,
          pageSize: ExportPageSize.letter,
          watermarkEnabled: false,
          watermarkText: 'SECRET WATERMARK SHOULD NOT APPEAR',
        ),
      );
      expect(builtLetter.pageCount, 1);
      final rawLetter = latin1.decode(builtLetter.bytes, allowInvalid: true);
      final letterText = extractPdfText(builtLetter.bytes);
      // Letter MediaBox: 612 x 792 pt
      expect(rawLetter, contains('612'));
      expect(rawLetter, contains('792'));
      expect(letterText, contains('DRAFT TRANSLATION'));
      expect(letterText, isNot(contains('SECRET WATERMARK')));
    });

    test('size-limit loop shrinks a 6-page scan under 2 MB at >= 150 DPI equivalent and flags impossible limits', () async {
      final sixPages = [
        for (var i = 0; i < 6; i++)
          _makeSyntheticPageJpg(width: 1800, height: 2400, seed: 100 + i),
      ];
      final rawTotal = sixPages.fold<int>(0, (sum, b) => sum + b.length);
      expect(rawTotal, greaterThan(500 * 1024));

      final under2Mb = await PaperPdfBuilder.build(
        title: 'Six Page Land File',
        scanPageImages: sixPages,
        englishLines: const [],
        banglaRasterPages: const [],
        config: const PaperExportConfig(
          includeScan: true,
          includeEnglish: false,
          includeBangla: false,
          includeTranslatorPage: false,
          maxSizeBytes: 2 * 1024 * 1024,
        ),
      );
      expect(under2Mb.pageCount, 6);
      expect(under2Mb.exceededSizeLimit, isFalse);
      expect(under2Mb.bytes.length, lessThanOrEqualTo(2 * 1024 * 1024));

      // Impossibly small limit (20 KB for 6 pages) must report exceededSizeLimit == true.
      final impossible = await PaperPdfBuilder.build(
        title: 'Six Page Land File',
        scanPageImages: sixPages,
        englishLines: const [],
        banglaRasterPages: const [],
        config: const PaperExportConfig(
          includeScan: true,
          includeEnglish: false,
          includeBangla: false,
          includeTranslatorPage: false,
          maxSizeBytes: 20 * 1024,
        ),
      );
      expect(impossible.exceededSizeLimit, isTrue);
    });
  });

  group('ImageRedactor (Cover a detail destructive pixel test)', () {
    test('black bar destroys every original pixel in the covered region while leaving outside pixels intact', () {
      // Build a 200x200 image with distinct bright red/green/blue stripes inside [40..160, 80..120].
      final original = img.Image(width: 200, height: 200);
      img.fill(original, color: img.ColorRgb8(250, 250, 250));
      for (var y = 80; y < 120; y++) {
        for (var x = 40; x < 160; x++) {
          final isRed = (x % 4) < 2;
          original.setPixelRgb(
            x,
            y,
            isRed ? 240 : 20,
            isRed ? 20 : 220,
            isRed ? 20 : 40,
          );
        }
      }
      final srcClone = original.clone();

      final redacted = ImageRedactor.applyToImage(
        original.clone(),
        regions: const [
          CoverRegion(
            pageIndex: 0,
            left: 0.20,
            top: 0.40,
            right: 0.80,
            bottom: 0.60,
            style: CoverStyle.blackBar,
          ),
        ],
      );

      // Every single pixel inside the covered rectangle must be dark ink, zero original stripe pixels!
      for (var y = 82; y < 118; y++) {
        for (var x = 42; x < 158; x++) {
          final p = redacted.getPixel(x, y);
          final orig = srcClone.getPixel(x, y);
          expect(p.r, lessThan(40));
          expect(p.g, lessThan(40));
          expect(p.b, lessThan(45));
          expect(p.r == orig.r && p.g == orig.g && p.b == orig.b, isFalse);
        }
      }

      // Pixels outside covered region stay white.
      final outside = redacted.getPixel(10, 10);
      expect(outside.r, greaterThan(240));
      expect(outside.g, greaterThan(240));
      expect(outside.b, greaterThan(240));

      // Blur/mosaic mode also destroys high-frequency stripe detail irreversibly.
      final blurred = ImageRedactor.applyToImage(
        original.clone(),
        regions: const [
          CoverRegion(
            pageIndex: 0,
            left: 0.20,
            top: 0.40,
            right: 0.80,
            bottom: 0.60,
            style: CoverStyle.blur,
          ),
        ],
      );
      var exactOriginalMatches = 0;
      for (var y = 82; y < 118; y++) {
        for (var x = 42; x < 158; x++) {
          final p = blurred.getPixel(x, y);
          final orig = srcClone.getPixel(x, y);
          if ((p.r - orig.r).abs() < 10 && (p.g - orig.g).abs() < 10) {
            exactOriginalMatches++;
          }
        }
      }
      expect(exactOriginalMatches, 0);
    });
  });

  group('DocxWriter (M6 Word .docx gate)', () {
    test('writes valid zip with well-formed XML, Bangla cs font/bidi lang, English draft, and DRAFT header', () {
      final bytes = DocxWriter.build(
        title: 'খতিয়ান, বিরুলিয়া',
        banglaLines: sampleDraft.map((d) => d.sourceText).toList(),
        englishLines: sampleDraft,
        includeBangla: true,
        includeEnglish: true,
        includeTranslatorPage: true,
        watermarkText: 'For visa application only',
      );

      final archive = ZipDecoder().decodeBytes(bytes);
      final fileMap = <String, String>{
        for (final f in archive) f.name: utf8.decode(f.content as List<int>),
      };

      expect(
        fileMap.keys,
        containsAll([
          '[Content_Types].xml',
          '_rels/.rels',
          'word/_rels/document.xml.rels',
          'word/document.xml',
          'word/header1.xml',
        ]),
      );

      final docXml = fileMap['word/document.xml']!;
      expect(docXml, contains('খতিয়ান নং ১২৪৫'));
      expect(docXml, contains('Khatian (record of rights) No. 1245'));
      expect(docXml, contains('Owner: MD ABDUR RAHMAN'));
      expect(docXml, contains('w:cs="Nirmala UI"'));
      expect(docXml, contains('w:bidi="bn-BD"'));
      expect(docXml, contains("Translator&apos;s Certification"));

      final headerXml = fileMap['word/header1.xml']!;
      expect(headerXml, contains('DRAFT TRANSLATION'));
      expect(headerXml, contains('For visa application only'));
    });
  });
}
