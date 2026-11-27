import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rosid/core/l10n/app_localizations.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/core/theme/app_theme.dart';
import 'package:rosid/core/theme/tokens.g.dart';
import 'package:rosid/core/widgets/rosid_navigation.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/database/database_provider.dart';
import 'package:rosid/features/capture/frame_analyzer.dart';
import 'package:rosid/features/capture/scan_camera_screen.dart';
import 'package:rosid/features/capture/scan_controller.dart';
import 'package:rosid/features/paper/check_words_screen.dart';
import 'package:rosid/features/paper/paper_screen.dart';
import 'package:rosid/ocr/preprocess/document_quad.dart';
import 'package:rosid/translation/draft_rules.dart';
import 'package:rosid/translation/translation_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/golden_fonts.dart';

Widget _sampleKhatianPaper() {
  final paper = Container(
    width: 248,
    padding: const EdgeInsets.fromLTRB(18, 22, 18, 24),
    decoration: BoxDecoration(
      color: const Color(0xFFFAF9F4),
      borderRadius: BorderRadius.circular(4),
      boxShadow: const [
        BoxShadow(
          color: Color(0x55000000),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ভূমি রেকর্ড ও জরিপ অধিদপ্তর',
          textAlign: TextAlign.center,
          style: RosidTextTokens.docSmall.copyWith(
            fontSize: 10,
            color: RosidColorTokens.inkSecondaryLight,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'খতিয়ান নং ১২৪৫',
          textAlign: TextAlign.center,
          style: RosidTextTokens.docTitle.copyWith(
            fontSize: 16,
            color: RosidColorTokens.paperInkLight,
          ),
        ),
        const Divider(color: Color(0xFFD4D6CE), height: 18),
        Text(
          'জেলা: ঢাকা           উপজেলা: সাভার\n'
          'মৌজা: বিরুলিয়া      জে.এল. নং: ৩৫\n'
          'মালিকের নাম: মোঃ আব্দুর রহমান\n'
          'পিতা: মৃত আব্দুল করিম\n'
          'দাগ নং: ৩০২          শ্রেণি: ভিটি\n'
          'জমির পরিমাণ: ১২.৫০ শতাংশ',
          style: RosidTextTokens.docSmall.copyWith(
            fontSize: 11.5,
            height: 1.75,
            color: RosidColorTokens.paperInkLight,
          ),
        ),
      ],
    ),
  );
  return Center(child: Transform.rotate(angle: 0.03, child: paper));
}

Future<AppDatabase> _seedBanglaKhatian() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final now = DateTime(2026, 11, 26);
  await db
      .into(db.scans)
      .insert(
        ScansCompanion.insert(
          id: 'khatian-m9',
          type: 'document',
          kind: const Value('land'),
          language: const Value('bn'),
          checkCount: const Value(3),
          imagePath: '',
          ocrRawText: const Value('মৌজা: বিরুলযা জে.এল. নং: ৩৫'),
          createdAt: now,
          updatedAt: now,
        ),
      );
  await db
      .into(db.documents)
      .insert(
        DocumentsCompanion.insert(
          id: 'doc-m9',
          scanId: 'khatian-m9',
          title: 'খতিয়ান, বিরুলিয়া',
          body: const Value('মৌজা: বিরুলযা জে.এল. নং: ৩৫'),
        ),
      );
  await db
      .into(db.textLines)
      .insert(
        TextLinesCompanion.insert(
          id: 'l-0',
          scanId: 'khatian-m9',
          pageIndex: 0,
          lineOrder: 0,
          textContent: 'মৌজা: বিরুলযা জে.এল. নং: ৩৫',
          boxJson: const Value('[0.08,0.22,0.92,0.32]'),
          confidence: const Value(0.58),
          script: const Value('bn'),
        ),
      );
  return db;
}

