import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rosid/core/l10n/app_localizations.dart';
import 'package:rosid/core/profile/app_profile.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/core/theme/app_theme.dart';
import 'package:rosid/core/widgets/rosid_navigation.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/database/database_provider.dart';
import 'package:rosid/data/repositories/record_repository.dart';
import 'package:rosid/data/repositories/scan_repository.dart';
import 'package:rosid/features/paper/paper_screen.dart';
import 'package:rosid/features/translation/name_book_screen.dart';
import 'package:rosid/features/translation/term_help_sheet.dart';
import 'package:rosid/translation/draft_rules.dart';
import 'package:rosid/translation/translation_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/golden_fonts.dart';

const _khatianTerm = TermRule(
  id: 'khatian',
  bangla: 'খতিয়ান',
  transliteration: 'Khatian',
  english: 'Record of rights',
  both: 'Khatian (record of rights)',
  explanation: 'The government record that shows who owns a piece of land, with its plot numbers and area. In English it is often called a record of rights.',
  chosenForm: TermForm.both,
);

final _sampleDraftLines = <DraftLineView>[
  const DraftLineView(
    translationId: 't-0',
    lineOrder: 0,
    sourceText: 'খতিয়ান নং ১২৪৫',
    englishText: 'Khatian (record of rights) No. 1245',
    edited: false,
    nameMarks: [],
    termMentions: [
      DraftTermMention(
        termId: 'khatian',
        renderedText: 'Khatian (record of rights)',
      ),
    ],
  ),
  const DraftLineView(
    translationId: 't-1',
    lineOrder: 1,
    sourceText: 'জেলা: ঢাকা, উপজেলা: সাভার',
    englishText: 'District: Dhaka. Upazila: Savar',
    edited: false,
    nameMarks: [],
    termMentions: [],
  ),
  const DraftLineView(
    translationId: 't-2',
    lineOrder: 2,
    sourceText: 'মৌজা: বিরুলিয়া, জে.এল. নং: ৩৫',
    englishText: 'Mouza: Birulia. J.L. No. 35',
    edited: false,
    nameMarks: [],
    termMentions: [],
  ),
  const DraftLineView(
    translationId: 't-3',
    lineOrder: 3,
    sourceText: 'মালিকের নাম: মোঃ আব্দুর রহমান',
    englishText: 'Owner: MD ABDUR RAHMAN',
    edited: false,
    nameMarks: [
      DraftNameMark(
        bangla: 'মোঃ আব্দুর রহমান',
        english: 'MD ABDUR RAHMAN',
        category: 'person',
        status: DraftNameStatus.fromNameBook,
      ),
    ],
    termMentions: [],
  ),
  const DraftLineView(
    translationId: 't-4',
    lineOrder: 4,
    sourceText: 'পিতা: মৃত আব্দুল করিম',
    englishText: 'Father: Late Abdul Karim',
    edited: false,
    nameMarks: [
      DraftNameMark(
        bangla: 'আব্দুল করিম',
        english: 'Abdul Karim',
        category: 'person',
        status: DraftNameStatus.newNameCheck,
      ),
    ],
    termMentions: [],
  ),
  const DraftLineView(
    translationId: 't-5',
    lineOrder: 5,
    sourceText: 'জমির পরিমাণ: ১২.৫০ শতাংশ',
    englishText: 'Area: 12.50 decimals (about 5,445 sq ft)',
    edited: false,
    nameMarks: [],
    termMentions: [],
  ),
  const DraftLineView(
    translationId: 't-6',
    lineOrder: 6,
    sourceText: 'তারিখ: ১২ ফাল্গুন ১৪৩০',
    englishText: 'Date: 12 Falgun 1430 (25 February 2024)',
    edited: false,
    nameMarks: [],
    termMentions: [],
  ),
];

