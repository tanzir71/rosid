import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rosid/translation/bangla_calendar.dart';
import 'package:rosid/translation/bangla_transliterator.dart';
import 'package:rosid/translation/draft_rules.dart';

/// M5 Rules Verification Tests (`handover/milestones/M5-english-draft.md`).
///
/// Published calendar sources verified for Bangladesh's revised Bangla calendar
/// (Bangla Academy 2019 reform, effective from 1426 BS / 14 April 2019):
/// - Bangla Academy 2019 revised calendar rules: 1 Boishakh = 14 April;
///   Boishakh–Ashwin = 31 days; Kartik–Magh = 30 days; Falgun = 29 days
///   (30 days in Gregorian leap years); Choitro = 30 days.
/// - Cross-checked against published online Bangladesh calendars:
///   * bangladatetoday.com (12 Falgun 1430 = 25 February 2024; 1 Boishakh 1431 = 14 April 2024; 1 Poush 1431 = 16 December 2024)
///   * ponjika.us & sattacademy.com (8 Falgun = 21 February Ekushey; 12 Choitro = 26 March Independence Day; 1 Poush = 16 December Victory Day)
void main() {
  group('BanglaCalendar (revised Bangladesh 2019 calendar)', () {
    // 14 verified date pairs across leap and non-leap years, national anchors,
    // year boundaries, and pre-2019 historical records.
    final verifiedPairs = <(int, int, int, DateTime, bool, String)>[
      // (banglaYear, banglaMonth, banglaDay, expectedGregorian, isApprox, note)
      (
        1426,
        1,
        1,
        DateTime.utc(2019, 4, 14),
        false,
        'Pohela Boishakh 1426 (reform start)',
      ),
      (1430, 1, 1, DateTime.utc(2023, 4, 14), false, 'Pohela Boishakh 1430'),
      (
        1430,
        9,
        1,
        DateTime.utc(2023, 12, 16),
        false,
        '1 Poush 1430 = Victory Day 2023',
      ),
      (
        1430,
        9,
        17,
        DateTime.utc(2024, 1, 1),
        false,
        '17 Poush 1430 = New Year 2024',
      ),
      (
        1430,
        11,
        8,
        DateTime.utc(2024, 2, 21),
        false,
        '8 Falgun 1430 = Ekushey Feb 2024',
      ),
      (
        1430,
        11,
        12,
        DateTime.utc(2024, 2, 25),
        false,
        '12 Falgun 1430 = 25 Feb 2024 (Figma)',
      ),
      (
        1430,
        11,
        29,
        DateTime.utc(2024, 3, 13),
        false,
        '29 Falgun 1430 (leap year 2024)',
      ),
      (
        1430,
        11,
        30,
        DateTime.utc(2024, 3, 14),
        false,
        '30 Falgun 1430 (leap day in 2024)',
      ),
      (
        1430,
        12,
        12,
        DateTime.utc(2024, 3, 26),
        false,
        '12 Choitro 1430 = Independence Day 2024',
      ),
      (
        1430,
        12,
        30,
        DateTime.utc(2024, 4, 13),
        false,
        'Choitro Songkranti 1430',
      ),
      (
        1431,
        1,
        1,
        DateTime.utc(2024, 4, 14),
        false,
        '1 Boishakh 1431 = 14 April 2024',
      ),
      (
        1431,
        9,
        1,
        DateTime.utc(2024, 12, 16),
        false,
        '1 Poush 1431 = 16 December 2024',
      ),
      (
        1431,
        11,
        29,
        DateTime.utc(2025, 3, 14),
        false,
        '29 Falgun 1431 (non-leap year 2025)',
      ),
      (
        1431,
        12,
        12,
        DateTime.utc(2025, 3, 26),
        false,
        '12 Choitro 1431 = Independence Day 2025',
      ),
      (
        1425,
        1,
        1,
        DateTime.utc(2018, 4, 14),
        true,
        'Pre-2019 date gets about prefix',
      ),
    ];

    test('converts all 15 verified Bangladesh Bangla calendar date pairs accurately', () {
      for (final (by, bm, bd, expected, approx, note) in verifiedPairs) {
        final got = BanglaCalendar.toGregorian(by, bm, bd);
        expect(got, expected, reason: note);
        expect(BanglaCalendar.isPre2019(got!), approx, reason: note);
      }
      // Non-leap Falgun 30 must be rejected as invalid.
      expect(BanglaCalendar.toGregorian(1431, 11, 30), isNull);
    });

    test('parses Bangla month names, তারিখ, pre-2019 about prefix, and Gregorian dates in Bangla digits', () {
      final m1 = BanglaCalendar.findBanglaDates('তারিখ: ১২ ফাল্গুন ১৪৩০');
      expect(m1, hasLength(1));
      expect(
        m1.first.formattedWithGregorian,
        '12 Falgun 1430 (25 February 2024)',
      );

      final mOld = BanglaCalendar.findBanglaDates(
        'তারিখ: ১ বৈশাখ ১৪২৫ বঙ্গাব্দ',
      );
      expect(mOld, hasLength(1));
      expect(
        mOld.first.formattedWithGregorian,
        '1 Boishakh 1425 (about 14 April 2018)',
      );

      final g1 = BanglaCalendar.findGregorianBanglaDates(
        'জন্ম তারিখ: ২৫/০২/২০২৪',
      );
      expect(g1, hasLength(1));
      expect(g1.first.formattedEnglish, '25 February 2024');

      final g2 = BanglaCalendar.findGregorianBanglaDates(
        'তারিখ: ১৫ আগস্ট ১৯৯৫',
      );
      expect(g2, hasLength(1));
      expect(g2.first.formattedEnglish, '15 August 1995');
    });
  });

  group('BanglaTransliterator', () {
    test('seeds at least 300 common Bangladeshi name and place parts', () {
      expect(
        BanglaTransliterator.commonNameParts.length,
        greaterThanOrEqualTo(300),
      );
    });

    test('transliterates common Bangladeshi names and places accurately', () {
      expect(
        BanglaTransliterator.transliterate('মোঃ আব্দুর রহমান'),
        'MD Abdur Rahman',
      );
      expect(BanglaTransliterator.transliterate('আব্দুল করিম'), 'Abdul Karim');
      expect(
        BanglaTransliterator.transliterate('ফারহানা রহমান'),
        'Farhana Rahman',
      );
      expect(BanglaTransliterator.transliterate('বিরুলিয়া'), 'Birulia');
      expect(BanglaTransliterator.transliterate('সাভার'), 'Savar');
      expect(BanglaTransliterator.transliterate('ঢাকা'), 'Dhaka');
    });

    test(
      'falls back cleanly to phonetic transliteration for unknown Bangla names',
      () {
        final out = BanglaTransliterator.transliterate('কালিকাপুর');
        expect(out, isNotEmpty);
        expect(RegExp(r'[\u0980-\u09FF]').hasMatch(out), isFalse);
        expect(out[0], out[0].toUpperCase());
      },
    );
  });

  group('assets/data/terms.json', () {
    test(
      'contains all 19 seeded terms from 01-product.md with valid fields',
      () {
        final raw = File('assets/data/terms.json').readAsStringSync();
        final list = jsonDecode(raw) as List<dynamic>;
        expect(list.length, 19);
        final ids = list.map((e) => (e as Map<String, dynamic>)['id']).toSet();
        expect(
          ids,
          containsAll([
            'khatian',
            'porcha',
            'dag_no',
            'mouza',
            'jl_no',
            'namjari',
            'dolil',
            'dakhila',
          ]),
        );
      },
    );
  });

  group('DraftRulesEngine', () {
    const engine = DraftRulesEngine();

    final sampleTerms = <TermRule>[
      const TermRule(
        id: 'khatian',
        bangla: 'খতিয়ান',
        transliteration: 'Khatian',
        english: 'Record of rights',
        both: 'Khatian (record of rights)',
        explanation: 'Government land record',
        chosenForm: TermForm.both,
      ),
      const TermRule(
        id: 'mouza',
        bangla: 'মৌজা',
        transliteration: 'Mouza',
        english: 'Revenue village',
        both: 'Mouza',
        explanation: 'Revenue village',
        chosenForm: TermForm.both,
      ),
      const TermRule(
        id: 'jl_no',
        bangla: 'জে.এল. নং',
        transliteration: 'J.L. No.',
        english: 'Jurisdiction list No.',
        both: 'J.L. No.',
        explanation: 'Jurisdiction list number',
        chosenForm: TermForm.both,
      ),
      const TermRule(
        id: 'mrito',
        bangla: 'মৃত',
        transliteration: 'Mrito',
        english: 'Late',
        both: 'Late',
        explanation: 'Before a deceased person name',
        chosenForm: TermForm.both,
      ),
    ];

    final sampleNames = <NameBookRule>[
      const NameBookRule(
        id: 'n1',
        bangla: 'মোঃ আব্দুর রহমান',
        english: 'MD ABDUR RAHMAN',
        category: 'person',
        source: 'passport',
        confirmed: true,
      ),
    ];

    test('produces exact Figma draft lines for land record fields', () {
      final cases = <(String, String)>[
        ('খতিয়ান নং ১২৪৫', 'Khatian (record of rights) No. 1245'),
        ('জেলা: ঢাকা, উপজেলা: সাভার', 'District: Dhaka. Upazila: Savar'),
        ('মৌজা: বিরুলিয়া, জে.এল. নং: ৩৫', 'Mouza: Birulia. J.L. No. 35'),
        ('মালিকের নাম: মোঃ আব্দুর রহমান', 'Owner: MD ABDUR RAHMAN'),
        ('পিতা: মৃত আব্দুল করিম', 'Father: Late Abdul Karim'),
        (
          'জমির পরিমাণ: ১২.৫০ শতাংশ',
          'Area: 12.50 decimals (about 5,445 sq ft)',
        ),
        ('তারিখ: ১২ ফাল্গুন ১৪৩০', 'Date: 12 Falgun 1430 (25 February 2024)'),
      ];

      for (final (bn, expectedEn) in cases) {
        final prep = engine.prepareLine(
          bn,
          names: sampleNames,
          terms: sampleTerms,
        );
        final res = engine.finalizeLine(prep);
        expect(res.englishDraft, expectedEn, reason: 'Line: $bn');
      }
    });

    test('applies chosen term form (both / english / bangla)', () {
      for (final (form, expected) in [
        (TermForm.both, 'Khatian (record of rights) No. 1245'),
        (TermForm.english, 'Record of rights No. 1245'),
        (TermForm.bangla, 'Khatian No. 1245'),
      ]) {
        final t = [
          TermRule(
            id: 'khatian',
            bangla: 'খতিয়ান',
            transliteration: 'Khatian',
            english: 'Record of rights',
            both: 'Khatian (record of rights)',
            explanation: 'Government land record',
            chosenForm: form,
          ),
        ];
        final prep = engine.prepareLine(
          'খতিয়ান নং ১২৪৫',
          names: const [],
          terms: t,
        );
        expect(engine.finalizeLine(prep).englishDraft, expected);
      }
    });

    test(
      'distinguishes verified name book matches from new suggested names',
      () {
        final ownerPrep = engine.prepareLine(
          'মালিকের নাম: মোঃ আব্দুর রহমান',
          names: sampleNames,
          terms: sampleTerms,
        );
        expect(ownerPrep.nameMarks, hasLength(1));
        expect(ownerPrep.nameMarks.first.status, DraftNameStatus.fromNameBook);

        final fatherPrep = engine.prepareLine(
          'পিতা: মৃত আব্দুল করিম',
          names: sampleNames,
          terms: sampleTerms,
        );
        expect(fatherPrep.nameMarks, hasLength(1));
        expect(fatherPrep.nameMarks.first.status, DraftNameStatus.newNameCheck);
        expect(fatherPrep.nameMarks.first.english, 'Abdul Karim');
      },
    );

    test('preserves 100% of numbers, dates, and passport names through model placeholder round-trip', () {
      const sentence =
          'এই মর্মে প্রত্যয়ন করা যাচ্ছে যে মোঃ আব্দুর রহমান ১২ ফাল্গুন ১৪৩০ তারিখে ১২.৫০ শতাংশ জমির খতিয়ান নং ১২৪৫ দাখিল করেছেন।';
      final prep = engine.prepareLine(
        sentence,
        names: sampleNames,
        terms: sampleTerms,
      );
      expect(prep.hasFreeTextForModel, isTrue);
      // Simulate a neural model output that lowercased one placeholder token and kept others.
      final simulatedNmt =
          'It is hereby certified that ${prep.placeholders.keys.join(" ")} has been submitted.';
      final res = engine.finalizeLine(prep, modelOutput: simulatedNmt);
      expect(res.englishDraft, contains('MD ABDUR RAHMAN'));
      expect(res.englishDraft, contains('12 Falgun 1430 (25 February 2024)'));
      expect(res.englishDraft, contains('12.50 decimals (about 5,445 sq ft)'));
      expect(res.englishDraft, contains('Khatian (record of rights)'));
      expect(res.englishDraft, contains('1245'));
    });
  });
}