void main() {
  setUpAll(loadRosidTestFonts);

  Future<void> pumpBnPhone(
    WidgetTester tester,
    ProviderContainer container,
    Widget child,
    String goldenName,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          locale: const Locale('bn'),
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
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$goldenName.png'),
    );
  }

  testWidgets('M9 Bangla site screenshot: scan camera', (tester) async {
    SharedPreferences.setMockInitialValues({'language_code': 'bn'});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(container.dispose);

    container.read(v2ScanProvider.notifier).setPagesForTesting(const [
      CapturedPageDraft(pageId: 'p1', originalPath: '/sample/1.jpg'),
    ]);

    await pumpBnPhone(
      tester,
      container,
      ScanCameraScreen(
        initialMode: V2ScanMode.document,
        initializeCamera: false,
        previewBackground: _sampleKhatianPaper(),
        previewQuad: const DocumentQuad(
          topLeft: NormalizedPoint(0.20, 0.25),
          topRight: NormalizedPoint(0.81, 0.27),
          bottomRight: NormalizedPoint(0.77, 0.75),
          bottomLeft: NormalizedPoint(0.16, 0.73),
        ),
        previewHint: CaptureQualityHint.edgesFoundHoldSteady,
        previewSteadyProgress: 0.65,
      ),
      'm9_bn_scan_camera',
    );
  });

  testWidgets('M9 Bangla site screenshot: check words', (tester) async {
    SharedPreferences.setMockInitialValues({'language_code': 'bn'});
    final prefs = await SharedPreferences.getInstance();
    final db = await _seedBanglaKhatian();
    addTearDown(db.close);

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(container.dispose);

    await pumpBnPhone(
      tester,
      container,
      const CheckWordsScreen(scanId: 'khatian-m9'),
      'm9_bn_check_words',
    );
  });

  testWidgets('M9 Bangla site screenshot: english draft', (tester) async {
    SharedPreferences.setMockInitialValues({'language_code': 'bn'});
    final prefs = await SharedPreferences.getInstance();
    final db = await _seedBanglaKhatian();
    addTearDown(db.close);

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(container.dispose);

    const draftLines = [
      DraftLineView(
        translationId: 't-1',
        lineOrder: 0,
        sourceText: 'খতিয়ান নং ১২৪৫',
        englishText: 'Khatian (record of rights) No. 1245',
        edited: false,
        nameMarks: [],
        termMentions: [
          DraftTermMention(
            termId: 'term-khatian',
            renderedText: 'Khatian (record of rights)',
          ),
        ],
      ),
      DraftLineView(
        translationId: 't-2',
        lineOrder: 1,
        sourceText: 'জেলা: ঢাকা, উপজেলা: সাভার',
        englishText: 'District: Dhaka, Upazila: Savar',
        edited: false,
        nameMarks: [],
        termMentions: [],
      ),
      DraftLineView(
        translationId: 't-3',
        lineOrder: 2,
        sourceText: 'মৌজা: বিরুলিয়া, জে.এল. নং: ৩৫',
        englishText: 'Mouza: Birulia, J.L. No. 35',
        edited: false,
        nameMarks: [],
        termMentions: [],
      ),
      DraftLineView(
        translationId: 't-4',
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
      DraftLineView(
        translationId: 't-5',
        lineOrder: 4,
        sourceText: 'জমির পরিমাণ: ১২.৫০ শতাংশ',
        englishText: 'Area: 12.50 decimals (about 5,445 sq ft)',
        edited: false,
        nameMarks: [],
        termMentions: [],
      ),
      DraftLineView(
        translationId: 't-6',
        lineOrder: 5,
        sourceText: 'তারিখ: ১২ ফাল্গুন ১৪৩০',
        englishText: 'Date: 12 Falgun 1430 (25 February 2024)',
        edited: false,
        nameMarks: [],
        termMentions: [],
      ),
    ];

    await pumpBnPhone(
      tester,
      container,
      const PaperScreen(
        scanId: 'khatian-m9',
        initialTab: RosidReaderTab.english,
        previewDraftLines: draftLines,
      ),
      'm9_bn_translate_draft',
    );
  });
}
