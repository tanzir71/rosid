import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosid/core/profile/app_profile.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/repositories/record_repository.dart';
import 'package:rosid/data/repositories/scan_repository.dart';
import 'package:rosid/features/paper/paper_repository.dart';
import 'package:rosid/ocr/pipeline/post_reading.dart';
import 'package:rosid/ocr/pipeline/reading_interfaces.dart';
import 'package:rosid/parsing/land_units.dart';
import 'package:rosid/parsing/paper_classifier.dart';

void main() {
  group(
    'LandUnits pure conversion tests (12.50 decimals + 12 additional cases)',
    () {
      test(
        '12.50 decimals gives 5,445 sq ft, 0.125 acre, about 7.56 katha',
        () {
          final conv = LandUnits.parseFromText('জমির পরিমাণ: ১২.৫০ শতাংশ');
          expect(conv, isNotNull);
          expect(conv!.decimals, closeTo(12.50, 0.001));
          expect(conv.sqFt, closeTo(5445.0, 0.1));
          expect(conv.acres, closeTo(0.125, 0.0001));
          expect(conv.katha, closeTo(7.5625, 0.01));
          expect(conv.formattedDecimals, '12.50 decimals');
          expect(conv.formattedSqFt, '5,445 sq ft');
          expect(conv.formattedAcres, '0.125 acre');
          expect(conv.formattedKatha, 'about 7.56 katha');
        },
      );

      test('additional 12 cases across decimals, acres, katha, bigha, sq ft and Bangla numerals', () {
        // 1. 100 decimals = 1 acre = 43,560 sq ft
        final c1 = LandUnits.convert(100, LandUnit.decimal);
        expect(c1.acres, closeTo(1.0, 0.0001));
        expect(c1.sqFt, closeTo(43560, 0.1));
        expect(c1.formattedSqFt, '43,560 sq ft');

        // 2. 1 acre = 100 decimals
        final c2 = LandUnits.parseFromText('মোট জমি: ১ একর');
        expect(c2!.decimals, closeTo(100.0, 0.01));
        expect(c2.katha, closeTo(60.5, 0.01));

        // 3. 1 katha = 720 sq ft
        final c3 = LandUnits.parseFromText('১ কাঠা');
        expect(c3!.sqFt, closeTo(720.0, 0.01));
        expect(c3.decimals, closeTo(1.6529, 0.01));

        // 4. 5 katha = 3,600 sq ft
        final c4 = LandUnits.parseFromText('৫ কাঠা');
        expect(c4!.sqFt, closeTo(3600.0, 0.01));
        expect(c4.bigha, closeTo(0.25, 0.001));

        // 5. 1 bigha = 20 katha = 14,400 sq ft
        final c5 = LandUnits.parseFromText('১ বিঘা');
        expect(c5!.katha, closeTo(20.0, 0.01));
        expect(c5.sqFt, closeTo(14400.0, 0.01));
        expect(c5.formattedBigha, 'about 1.00 bigha');

        // 6. 2.5 bigha = 50 katha
        final c6 = LandUnits.parseFromText('2.5 bigha');
        expect(c6!.katha, closeTo(50.0, 0.01));

        // 7. 33 decimals ≈ 1 bigha
        final c7 = LandUnits.parseFromText('৩৩ শতক');
        expect(c7!.bigha, closeTo(0.99825, 0.01));

        // 8. 435.6 sq ft = 1 decimal
        final c8 = LandUnits.parseFromText('435.6 sq ft');
        expect(c8!.decimals, closeTo(1.0, 0.001));

        // 9. 720 বর্গফুট = 1 katha
        final c9 = LandUnits.parseFromText('৭২০ বর্গফুট');
        expect(c9!.katha, closeTo(1.0, 0.001));

        // 10. 0.50 acre = 50 decimals = 21,780 sq ft
        final c10 = LandUnits.parseFromText('0.50 acres');
        expect(c10!.decimals, closeTo(50.0, 0.01));
        expect(c10.formattedSqFt, '21,780 sq ft');

        // 11. 8.25 decimals
        final c11 = LandUnits.parseFromText('৮.২৫ শতাংশ');
        expect(c11!.sqFt, closeTo(3593.7, 0.1));
        expect(c11.formattedKatha, 'about 4.99 katha');

        // 12. Non-land line returns null
        expect(LandUnits.parseFromText('দাগ নং: ৩০২, শ্রেণি: ভিটি'), isNull);
      });
    },
  );

  group(
    'PaperClassifier key details accuracy on land-record fixtures (>= 90%)',
    () {
      test('extracts khatian no., plot no., and area on >= 90% of synthetic land fixtures', () {
        const classifier = PaperClassifier();
        final dir = Directory('test/fixtures/synthetic');
        final landFiles =
            dir
                .listSync()
                .whereType<File>()
                .where(
                  (f) =>
                      f.path.endsWith('.json') &&
                      f.uri.pathSegments.last.startsWith('land_'),
                )
                .toList()
              ..sort((a, b) => a.path.compareTo(b.path));

        expect(landFiles.length, greaterThanOrEqualTo(28));

        var khatianHits = 0;
        var plotHits = 0;
        var areaHits = 0;

        for (final file in landFiles) {
          final meta =
              jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
          final lines = (meta['lines'] as List<dynamic>).cast<String>();
          final truth = meta['details'] as Map<String, dynamic>;

          final kind = classifier.classify(lines.join('\n'));
          expect(kind, PaperKind.land);

          final details = classifier.extractDetails(lines, kind: kind);
          String? valOf(String k) {
            for (final d in details) {
              if (d.key == k) return d.value;
            }
            return null;
          }

          final gotKhatian = PaperClassifier.normalizeDigits(
            valOf('khatian_no') ?? '',
          );
          final gotPlot = PaperClassifier.normalizeDigits(
            valOf('plot_no') ?? '',
          );
          final gotArea = LandUnits.parseFromText(valOf('area') ?? '');

          if (gotKhatian == truth['khatian_no'].toString()) khatianHits++;
          if (gotPlot == truth['plot_no'].toString()) plotHits++;
          if (gotArea != null &&
              (gotArea.decimals - (truth['area_decimals'] as num).toDouble())
                      .abs() <
                  0.01) {
            areaHits++;
          }
        }

        final n = landFiles.length;
        expect(khatianHits / n, greaterThanOrEqualTo(0.90));
        expect(plotHits / n, greaterThanOrEqualTo(0.90));
        expect(areaHits / n, greaterThanOrEqualTo(0.90));
      });
    },
  );

  group('Remembered corrections & non-destructive full-text edit', () {
    test('correcting a word stores it in corrections and offers remembered form first on a subsequent scan', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final scans = ScanRepository(db);
      final records = RecordRepository(db);
      final paperRepo = PaperRepository(db, records);

      // First scan has misread word "বিরুলযা"
      await scans.createScan(
        id: 'scan-1',
        mode: ScanMode.document,
        imagePath: '/tmp/s1.jpg',
        langHint: 'bn',
        createdAt: DateTime(2026, 11, 27),
      );
      await db
          .into(db.textLines)
          .insert(
            TextLinesCompanion.insert(
              id: 'line-1',
              scanId: 'scan-1',
              pageIndex: 0,
              lineOrder: 0,
              textContent: 'মৌজা: বিরুলযা',
              confidence: const Value(0.62),
            ),
          );

      final firstPaper = await paperRepo.loadPaper('scan-1');
      expect(firstPaper, isNotNull);
      final targetLine = firstPaper!.lines.first;

      // User corrects "বিরুলযা" -> "বিরুলিয়া" and saves to name book
      await paperRepo.applyWordCorrection(
        scanId: 'scan-1',
        line: targetLine,
        wrongWord: 'বিরুলযা',
        rightWord: 'বিরুলিয়া',
        addToNameBook: true,
      );

      final corrRows = await db.select(db.corrections).get();
      expect(corrRows, hasLength(1));
      expect(corrRows.first.wrongReading, 'বিরুলযা');
      expect(corrRows.first.rightReading, 'বিরুলিয়া');

      final nameRows = await db.select(db.names).get();
      expect(nameRows.any((n) => n.bangla == 'বিরুলিয়া'), isTrue);

      // Second scan has the exact same misread word "বিরুলযা"
      await scans.createScan(
        id: 'scan-2',
        mode: ScanMode.document,
        imagePath: '/tmp/s2.jpg',
        langHint: 'bn',
        createdAt: DateTime(2026, 11, 27),
      );
      await db
          .into(db.textLines)
          .insert(
            TextLinesCompanion.insert(
              id: 'line-2',
              scanId: 'scan-2',
              pageIndex: 0,
              lineOrder: 0,
              textContent: 'মৌজা: বিরুলযা',
              confidence: const Value(0.60),
            ),
          );

      final secondPaper = await paperRepo.loadPaper('scan-2');
      final wordCheck = secondPaper!.checkWords.firstWhere(
        (w) => w.word == 'বিরুলযা',
      );
      expect(wordCheck.alternatives.first, 'বিরুলিয়া');

      // Also check PostReadingProcessor directly offers remembered form first
      const processor = PostReadingProcessor();
      final processed = processor.processLine(
        const RecognizedLine(
          pageIndex: 0,
          lineOrder: 0,
          text: 'মৌজা: বিরুলযা',
          originalText: 'মৌজা: বিরুলযা',
          box: DetectedLineBox(
            topLeft: (0, 0),
            topRight: (100, 0),
            bottomRight: (100, 24),
            bottomLeft: (0, 24),
            score: 1,
          ),
          confidence: 0.60,
          script: 'bn',
          engineId: 'test',
        ),
        remembered: const [
          RememberedCorrection(wrongText: 'বিরুলযা', rightText: 'বিরুলিয়া'),
        ],
      );
      final u = processed.uncertainWords.firstWhere((e) => e.word == 'বিরুলযা');
      expect(u.alternatives.first, 'বিরুলিয়া');
    });

    test(
      'editing full text keeps scans.ocrRawText original untouched',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final scans = ScanRepository(db);
        final records = RecordRepository(db);
        final paperRepo = PaperRepository(db, records);

        await scans.createScan(
          id: 'scan-edit',
          mode: ScanMode.document,
          imagePath: '/tmp/e.jpg',
          langHint: 'bn',
          createdAt: DateTime(2026, 11, 27),
        );
        await (db.update(db.scans)..where((s) => s.id.equals('scan-edit')))
            .write(const ScansCompanion(ocrRawText: Value('মূল পাঠ ১২৪৫')));

        await paperRepo.updateFullText(
          'scan-edit',
          title: 'খতিয়ান',
          body: 'সম্পাদিত পাঠ ১২৪৫',
        );

        final scan = await (db.select(
          db.scans,
        )..where((s) => s.id.equals('scan-edit'))).getSingle();
        final doc = await (db.select(
          db.documents,
        )..where((d) => d.scanId.equals('scan-edit'))).getSingle();
        expect(scan.ocrRawText, 'মূল পাঠ ১২৪৫');
        expect(doc.body, 'সম্পাদিত পাঠ ১২৪৫');
      },
    );
  });
}