const _sampleNameBook = <NameBookRule>[
  NameBookRule(
    id: 'n-1',
    bangla: 'ফারহানা রহমান',
    english: 'FARHANA RAHMAN',
    category: 'person',
    source: 'passport',
    confirmed: true,
  ),
  NameBookRule(
    id: 'n-2',
    bangla: 'মোঃ আব্দুর রহমান',
    english: 'MD ABDUR RAHMAN',
    category: 'person',
    source: 'passport',
    confirmed: true,
  ),
  NameBookRule(
    id: 'n-3',
    bangla: 'রোকেয়া বেগম',
    english: 'ROKEYA BEGUM',
    category: 'person',
    source: 'nid',
    confirmed: true,
  ),
  NameBookRule(
    id: 'n-4',
    bangla: 'আব্দুল করিম',
    english: 'Abdul Karim',
    category: 'person',
    source: 'suggested',
    confirmed: false,
  ),
  NameBookRule(
    id: 'n-5',
    bangla: 'বিরুলিয়া',
    english: 'Birulia',
    category: 'place',
    source: 'manual',
    confirmed: true,
  ),
  NameBookRule(
    id: 'n-6',
    bangla: 'সাভার',
    english: 'Savar',
    category: 'place',
    source: 'manual',
    confirmed: true,
  ),
];

Future<AppDatabase> _seedPaper() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final scans = ScanRepository(db);
  final records = RecordRepository(db);
  await scans.createScan(
    id: 'khatian-m5',
    mode: ScanMode.document,
    imagePath: '/sample/khatian.jpg',
    langHint: 'bn',
    createdAt: DateTime.now(),
  );
  await (db.update(db.scans)..where((s) => s.id.equals('khatian-m5'))).write(
    const ScansCompanion(kind: Value('land')),
  );
  await records.saveDocument(
    scanId: 'khatian-m5',
    title: 'খতিয়ান, বিরুলিয়া',
    body: _sampleDraftLines.map((l) => l.sourceText).join('\n'),
    tags: const [],
  );
  return db;
}

void main() {
  setUpAll(loadRosidTestFonts);

  Future<void> pumpPhone(
    WidgetTester tester,
    AppDatabase db,
    SharedPreferences prefs,
    Widget child,
    String goldenName, {
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeMode,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: child,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$goldenName.png'),
    );
  }

  testWidgets('M5 screen golden: translate-english-draft', (tester) async {
    SharedPreferences.setMockInitialValues({'language_code': 'en'});
    final prefs = await SharedPreferences.getInstance();
    final db = await _seedPaper();
    addTearDown(db.close);

    await pumpPhone(
      tester,
      db,
      prefs,
      PaperScreen(
        scanId: 'khatian-m5',
        initialTab: RosidReaderTab.english,
        previewDraftLines: _sampleDraftLines,
        previewTerms: const [_khatianTerm],
      ),
      'm5_translate_english_draft',
    );
  });

  testWidgets('M5 screen golden: translate-english-draft-dark', (tester) async {
    SharedPreferences.setMockInitialValues({'language_code': 'en'});
    final prefs = await SharedPreferences.getInstance();
    final db = await _seedPaper();
    addTearDown(db.close);

    await pumpPhone(
      tester,
      db,
      prefs,
      PaperScreen(
        scanId: 'khatian-m5',
        initialTab: RosidReaderTab.english,
        previewDraftLines: _sampleDraftLines,
        previewTerms: const [_khatianTerm],
      ),
      'm5_translate_english_draft_dark',
      themeMode: ThemeMode.dark,
    );
  });

  testWidgets('M5 screen golden: translate-term-help', (tester) async {
    SharedPreferences.setMockInitialValues({'language_code': 'en'});
    final prefs = await SharedPreferences.getInstance();
    final db = await _seedPaper();
    addTearDown(db.close);

    await pumpPhone(
      tester,
      db,
      prefs,
      Stack(
        children: [
          PaperScreen(
            scanId: 'khatian-m5',
            initialTab: RosidReaderTab.english,
            previewDraftLines: _sampleDraftLines,
            previewTerms: const [_khatianTerm],
          ),
          const ModalBarrier(dismissible: false, color: Color(0x66000000)),
          Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              color: Colors.transparent,
              child: TermHelpSheet(term: _khatianTerm, onApply: (_) {}),
            ),
          ),
        ],
      ),
      'm5_translate_term_help',
    );
  });

  testWidgets('M5 screen golden: translate-name-book', (tester) async {
    SharedPreferences.setMockInitialValues({'language_code': 'en'});
    final prefs = await SharedPreferences.getInstance();
    final db = await _seedPaper();
    addTearDown(db.close);

    await pumpPhone(
      tester,
      db,
      prefs,
      const NameBookScreen(previewNames: _sampleNameBook),
      'm5_translate_name_book',
    );
  });
}
