import 'package:cupertino_ui/cupertino_ui.dart';
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
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/database/database_provider.dart';
import 'package:rosid/features/capture/adjust_page_screen.dart';
import 'package:rosid/features/capture/frame_analyzer.dart';
import 'package:rosid/features/capture/reading_progress_screen.dart';
import 'package:rosid/features/capture/scan_camera_screen.dart';
import 'package:rosid/features/capture/scan_controller.dart';
import 'package:rosid/ocr/preprocess/document_quad.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/golden_fonts.dart';

Widget _sampleKhatianPaper({double angle = 0}) {
  final paper = Container(
    width: 245,
    height: 360,
    padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F2EC),
      borderRadius: BorderRadius.circular(3),
    ),
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
        const SizedBox(height: 2),
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
  return Center(
    child: Transform.rotate(angle: angle, child: paper),
  );
}

Widget _sampleIdCardVisual() {
  return Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: AspectRatio(
        aspectRatio: 85.6 / 54.0,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F1EA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD8D7CF), width: 6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 68,
                    height: 82,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBCBC4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 12,
                          width: 110,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2B2C38),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          height: 10,
                          width: 82,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBCBC4),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          height: 10,
                          width: 104,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBCBC4),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                height: 10,
                width: 190,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBCBC4),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(loadRosidTestFonts);

  Future<void> pumpPhone(
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
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.light,
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
    await tester.pump(const Duration(milliseconds: 200));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$goldenName.png'),
    );
  }

  testWidgets('M2 screen golden: scan-camera', (tester) async {
    SharedPreferences.setMockInitialValues({
      'language_code': 'en',
      'expense_tracking_enabled': true,
    });
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
      CapturedPageDraft(pageId: 'p2', originalPath: '/sample/2.jpg'),
    ]);

    await pumpPhone(
      tester,
      container,
      ScanCameraScreen(
        initialMode: V2ScanMode.document,
        initializeCamera: false,
        previewBackground: _sampleKhatianPaper(angle: 0.03),
        previewQuad: const DocumentQuad(
          topLeft: NormalizedPoint(0.20, 0.25),
          topRight: NormalizedPoint(0.81, 0.27),
          bottomRight: NormalizedPoint(0.77, 0.75),
          bottomLeft: NormalizedPoint(0.16, 0.73),
        ),
        previewHint: CaptureQualityHint.edgesFoundHoldSteady,
        previewSteadyProgress: 0.65,
      ),
      'm2_scan_camera',
    );
  });

  testWidgets('M2 screen golden: scan-id-card-back', (tester) async {
    SharedPreferences.setMockInitialValues({
      'language_code': 'en',
      'expense_tracking_enabled': true,
    });
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

    container.read(v2ScanProvider.notifier).startSession(V2ScanMode.idCard);
    container.read(v2ScanProvider.notifier).setPagesForTesting(const [
      CapturedPageDraft(
        pageId: 'id-front',
        originalPath: '/sample/front.jpg',
        side: 'front',
      ),
    ]);

    await pumpPhone(
      tester,
      container,
      ScanCameraScreen(
        initialMode: V2ScanMode.idCard,
        initializeCamera: false,
        previewBackground: _sampleIdCardVisual(),
        previewSteadyProgress: 0.65,
      ),
      'm2_scan_id_card_back',
    );
  });

  testWidgets('M2 screen golden: scan-adjust-page', (tester) async {
    SharedPreferences.setMockInitialValues({'language_code': 'en'});
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
      CapturedPageDraft(
        pageId: 'p2',
        originalPath: '/sample/2.jpg',
        quad: DocumentQuad(
          topLeft: NormalizedPoint(0.17, 0.14),
          topRight: NormalizedPoint(0.83, 0.14),
          bottomRight: NormalizedPoint(0.83, 0.86),
          bottomLeft: NormalizedPoint(0.17, 0.86),
        ),
      ),
      CapturedPageDraft(pageId: 'p3', originalPath: '/sample/3.jpg'),
    ], selected: 1);

    await pumpPhone(
      tester,
      container,
      AdjustPageScreen(
        previewPageWidget: _sampleKhatianPaper(),
        previewDraggingCorner: 0,
      ),
      'm2_scan_adjust_page',
    );
  });

  testWidgets('M2 screen golden: scan-reading', (tester) async {
    SharedPreferences.setMockInitialValues({'language_code': 'en'});
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

    await pumpPhone(
      tester,
      container,
      ReadingProgressScreen(
        autoStart: false,
        previewPage: _sampleKhatianPaper(),
        previewSnapshot: const ReadingProgressSnapshot(
          cleanStep: ReadingStepState.done,
          scriptStep: ReadingStepState.done,
          readStep: ReadingStepState.active,
          detailsStep: ReadingStepState.pending,
          currentLine: 9,
          totalLines: 14,
          hasHandwriting: true,
          scanBarFraction: 0.56,
        ),
      ),
      'm2_scan_reading',
    );
  });
}
