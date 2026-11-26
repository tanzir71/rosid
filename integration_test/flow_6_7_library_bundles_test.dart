import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rosid/app.dart';
import 'package:rosid/core/profile/app_profile.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/database/database_provider.dart';
import 'package:rosid/data/repositories/record_repository.dart';
import 'package:rosid/data/repositories/scan_repository.dart';
import 'package:rosid/export/paper_export_service.dart';
import 'package:rosid/features/library/library_search_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingFileService extends PlatformFileService {
  final List<({String name, List<int> bytes})> saved = [];

  @override
  Future<({bool saved, String? uri, String? displayName})> saveFileToPhone({
    required String sourcePath,
    required String suggestedName,
    required String mimeType,
  }) async {
    final bytes = await File(sourcePath).readAsBytes();
    saved.add((name: suggestedName, bytes: bytes));
    return (
      saved: true,
      uri: 'content://rosid.test/$suggestedName',
      displayName: suggestedName,
    );
  }
}

String _extractPdfText(List<int> pdfBytes) {
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

String _writeJpg(String name) {
  final dir = Directory.systemTemp.createTempSync('rosid_m7_');
  final im = img.Image(width: 500, height: 700);
  img.fill(im, color: img.ColorRgb8(245, 245, 240));
  img.fillRect(
    im,
    x1: 50,
    y1: 60,
    x2: 450,
    y2: 90,
    color: img.ColorRgb8(35, 35, 45),
  );
  final path = '${dir.path}/$name';
  File(path).writeAsBytesSync(img.encodeJpg(im, quality: 82));
  return path;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'M7 Search Benchmark: 500 generated papers search <= 150 ms on rosid_test',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final now = DateTime(2026, 11, 26);
      await db.transaction(() async {
        for (var i = 0; i < 500; i++) {
          final id = 'paper-$i';
          final isTarget = i == 247 || i == 412;
          final title = isTarget
              ? 'খতিয়ান নং $i, বিরুলিয়া'
              : 'কাগজপত্র নং $i, গাজীপুর';
          final body = isTarget
              ? 'মৌজা: বিরুলিয়া, মালিক: মোঃ আব্দুর রহমান, জমির পরিমাণ ১২.৫০ শতাংশ'
              : 'মৌজা: শ্রীপুর, দাগ নং $i, জমির পরিমাণ ৫.০০ শতাংশ';

          await db
              .into(db.scans)
              .insert(
                ScansCompanion.insert(
                  id: id,
                  type: 'document',
                  kind: const Value('land'),
                  imagePath: '/tmp/p$i.jpg',
                  ocrRawText: Value(body),
                  createdAt: now.subtract(Duration(hours: i)),
                  updatedAt: now.subtract(Duration(hours: i)),
                ),
              );
          await db
              .into(db.documents)
              .insert(
                DocumentsCompanion.insert(
                  id: 'doc-$i',
                  scanId: id,
                  title: title,
                  body: Value(body),
                ),
              );
          await db
              .into(db.textLines)
              .insert(
                TextLinesCompanion.insert(
                  id: 'ln-$i',
                  scanId: id,
                  pageIndex: 0,
                  lineOrder: 0,
                  textContent: body,
                ),
              );
          await db.indexScan(scanId: id, text: [title, body]);
        }
        await db
            .into(db.names)
            .insert(
              NamesCompanion.insert(
                id: 'nb-birulia',
                bangla: 'বিরুলিয়া',
                english: 'Birulia',
                category: const Value('place'),
                source: const Value('manual'),
                confirmed: const Value(true),
              ),
            );
      });

      final search = LibrarySearchService(db);
      // Warm up query plan once, then measure both Bangla & cross-script English searches.
      await search.search('গাজীপুর');

      final rBn = await search.search('বিরুলিয়া');
      final rEn = await search.search('Birulia');

      debugPrint(
        '[M7_SEARCH_BENCH_500] bn_hits=${rBn.paperCount} bn_ms=${rBn.elapsedMs} '
        'en_hits=${rEn.paperCount} en_ms=${rEn.elapsedMs}',
      );

      expect(rBn.paperCount, 2);
      expect(rEn.paperCount, 2);
      expect(rBn.elapsedMs, lessThanOrEqualTo(150));
      expect(rEn.elapsedMs, lessThanOrEqualTo(150));
    },
  );

  testWidgets(
    'Flows 6 & 7: Cross-script Library search + Student visa bundle checklist & PDF export under 2 MB',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'onboarding_complete': true,
        'language_code': 'en',
        'purposes': ['visa', 'land'],
      });
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final p1 = _writeJpg('passport.jpg');
      final p2 = _writeJpg('khatian.jpg');
      final scans = ScanRepository(db);
      final records = RecordRepository(db);

      await scans.createScan(
        id: 'f6-khatian',
        mode: ScanMode.document,
        imagePath: p2,
        langHint: 'bn',
        createdAt: DateTime(2026, 11, 26),
      );
      await (db.update(db.scans)..where((s) => s.id.equals('f6-khatian')))
          .write(const ScansCompanion(kind: Value('land')));
      await db
          .into(db.textLines)
          .insert(
            TextLinesCompanion.insert(
              id: 'f6-l0',
              scanId: 'f6-khatian',
              pageIndex: 0,
              lineOrder: 0,
              textContent: 'মৌজা: বিরুলিয়া, মালিক: মোঃ আব্দুর রহমান',
            ),
          );
      await records.saveDocument(
        scanId: 'f6-khatian',
        title: 'খতিয়ান, বিরুলিয়া',
        body: 'মৌজা: বিরুলিয়া, মালিক: মোঃ আব্দুর রহমান',
        tags: const [],
      );

      await scans.createScan(
        id: 'f7-passport',
        mode: ScanMode.document,
        imagePath: p1,
        langHint: 'en',
        createdAt: DateTime(2026, 11, 25),
      );
      await (db.update(db.scans)..where((s) => s.id.equals('f7-passport')))
          .write(const ScansCompanion(kind: Value('id')));
      await records.saveDocument(
        scanId: 'f7-passport',
        title: 'Passport',
        body: 'PASSPORT MD ABDUR RAHMAN',
        tags: const [],
      );

      await db
          .into(db.names)
          .insert(
            NamesCompanion.insert(
              id: 'f6-n1',
              bangla: 'বিরুলিয়া',
              english: 'Birulia',
              category: const Value('place'),
              source: const Value('manual'),
              confirmed: const Value(true),
            ),
          );

      final fileRecorder = _RecordingFileService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWithValue(db),
            platformFileServiceProvider.overrideWithValue(fileRecorder),
          ],
          child: const RosidApp(),
        ),
      );
      await tester.pumpAndSettle();

      // --- Flow 6: Library cross-script search ---
      await tester.tap(find.text('Library').last);
      await tester.pumpAndSettle();
      expect(find.text('খতিয়ান, বিরুলিয়া'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('library-search-field')),
        'বিরুলিয়া',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Found in 1 paper'), findsOneWidget);
      expect(find.text('খতিয়ান, বিরুলিয়া'), findsOneWidget);

      // Now search the English Name Book spelling (`Birulia`) -> must find the same Bangla paper!
      await tester.tap(find.byKey(const ValueKey('library-search-clear')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('library-search-field')),
        'Birulia',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Found in 1 paper'), findsOneWidget);
      expect(find.text('খতিয়ান, বিরুলিয়া'), findsOneWidget);

      // --- Flow 7: Make a bundle from Student visa checklist, attach 2 papers, export 1 PDF under 2 MB ---
      await tester.tap(find.text('Bundles').last);
      await tester.pumpAndSettle();
      final visaTpl = find.byKey(
        const ValueKey('bundle-template-student_visa'),
      );
      await tester.ensureVisible(visaTpl);
      await tester.pumpAndSettle();
      await tester.tap(visaTpl);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('new-bundle-confirm')));
      await tester.pumpAndSettle();

      // Attach paper 1 (`Passport`) to item 0 (`Passport`)
      await tester.tap(find.text('Passport').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('link-paper-f7-passport')));
      await tester.pumpAndSettle();

      // Attach paper 2 (`খতিয়ান, বিরুলিয়া`) to item 1 (`National ID, both sides`)
      await tester.tap(find.text('National ID, both sides').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('link-paper-f6-khatian')));
      await tester.pumpAndSettle();

      // Export bundle as one PDF under 2 MB
      await tester.tap(find.byKey(const ValueKey('bundle-export-button')));
      await tester.pumpAndSettle();
      expect(find.text('Export bundle'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('bundle-export-save')));
      await tester.pumpAndSettle(const Duration(seconds: 4));

      expect(fileRecorder.saved.length, 1);
      final pdfBytes = fileRecorder.saved.first.bytes;
      expect(pdfBytes.length, lessThanOrEqualTo(2 * 1024 * 1024));
      final pdfText = _extractPdfText(pdfBytes);
      expect(pdfText, contains('CONTENTS'));
      expect(pdfText, contains('01 Passport Page 2'));
      expect(pdfText, contains('02 National ID, both sides Page 3'));
    },
  );
}
