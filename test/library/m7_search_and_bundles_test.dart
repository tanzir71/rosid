import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:rosid/core/profile/app_profile.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/repositories/record_repository.dart';
import 'package:rosid/data/repositories/scan_repository.dart';
import 'package:rosid/export/bundle_export_service.dart';
import 'package:rosid/features/library/library_search_service.dart';
import 'package:rosid/parsing/normalizers/text_normalizer.dart';
import 'package:rosid/translation/translation_repository.dart';

String _extractPdfText(Uint8List pdfBytes) {
  final raw = latin1.decode(pdfBytes, allowInvalid: true);
  final matches = RegExp(r'\[\(([^)]*(?:\\.[^)]*)*)\)\]TJ').allMatches(raw);
  return matches
      .map(
        (m) => m
            .group(1)!
            .replaceAll(r'\(', '(')
            .replaceAll(r'\)', ')')
            .replaceAll(r'\\', r'\'),
      )
      .join(' ');
}

Uint8List _blankPageJpg() {
  final im = img.Image(width: 400, height: 560);
  img.fill(im, color: img.ColorRgb8(246, 246, 242));
  return Uint8List.fromList(img.encodeJpg(im, quality: 80));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TextNormalizer.normalizeForSearch (Bangla NFC, ZWJ, variants)', () {
    test('normalizes NFC, strips ZWJ/ZWNJ, and treats decomposed/precomposed য় and ড় as equal', () {
      // Precomposed vs decomposed য় (`য` + nukta) and ড় (`ড` + nukta)
      final precomposed = TextNormalizer.normalizeForSearch(
        'বিরুলিয়া বড়বাড়ী',
      );
      final decomposed = TextNormalizer.normalizeForSearch(
        'বিরুলিয\u09BCা বড\u09BCবাড\u09BCী',
      );
      expect(precomposed, decomposed);

      // Zero-width joiners/non-joiners stripped
      final withZwj = TextNormalizer.normalizeForSearch(
        'খতি\u200Dয়ান\u200C নং ১২৪৫',
      );
      final clean = TextNormalizer.normalizeForSearch('খতিয়ান নং ১২৪৫');
      expect(withZwj, clean);
    });
  });

  group(
    'LibrarySearchService (cross-script Name Book & English draft search)',
    () {
      late AppDatabase db;
      late LibrarySearchService search;

      setUp(() async {
        db = AppDatabase.forTesting(NativeDatabase.memory());
        search = LibrarySearchService(db);

        final scans = ScanRepository(db);
        final records = RecordRepository(db);
        await scans.createScan(
          id: 's-khatian',
          mode: ScanMode.document,
          imagePath: '/tmp/k.jpg',
          langHint: 'bn',
          createdAt: DateTime(2026, 11, 26),
        );
        await (db.update(db.scans)..where((s) => s.id.equals('s-khatian')))
            .write(const ScansCompanion(kind: Value('land')));
        await db
            .into(db.textLines)
            .insert(
              TextLinesCompanion.insert(
                id: 'l-1',
                scanId: 's-khatian',
                pageIndex: 0,
                lineOrder: 0,
                textContent: 'মৌজা: বিরুলিয়া, জে.এল. নং: ৩৫',
              ),
            );
        await db
            .into(db.translations)
            .insert(
              TranslationsCompanion.insert(
                id: 'tr-1',
                scanId: 's-khatian',
                lineId: const Value('l-1'),
                lineOrder: 0,
                sourceText: const Value('মৌজা: বিরুলিয়া, জে.এল. নং: ৩৫'),
                englishText: 'Mouza: Birulia. J.L. No. 35',
              ),
            );
        await records.saveDocument(
          scanId: 's-khatian',
          title: 'খতিয়ান, বিরুলিয়া',
          body: 'মৌজা: বিরুলিয়া, জে.এল. নং: ৩৫',
          tags: const [],
        );
        await db.indexScan(
          scanId: 's-khatian',
          text: [
            'খতিয়ান, বিরুলিয়া',
            'মৌজা: বিরুলিয়া, জে.এল. নং: ৩৫',
            'Mouza: Birulia. J.L. No. 35',
          ],
        );

        // Seed another paper with Bangla-only text (no English draft yet) for Name Book cross-script test.
        await scans.createScan(
          id: 's-namjari',
          mode: ScanMode.document,
          imagePath: '/tmp/n.jpg',
          langHint: 'bn',
          createdAt: DateTime(2026, 11, 20),
        );
        await db
            .into(db.textLines)
            .insert(
              TextLinesCompanion.insert(
                id: 'l-2',
                scanId: 's-namjari',
                pageIndex: 1,
                lineOrder: 0,
                textContent: 'মালিক: মোঃ আব্দুর রহমান, সাং: বিরুলিয়া',
              ),
            );
        await records.saveDocument(
          scanId: 's-namjari',
          title: 'নামজারি খতিয়ান',
          body: 'মালিক: মোঃ আব্দুর রহমান, সাং: বিরুলিয়া',
          tags: const [],
        );

        // Name Book entries connecting scripts
        await db
            .into(db.names)
            .insert(
              NamesCompanion.insert(
                id: 'nb-1',
                bangla: 'বিরুলিয়া',
                english: 'Birulia',
                category: const Value('place'),
                source: const Value('manual'),
                confirmed: const Value(true),
              ),
            );
        await db
            .into(db.names)
            .insert(
              NamesCompanion.insert(
                id: 'nb-2',
                bangla: 'মোঃ আব্দুর রহমান',
                english: 'MD ABDUR RAHMAN',
                category: const Value('person'),
                source: const Value('passport'),
                confirmed: const Value(true),
              ),
            );
      });

      tearDown(() async => db.close());

      test('Bangla query finds Bangla text and English draft hits', () async {
        final res = await search.search('বিরুলিয়া');
        expect(res.paperCount, 2);
        expect(
          res.hits.any((h) => h.scanId == 's-khatian' && !h.isEnglishDraft),
          isTrue,
        );
        expect(
          res.hits.any((h) => h.scanId == 's-khatian' && h.isEnglishDraft),
          isTrue,
        );
        expect(
          res.hits.any((h) => h.scanId == 's-namjari' && h.pageNumber == 2),
          isTrue,
        );
      });

      test('English spelling of a Name Book entry finds Bangla-only paper across scripts', () async {
        final res = await search.search('MD ABDUR RAHMAN');
        expect(res.paperCount, 1);
        expect(res.hits.first.scanId, 's-namjari');
      });

      test(
        'Decomposed Bangla nukta query matches precomposed indexed Bangla text',
        () async {
          final res = await search.search('বিরুলিয\u09BCা');
          expect(res.paperCount, 2);
        },
      );
    },
  );

  group('Checklists asset & BundlePdfBuilder', () {
    test('assets/data/checklists.json contains 5 templates each with official-list disclaimer', () {
      final raw = File('assets/data/checklists.json').readAsStringSync();
      final list = jsonDecode(raw) as List<dynamic>;
      expect(list.length, 5);
      for (final item in list) {
        final m = item as Map<String, dynamic>;
        expect(
          m['disclaimerEn'],
          'Check the official list for your application.',
        );
      }
    });

    test('BundlePdfBuilder builds Contents page in checklist order with exact page numbers and DRAFT stamp', () async {
      final jpg = _blankPageJpg();
      final built = await BundlePdfBuilder.buildOnePdf(
        bundleTitle: 'UK student visa, Farhana',
        papers: [
          BundlePaperInput(
            title: 'Passport',
            scanImages: [jpg, jpg], // 2 pages -> starts Page 2
            englishLines: const [],
          ),
          BundlePaperInput(
            title: 'National ID, both sides',
            scanImages: [jpg], // 1 page -> starts Page 4
            englishLines: const [],
          ),
          BundlePaperInput(
            title: 'Birth certificate',
            scanImages: [
              jpg,
            ], // 1 scan + 1 English draft = 2 pages -> starts Page 5
            englishLines: const [
              DraftLineView(
                translationId: 'd1',
                lineOrder: 0,
                sourceText: 'জন্ম নিবন্ধন সনদ',
                englishText: 'Birth registration certificate',
                edited: false,
                nameMarks: [],
                termMentions: [],
              ),
            ],
          ),
        ],
        maxSizeBytes: 2 * 1024 * 1024,
        watermarkText: 'For visa application only',
      );

      expect(built.exceededSizeLimit, isFalse);
      expect(built.totalPages, 6);
      expect(built.contents.length, 3);
      expect(built.contents[0].startPage, 2);
      expect(built.contents[1].startPage, 4);
      expect(built.contents[2].startPage, 5);

      final text = _extractPdfText(built.bytes);
      expect(text, contains('CONTENTS'));
      expect(text, contains('01 Passport Page 2'));
      expect(text, contains('02 National ID, both sides Page 4'));
      expect(text, contains('03 Birth certificate Page 5'));
      expect(text, contains('DRAFT TRANSLATION'));
      expect(text, contains('For visa application only'));
    });
  });
}
