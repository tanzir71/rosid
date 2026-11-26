import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rosid/app.dart';
import 'package:rosid/core/profile/app_profile.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/database/database_provider.dart';
import 'package:rosid/data/repositories/record_repository.dart';
import 'package:rosid/data/repositories/scan_repository.dart';
import 'package:rosid/translation/draft_rules.dart';
import 'package:rosid/translation/translation_engine.dart';
import 'package:rosid/translation/translation_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Standard Popović (2015) chrF score (character 1..6-gram F-score, beta=2).
double computeChrF(List<String> hypotheses, List<String> references) {
  const maxN = 6;
  const beta2 = 4.0; // beta = 2 -> beta^2 = 4
  var totalPrec = 0.0;
  var totalRec = 0.0;
  var orders = 0;

  for (var n = 1; n <= maxN; n++) {
    var matched = 0;
    var hypTotal = 0;
    var refTotal = 0;

    for (var i = 0; i < hypotheses.length; i++) {
      final h = hypotheses[i].replaceAll(RegExp(r'\s+'), ' ').trim();
      final r = references[i].replaceAll(RegExp(r'\s+'), ' ').trim();
      if (h.length < n || r.length < n) continue;

      final hCounts = <String, int>{};
      for (var j = 0; j <= h.length - n; j++) {
        final g = h.substring(j, j + n);
        hCounts[g] = (hCounts[g] ?? 0) + 1;
      }
      final rCounts = <String, int>{};
      for (var j = 0; j <= r.length - n; j++) {
        final g = r.substring(j, j + n);
        rCounts[g] = (rCounts[g] ?? 0) + 1;
      }

      hypTotal += h.length - n + 1;
      refTotal += r.length - n + 1;
      for (final entry in hCounts.entries) {
        final rc = rCounts[entry.key] ?? 0;
        matched += entry.value < rc ? entry.value : rc;
      }
    }

    if (hypTotal > 0 && refTotal > 0) {
      totalPrec += matched / hypTotal;
      totalRec += matched / refTotal;
      orders++;
    }
  }

  if (orders == 0) return 0;
  final avgP = totalPrec / orders;
  final avgR = totalRec / orders;
  if (avgP + avgR == 0) return 0;
  return 100.0 * (1 + beta2) * avgP * avgR / (beta2 * avgP + avgR);
}

