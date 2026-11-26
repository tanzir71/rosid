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
import 'package:rosid/core/theme/tokens.g.dart';
import 'package:rosid/core/widgets/rosid_navigation.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/database/database_provider.dart';
import 'package:rosid/data/repositories/record_repository.dart';
import 'package:rosid/data/repositories/scan_repository.dart';
import 'package:rosid/features/paper/check_words_screen.dart';
import 'package:rosid/features/paper/paper_screen.dart';
import 'package:rosid/ocr/pipeline/reading_interfaces.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/golden_fonts.dart';

Future<AppDatabase> _seedKhatianPaper() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final scans = ScanRepository(db);
  final records = RecordRepository(db);
  final now = DateTime.now();

  await scans.createScan(
    id: 'khatian-m4',
    mode: ScanMode.document,
    imagePath: '/sample/khatian.jpg',
    langHint: 'bn',
    createdAt: now,
  );
  await (db.update(db.scans)..where((s) => s.id.equals('khatian-m4'))).write(
    const ScansCompanion(kind: Value('land'), checkCount: Value(3)),
  );

  const lines = [
    ('l-0', 'খতিয়ান নং ১২৪৫', 0.96, 0.14, 0.21),
    ('l-1', 'জেলা: ঢাকা, উপজেলা: সাভার', 0.94, 0.24, 0.30),
    ('l-2', 'মৌজা: বিরুলিয়া জে.এল. নং: ৩৫', 0.65, 0.31, 0.37),
    ('l-3', 'মালিকের নাম: মোঃ আব্দুর রহমান', 0.94, 0.39, 0.45),
    ('l-4', 'পিতা: মৃত আব্দুল করিম', 0.68, 0.30, 0.36),
    ('l-5', 'দাগ নং: ৩০২, শ্রেণি: ভিটি', 0.95, 0.34, 0.40),
    ('l-6', 'জমির পরিমাণ: ১২.৫০ শতাংশ', 0.66, 0.41, 0.48),
  ];

  for (var i = 0; i < lines.length; i++) {
    final (id, text, conf, top, bot) = lines[i];
    final box = DetectedLineBox(
      topLeft: (0.06, top),
      topRight: (0.94, top),
      bottomRight: (0.94, bot),
      bottomLeft: (0.06, bot),
      score: conf,
    );
    await db
        .into(db.textLines)
        .insert(
          TextLinesCompanion.insert(
            id: id,
            scanId: 'khatian-m4',
            pageIndex: 0,
            lineOrder: i,
            textContent: text,
            boxJson: Value(box.toBoxJson()),
            confidence: Value(conf),
          ),
        );
  }

  await db
      .into(db.details)
      .insert(
        DetailsCompanion.insert(
          id: 'd-1',
          scanId: 'khatian-m4',
          detailKey: 'khatian_no',
          value: '১২৪৫',
          sourceLineId: const Value('l-0'),
        ),
      );
  await db
      .into(db.details)
      .insert(
        DetailsCompanion.insert(
          id: 'd-2',
          scanId: 'khatian-m4',
          detailKey: 'plot_no',
          value: '৩০২',
          sourceLineId: const Value('l-5'),
        ),
      );
  await db
      .into(db.details)
      .insert(
        DetailsCompanion.insert(
          id: 'd-3',
          scanId: 'khatian-m4',
          detailKey: 'owner',
          value: 'মোঃ আব্দুর রহমান',
          sourceLineId: const Value('l-3'),
        ),
      );
  await db
      .into(db.details)
      .insert(
        DetailsCompanion.insert(
          id: 'd-4',
          scanId: 'khatian-m4',
          detailKey: 'area',
          value: '১২.৫০ শতাংশ',
          sourceLineId: const Value('l-6'),
        ),
      );

  // Seed 3 plausible Bangla near-matches in corrections/names for Check words golden
  await db
      .into(db.corrections)
      .insert(
        CorrectionsCompanion.insert(
          id: 'c-1',
          wrongReading: 'বিরুলিয়া',
          rightReading: 'বিরুনিয়া',
        ),
      );
  await db
      .into(db.names)
      .insert(
        NamesCompanion.insert(
          id: 'n-1',
          bangla: 'বিরলিয়া',
          english: 'Biralia',
          category: const Value('place'),
        ),
      );
  await db
      .into(db.names)
      .insert(
        NamesCompanion.insert(
          id: 'n-2',
          bangla: 'বিকলিয়া',
          english: 'Bikalia',
          category: const Value('place'),
        ),
      );

  await records.saveDocument(
    scanId: 'khatian-m4',
    title: 'খতিয়ান, বিরুলিয়া',
    body: lines.map((e) => e.$2).join('\n'),
    tags: const [],
  );
  return db;
}

