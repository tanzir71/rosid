import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
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
import 'package:shared_preferences/shared_preferences.dart';

/// Captures temp files passed to Android's SAF save dialog without blocking on
/// the external system picker UI (`handover/03-verification.md` line 105).
class _RecordingPlatformFileService extends PlatformFileService {
  final List<({String path, String name, String mime, List<int> bytes})> saved =
      [];

  @override
  Future<({bool saved, String? uri, String? displayName})> saveFileToPhone({
    required String sourcePath,
    required String suggestedName,
    required String mimeType,
  }) async {
    final file = File(sourcePath);
    final bytes = file.existsSync() ? await file.readAsBytes() : <int>[];
    saved.add((
      path: sourcePath,
      name: suggestedName,
      mime: mimeType,
      bytes: bytes,
    ));
    return (
      saved: true,
      uri: 'content://rosid.test/$suggestedName',
      displayName: suggestedName,
    );
  }
}

Future<String> _writeTempScanJpg(String name) async {
  final dir = Directory.systemTemp.createTempSync('rosid_flow5_');
  final im = img.Image(width: 600, height: 800);
  img.fill(im, color: img.ColorRgb8(248, 248, 244));
  img.fillRect(
    im,
    x1: 60,
    y1: 80,
    x2: 540,
    y2: 110,
    color: img.ColorRgb8(30, 30, 38),
  );
  final path = '${dir.path}/$name';
  File(path).writeAsBytesSync(img.encodeJpg(im, quality: 85));
  return path;
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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Flows 3, 4 & 5 export completion: ID one-page PDF, PDF with translator page, Word (.docx) unzip check, and Plain text (.txt)',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'onboarding_complete': true,
        'language_code': 'en',
        'purposes': ['land', 'visa'],
      });
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final scanPath = await _writeTempScanJpg('khatian.jpg');
      final idPath = await _writeTempScanJpg('nid_a4.jpg');
      final scans = ScanRepository(db);
      final records = RecordRepository(db);

      await scans.createScan(
        id: 'flow5-land',
        mode: ScanMode.document,
        imagePath: scanPath,
        langHint: 'bn',
        createdAt: DateTime.now(),
      );
      await (db.update(db.scans)..where((s) => s.id.equals('flow5-land')))
          .write(const ScansCompanion(kind: Value('land')));
      const lines = [
        ('f5-0', 'খতিয়ান নং ১২৪৫'),
        ('f5-1', 'জেলা: ঢাকা, উপজেলা: সাভার'),
        ('f5-2', 'মালিকের নাম: মোঃ আব্দুর রহমান'),
        ('f5-3', 'জমির পরিমাণ: ১২.৫০ শতাংশ'),
      ];
      for (var i = 0; i < lines.length; i++) {
        await db
            .into(db.textLines)
            .insert(
              TextLinesCompanion.insert(
                id: lines[i].$1,
                scanId: 'flow5-land',
                pageIndex: 0,
                lineOrder: i,
                textContent: lines[i].$2,
              ),
            );
      }
      await records.saveDocument(
        scanId: 'flow5-land',
        title: 'খতিয়ান, বিরুলিয়া',
        body: lines.map((e) => e.$2).join('\n'),
        tags: const [],
      );

      // Seed an ID card paper too for Flow 3 export part.
      await scans.createScan(
        id: 'flow3-id',
        mode: ScanMode.document,
        imagePath: idPath,
        langHint: 'en',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      await (db.update(db.scans)..where((s) => s.id.equals('flow3-id'))).write(
        const ScansCompanion(kind: Value('id')),
      );
      await records.saveDocument(
        scanId: 'flow3-id',
        title: 'National ID',
        body: 'National ID Card',
        tags: const [],
      );

      final recorder = _RecordingPlatformFileService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWithValue(db),
            platformFileServiceProvider.overrideWithValue(recorder),
          ],
          child: const RosidApp(),
        ),
      );
      await tester.pumpAndSettle();

      // --- Flow 4 export completion: open land record -> Export -> PDF with translator page ---
      final landFinder = find.text('খতিয়ান, বিরুলিয়া').last;
      await tester.ensureVisible(landFinder);
      await tester.pumpAndSettle();
      await tester.tap(landFinder);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('paper-action-export')));
      await tester.pumpAndSettle();
      expect(find.text('Export'), findsOneWidget);

      // Preview screen first
      await tester.tap(find.byKey(const ValueKey('export-preview-button')));
      await tester.pumpAndSettle();
      expect(find.text('Next, get it certified'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('rosid-top-bar-back')).last);
      await tester.pumpAndSettle();

      // Save PDF with translator's page (enabled by default).
      await tester.tap(find.byKey(const ValueKey('export-save-button')));
      await tester.pumpAndSettle(const Duration(seconds: 4));
      expect(find.byKey(const ValueKey('export-saved-stamp')), findsOneWidget);
      expect(recorder.saved.length, 1);
      final pdfRaw = latin1.decode(recorder.saved[0].bytes, allowInvalid: true);
      final pdfText = _extractPdfText(recorder.saved[0].bytes);
      expect(pdfRaw.startsWith('%PDF-'), isTrue);
      expect(pdfText, contains('DRAFT TRANSLATION'));
      expect(pdfText, contains("Translator's Certification"));

      // Return to paper -> Export again as Word (.docx) (Flow 5 part 1).
      await tester.tap(find.byKey(const ValueKey('saved-done')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('paper-action-export')));
      await tester.pumpAndSettle();
      // Enable Bangla text + select Word (.docx).
      await tester.tap(find.byKey(const ValueKey('export-inc-bangla')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('export-type-docx')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('export-save-button')));
      await tester.pumpAndSettle(const Duration(seconds: 4));
      expect(recorder.saved.length, 2);
      final docxBytes = recorder.saved[1].bytes;
      final archive = ZipDecoder().decodeBytes(docxBytes);
      final docEntry = archive.firstWhere((f) => f.name == 'word/document.xml');
      final docXml = utf8.decode(docEntry.content as List<int>);
      expect(docXml, contains('খতিয়ান নং ১২৪৫'));
      expect(docXml, contains('Khatian (record of rights) No. 1245'));
      expect(docXml, contains('w:cs="Nirmala UI"'));

      // Return to paper -> Export as Plain text (.txt) (Flow 5 part 2).
      await tester.tap(find.byKey(const ValueKey('saved-done')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('paper-action-export')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('export-type-txt')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('export-save-button')));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(recorder.saved.length, 3);
      final txt = utf8.decode(recorder.saved[2].bytes);
      expect(txt, contains('DRAFT TRANSLATION'));
      expect(txt, contains('খতিয়ান নং ১২৪৫'));
      expect(txt, contains('Khatian (record of rights) No. 1245'));

      // Return home -> Open ID card -> Export one-page PDF (Flow 3 export completion).
      await tester.tap(find.byKey(const ValueKey('saved-done')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('rosid-top-bar-back')).last);
      await tester.pumpAndSettle();
      final idFinder = find.text('National ID').last;
      await tester.ensureVisible(idFinder);
      await tester.pumpAndSettle();
      await tester.tap(idFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('paper-action-export')));
      await tester.pumpAndSettle();
      expect(find.text('National ID, both sides'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('id-export-submit')));
      await tester.pumpAndSettle(const Duration(seconds: 4));
      expect(recorder.saved.length, 4);
      final idPdfRaw = latin1.decode(
        recorder.saved[3].bytes,
        allowInvalid: true,
      );
      final idPdfText = _extractPdfText(recorder.saved[3].bytes);
      expect(idPdfRaw.startsWith('%PDF-'), isTrue);
      expect(idPdfText, contains('For visa application only'));
    },
  );
}