const _gate40Json = r'''
[
  {"page": 1, "bn": "খতিয়ান নং ১২৪৫", "ref": "Khatian (record of rights) No. 1245", "mustKeep": ["1245"]},
  {"page": 1, "bn": "জেলা: ঢাকা, উপজেলা: সাভার", "ref": "District: Dhaka. Upazila: Savar", "mustKeep": ["Dhaka", "Savar"]},
  {"page": 1, "bn": "মৌজা: বিরুলিয়া, জে.এল. নং: ৩৫", "ref": "Mouza: Birulia. J.L. No. 35", "mustKeep": ["Birulia", "35"]},
  {"page": 1, "bn": "মালিকের নাম: মোঃ আব্দুর রহমান", "ref": "Owner: MD ABDUR RAHMAN", "mustKeep": ["MD ABDUR RAHMAN"]},
  {"page": 1, "bn": "পিতা: মৃত আব্দুল করিম", "ref": "Father: Late Abdul Karim", "mustKeep": ["Abdul Karim"]},
  {"page": 1, "bn": "দাগ নং: ৩০২", "ref": "Plot (Dag) No. 302", "mustKeep": ["302"]},
  {"page": 1, "bn": "জমির পরিমাণ: ১২.৫০ শতাংশ", "ref": "Area: 12.50 decimals (about 5,445 sq ft)", "mustKeep": ["12.50", "5,445"]},
  {"page": 1, "bn": "তারিখ: ১২ ফাল্গুন ১৪৩০", "ref": "Date: 12 Falgun 1430 (25 February 2024)", "mustKeep": ["12 Falgun 1430", "25 February 2024"]},

  {"page": 2, "bn": "গণপ্রজাতন্ত্রী বাংলাদেশ সরকার", "ref": "Government of the People's Republic of Bangladesh", "mustKeep": ["Bangladesh"]},
  {"page": 2, "bn": "ভূমি উন্নয়ন কর দাখিলা", "ref": "Land development tax receipt (dakhila)", "mustKeep": ["Land development tax"]},
  {"page": 2, "bn": "খতিয়ান নং ৩৮৯০", "ref": "Khatian (record of rights) No. 3890", "mustKeep": ["3890"]},
  {"page": 2, "bn": "মৌজা: আশুলিয়া, জে.এল. নং: ৪২", "ref": "Mouza: Ashulia. J.L. No. 42", "mustKeep": ["Ashulia", "42"]},
  {"page": 2, "bn": "মালিকের নাম: ফারহানা রহমান", "ref": "Owner: FARHANA RAHMAN", "mustKeep": ["FARHANA RAHMAN"]},
  {"page": 2, "bn": "জমির পরিমাণ: ৮.২৫ শতাংশ", "ref": "Area: 8.25 decimals (about 3,593.7 sq ft)", "mustKeep": ["8.25"]},
  {"page": 2, "bn": "তারিখ: ১ বৈশাখ ১৪৩১", "ref": "Date: 1 Boishakh 1431 (14 April 2024)", "mustKeep": ["1 Boishakh 1431", "14 April 2024"]},
  {"page": 2, "bn": "উক্ত জমির ২০২৪ সালের খাজনা বাবদ ৫৫০ টাকা পরিশোধ করা হয়েছে।", "ref": "An amount of 550 taka has been paid as land tax for 2024 for the said land.", "mustKeep": ["2024", "550"]},

  {"page": 3, "bn": "জন্ম নিবন্ধন সনদ", "ref": "Birth registration certificate", "mustKeep": ["Birth registration certificate"]},
  {"page": 3, "bn": "নিবন্ধন নং: ১৯৯৫২৬১৭৯০১২৩৪৫৬৭", "ref": "Registration No.: 19952617901234567", "mustKeep": ["19952617901234567"]},
  {"page": 3, "bn": "নাম: ফারহানা রহমান", "ref": "Name: FARHANA RAHMAN", "mustKeep": ["FARHANA RAHMAN"]},
  {"page": 3, "bn": "পিতা: মোঃ আব্দুর রহমান", "ref": "Father: MD ABDUR RAHMAN", "mustKeep": ["MD ABDUR RAHMAN"]},
  {"page": 3, "bn": "মাতা: রোকেয়া বেগম", "ref": "Mother: ROKEYA BEGUM", "mustKeep": ["ROKEYA BEGUM"]},
  {"page": 3, "bn": "জন্ম তারিখ: ১৫/০৮/১৯৯৫", "ref": "Date of birth: 15 August 1995", "mustKeep": ["15 August 1995"]},
  {"page": 3, "bn": "এই মর্মে প্রত্যয়ন করা যাচ্ছে যে আবেদনকারী বাংলাদেশের স্থায়ী নাগরিক।", "ref": "It is hereby certified that the applicant is a permanent citizen of Bangladesh.", "mustKeep": ["Bangladesh"]},
  {"page": 3, "bn": "ইস্যু তারিখ: ১০/০৩/২০২৪", "ref": "Issue date: 10 March 2024", "mustKeep": ["10 March 2024"]},

  {"page": 4, "bn": "ওয়ারিশ সনদ", "ref": "Succession (warish) certificate", "mustKeep": ["Succession"]},
  {"page": 4, "bn": "স্মারক নং: ২০২৪/০৮৭", "ref": "Memo No.: 2024/087", "mustKeep": ["2024/087"]},
  {"page": 4, "bn": "জেলা: গাজীপুর, উপজেলা: শ্রীপুর", "ref": "District: Gazipur. Upazila: Sreepur", "mustKeep": ["Gazipur", "Sreepur"]},
  {"page": 4, "bn": "মৃত আব্দুল করিম অত্র ইউনিয়নের একজন স্থায়ী বাসিন্দা ছিলেন।", "ref": "Late Abdul Karim was a permanent resident of this union.", "mustKeep": ["Late"]},
  {"page": 4, "bn": "তিনি ১২/০১/২০২২ তারিখে মৃত্যুবরণ করেন এবং তাঁর মোট ৩ জন ওয়ারিশ রেখে যান।", "ref": "He passed away on 12 January 2022 leaving behind 3 legal heirs.", "mustKeep": ["12 January 2022", "3"]},
  {"page": 4, "bn": "উক্ত ওয়ারিশগণ আইন অনুযায়ী সম্পত্তির সমান অংশীদার হবেন।", "ref": "The said heirs shall be equal inheritors of the property according to law.", "mustKeep": []},
  {"page": 4, "bn": "তারিখ: ৮ ফাল্গুন ১৪৩০", "ref": "Date: 8 Falgun 1430 (21 February 2024)", "mustKeep": ["8 Falgun 1430", "21 February 2024"]},
  {"page": 4, "bn": "ইউনিয়ন পরিষদ চেয়ারম্যানের স্বাক্ষর ও সিলমোহর দ্বারা সত্যায়িত।", "ref": "Attested by the signature and seal of the Union Parishad Chairman.", "mustKeep": []},

  {"page": 5, "bn": "দলিল নং: ৭৬৫৪", "ref": "Deed No.: 7654", "mustKeep": ["7654"]},
  {"page": 5, "bn": "জেলা: নারায়ণগঞ্জ, উপজেলা: রূপগঞ্জ", "ref": "District: Narayanganj. Upazila: Rupganj", "mustKeep": ["Narayanganj", "Rupganj"]},
  {"page": 5, "bn": "দাগ নং: ৫১২", "ref": "Plot (Dag) No. 512", "mustKeep": ["512"]},
  {"page": 5, "bn": "জমির পরিমাণ: ৫.০০ কাঠা", "ref": "Area: 5 katha (8.26 decimals, about 3,600 sq ft)", "mustKeep": ["5", "8.26", "3,600"]},
  {"page": 5, "bn": "বিক্রেতা মোঃ আব্দুর রহমান ক্রেতা ফারহানা রহমান বরাবর উক্ত জমি বিক্রয় করিলেন।", "ref": "The seller MD ABDUR RAHMAN sold the said land to the buyer FARHANA RAHMAN.", "mustKeep": ["MD ABDUR RAHMAN", "FARHANA RAHMAN"]},
  {"page": 5, "bn": "উক্ত জমি পৈতৃক সূত্রে প্রাপ্ত এবং বর্তমানে মালিকের দখলে আছে।", "ref": "The said land was inherited and is currently in possession of the owner.", "mustKeep": []},
  {"page": 5, "bn": "সরকারি ভূমি অফিস হতে এই পর্চা প্রদান করা হলো।", "ref": "This certified copy was issued from the government land office.", "mustKeep": []},
  {"page": 5, "bn": "তারিখ: ১ পৌষ ১৪৩১", "ref": "Date: 1 Poush 1431 (16 December 2024)", "mustKeep": ["1 Poush 1431", "16 December 2024"]}
]
''';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'M5 Gate: Integration A (WebView + Bergamot WASM) on 40 land & certificate lines',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final engine = WebViewBergamotEngine();
      final repo = TranslationRepository(db, engine);
      addTearDown(() async {
        await engine.release();
        await db.close();
      });

      await repo.upsertName(
        bangla: 'মোঃ আব্দুর রহমান',
        english: 'MD ABDUR RAHMAN',
        category: 'person',
        source: 'passport',
      );
      await repo.upsertName(
        bangla: 'ফারহানা রহমান',
        english: 'FARHANA RAHMAN',
        category: 'person',
        source: 'passport',
      );
      await repo.upsertName(
        bangla: 'রোকেয়া বেগম',
        english: 'ROKEYA BEGUM',
        category: 'person',
        source: 'nid',
      );

      final terms = await repo.loadTerms();
      final names = await repo.loadNames();
      const rules = DraftRulesEngine();

      final warmSw = Stopwatch()..start();
      await engine.warmUp();
      warmSw.stop();
      debugPrint('M5_GATE_WARMUP_MS=${warmSw.elapsedMilliseconds}');

      final rows = (jsonDecode(_gate40Json) as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(rows.length, 40);

      final byPage = <int, List<Map<String, dynamic>>>{};
      for (final r in rows) {
        byPage.putIfAbsent(r['page'] as int, () => []).add(r);
      }

      final pageMs = <int>[];
      final allHyps = <String>[];
      final allRefs = <String>[];
      var totalRequired = 0;
      var preservedRequired = 0;
      var modelTranslatedLines = 0;

      for (final pageNo in byPage.keys.toList()..sort()) {
        final pageRows = byPage[pageNo]!;
        final sw = Stopwatch()..start();

        final prepared = <PreparedLine>[];
        final freeIdx = <int>[];
        final freeInputs = <String>[];
        for (var i = 0; i < pageRows.length; i++) {
          final p = rules.prepareLine(
            pageRows[i]['bn'] as String,
            names: names,
            terms: terms,
          );
          prepared.add(p);
          if (p.hasFreeTextForModel) {
            freeIdx.add(i);
            freeInputs.add(p.maskedForModel);
          }
        }

        final outputs = freeInputs.isEmpty
            ? const <String>[]
            : await engine.translateBatch(freeInputs);
        final outMap = <int, String>{};
        for (var k = 0; k < freeIdx.length; k++) {
          if (k < outputs.length && outputs[k].trim().isNotEmpty) {
            outMap[freeIdx[k]] = outputs[k];
            modelTranslatedLines++;
          }
        }

        for (var i = 0; i < pageRows.length; i++) {
          final res = rules.finalizeLine(prepared[i], modelOutput: outMap[i]);
          allHyps.add(res.englishDraft);
          allRefs.add(pageRows[i]['ref'] as String);

          final mustKeep = (pageRows[i]['mustKeep'] as List<dynamic>)
              .cast<String>();
          for (final token in mustKeep) {
            totalRequired++;
            if (res.englishDraft.contains(token)) {
              preservedRequired++;
            } else {
              debugPrint('MISSING TOKEN "$token" in: ${res.englishDraft}');
            }
          }
        }
        sw.stop();
        pageMs.add(sw.elapsedMilliseconds);
        debugPrint('M5_GATE_PAGE_${pageNo}_MS=${sw.elapsedMilliseconds}');
      }

      final sortedMs = List<int>.from(pageMs)..sort();
      final medianMs = sortedMs[sortedMs.length ~/ 2];
      final chrf = computeChrF(allHyps, allRefs);

      debugPrint(
        'M5_GATE_SUMMARY: lines=40 modelLines=$modelTranslatedLines '
        'preserved=$preservedRequired/$totalRequired '
        'medianPageMs=$medianMs chrf=${chrf.toStringAsFixed(2)}',
      );

      // Must actually run the neural model on free-text Bangla lines!
      expect(modelTranslatedLines, greaterThanOrEqualTo(6));
      // M5 Gate: 100% preservation of every number, date and name placeholder.
      expect(preservedRequired, totalRequired);
      // M5 Gate: median time per page <= 8 s on rosid_test.
      expect(medianMs, lessThanOrEqualTo(8000));
    },
  );

  testWidgets(
    'Flow 4 (up to export): English draft, name spelling, term choice, line edit',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'onboarding_complete': true,
        'language_code': 'en',
        'purposes': ['land', 'visa'],
      });
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final scans = ScanRepository(db);
      final records = RecordRepository(db);
      await scans.createScan(
        id: 'flow4-khatian',
        mode: ScanMode.document,
        imagePath: '/sample/khatian.jpg',
        langHint: 'bn',
        createdAt: DateTime.now(),
      );
      await (db.update(db.scans)..where((s) => s.id.equals('flow4-khatian')))
          .write(const ScansCompanion(kind: Value('land')));
      const lines = [
        ('f4-0', 'খতিয়ান নং ১২৪৫'),
        ('f4-1', 'জেলা: ঢাকা, উপজেলা: সাভার'),
        ('f4-2', 'মালিকের নাম: মোঃ আব্দুর রহমান'),
        ('f4-3', 'পিতা: মৃত আব্দুল করিম'),
        ('f4-4', 'জমির পরিমাণ: ১২.৫০ শতাংশ'),
        ('f4-5', 'তারিখ: ১২ ফাল্গুন ১৪৩০'),
        ('f4-6', 'সরকারি ভূমি অফিস হতে এই পর্চা প্রদান করা হলো।'),
      ];
      for (var i = 0; i < lines.length; i++) {
        await db
            .into(db.textLines)
            .insert(
              TextLinesCompanion.insert(
                id: lines[i].$1,
                scanId: 'flow4-khatian',
                pageIndex: 0,
                lineOrder: i,
                textContent: lines[i].$2,
              ),
            );
      }
      await records.saveDocument(
        scanId: 'flow4-khatian',
        title: 'খতিয়ান, বিরুলিয়া',
        body: lines.map((e) => e.$2).join('\n'),
        tags: const [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWithValue(db),
          ],
          child: const RosidApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Open the land record from Home's Recent list (`.last` skips Resume card title).
      final paperFinder = find.text('খতিয়ান, বিরুলিয়া').last;
      expect(paperFinder, findsOneWidget);
      await tester.ensureVisible(paperFinder);
      await tester.pumpAndSettle();
      await tester.tap(paperFinder);
      await tester.pumpAndSettle();

      // Switch to English tab and wait for on-device Bergamot WASM draft.
      expect(find.text('English'), findsOneWidget);
      await tester.tap(find.text('English'));
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find
            .byKey(const ValueKey('english-draft-stamp'))
            .evaluate()
            .isNotEmpty) {
          break;
        }
      }
      await tester.pumpAndSettle();

      // Verify DRAFT stamp, disclaimer banner, and key translated fields.
      expect(find.byKey(const ValueKey('english-draft-stamp')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('english-draft-banner')),
        findsOneWidget,
      );
      expect(find.textContaining('No. 1245'), findsOneWidget);
      expect(
        find.textContaining('12.50 decimals (about 5,445 sq ft)'),
        findsOneWidget,
      );
      expect(
        find.textContaining('12 Falgun 1430 (25 February 2024)'),
        findsOneWidget,
      );

      // 1. Set a passport name spelling via Name Book (`Names` bottom bar action).
      await tester.tap(find.byKey(const ValueKey('english-action-names')));
      await tester.pumpAndSettle();
      expect(find.text('Names'), findsOneWidget);
      // Tap the auto-suggested `MD Abdur Rahman` row and confirm as passport spelling.
      await tester.tap(find.text('MD Abdur Rahman').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('name-editor-english')),
        'MD ABDUR RAHMAN',
      );
      await tester.tap(find.byKey(const ValueKey('name-src-passport')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('name-editor-save')));
      await tester.pumpAndSettle();
      expect(find.text('MD ABDUR RAHMAN'), findsOneWidget);

      // Navigate back to English draft and wait for refreshed draft.
      await tester.tap(find.byKey(const ValueKey('rosid-top-bar-back')).last);
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.text('Owner: MD ABDUR RAHMAN').evaluate().isNotEmpty) {
          break;
        }
      }
      await tester.pumpAndSettle();
      expect(find.text('Owner: MD ABDUR RAHMAN'), findsOneWidget);
      expect(find.text('Spelling from your name book'), findsOneWidget);

      // 2. Change a term choice via Terms picker -> Help with a term sheet.
      await tester.tap(find.byKey(const ValueKey('english-action-terms')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('terms-picker-row-khatian')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('term-help-sheet')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('term-choice-english')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('term-help-use-this')));
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.text('Record of rights No. 1245').evaluate().isNotEmpty) {
          break;
        }
      }
      await tester.pumpAndSettle();
      expect(find.text('Record of rights No. 1245'), findsOneWidget);

      // 3. Edit an English line and verify edit persists.
      await tester.tap(find.byKey(const ValueKey('english-action-edit')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('edit-draft-line-1')),
        'District: Dhaka, Upazila: Savar (Verified)',
      );
      await tester.tap(find.byKey(const ValueKey('draft-editor-save')));
      await tester.pumpAndSettle();
      expect(
        find.text('District: Dhaka, Upazila: Savar (Verified)'),
        findsOneWidget,
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
    },
  );
}