Widget _sampleScanPaper() {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ভূমি রেকর্ড ও জরিপ অধিদপ্তর',
          textAlign: TextAlign.center,
          style: RosidTextTokens.docSmall.copyWith(
            color: const Color(0xFF55586A),
          ),
        ),
        Text(
          'খতিয়ান নং ১২৪৫',
          textAlign: TextAlign.center,
          style: RosidTextTokens.docTitle.copyWith(
            fontSize: 16,
            color: RosidColorTokens.paperInkLight,
          ),
        ),
        const Divider(color: Color(0xFFD4D6CE), height: 14),
        Text(
          'জেলা: ঢাকা           উপজেলা: সাভার\n'
          'মৌজা: বিরুলিয়া      জে.এল. নং: ৩৫\n'
          'মালিকের নাম: মোঃ আব্দুর রহমান\n'
          'পিতা: মৃত আব্দুল করিম\n'
          'দাগ নং: ৩০২          শ্রেণি: ভিটি\n'
          'জমির পরিমাণ: ১২.৫০ শতাংশ',
          style: RosidTextTokens.docSmall.copyWith(
            fontSize: 11.5,
            height: 2.0,
            color: RosidColorTokens.paperInkLight,
          ),
        ),
      ],
    ),
  );
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

  testWidgets('M4 screen golden: read-text', (tester) async {
    SharedPreferences.setMockInitialValues({'language_code': 'en'});
    final prefs = await SharedPreferences.getInstance();
    final db = await _seedKhatianPaper();
    addTearDown(db.close);

    await pumpPhone(
      tester,
      db,
      prefs,
      const PaperScreen(
        scanId: 'khatian-m4',
        initialTab: RosidReaderTab.text,
        previewShowListen: true,
      ),
      'm4_read_text',
    );
  });

  testWidgets('M4 screen golden: read-text-dark', (tester) async {
    SharedPreferences.setMockInitialValues({'language_code': 'en'});
    final prefs = await SharedPreferences.getInstance();
    final db = await _seedKhatianPaper();
    addTearDown(db.close);

    await pumpPhone(
      tester,
      db,
      prefs,
      const PaperScreen(
        scanId: 'khatian-m4',
        initialTab: RosidReaderTab.text,
        previewShowListen: true,
      ),
      'm4_read_text_dark',
      themeMode: ThemeMode.dark,
    );
  });

  testWidgets('M4 screen golden: read-check-words', (tester) async {
    SharedPreferences.setMockInitialValues({'language_code': 'en'});
    final prefs = await SharedPreferences.getInstance();
    final db = await _seedKhatianPaper();
    addTearDown(db.close);

    await pumpPhone(
      tester,
      db,
      prefs,
      const CheckWordsScreen(scanId: 'khatian-m4'),
      'm4_read_check_words',
    );
  });

  testWidgets('M4 screen golden: read-scan-tap-line', (tester) async {
    SharedPreferences.setMockInitialValues({'language_code': 'en'});
    final prefs = await SharedPreferences.getInstance();
    final db = await _seedKhatianPaper();
    addTearDown(db.close);

    await pumpPhone(
      tester,
      db,
      prefs,
      PaperScreen(
        scanId: 'khatian-m4',
        initialTab: RosidReaderTab.scan,
        previewScanWidget: _sampleScanPaper(),
        previewSelectedLineId: 'l-6',
      ),
      'm4_read_scan_tap_line',
    );
  });
}
