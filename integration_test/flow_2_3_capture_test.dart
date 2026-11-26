import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rosid/app.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/data/database/database_provider.dart';
import 'package:rosid/features/capture/fake_capture_source.dart';
import 'package:rosid/features/capture/frame_analyzer.dart';
import 'package:rosid/features/capture/scan_camera_screen.dart';
import 'package:rosid/features/capture/scan_controller.dart';
import 'package:rosid/ocr/models/ocr_models.dart';
import 'package:rosid/ocr/pipeline/reading_interfaces.dart';
import 'package:rosid/ocr/pipeline/rosid_reading_pipeline.dart';
import 'package:shared_preferences/shared_preferences.dart';

Uint8List _makeSyntheticJpeg({
  required double left,
  required double top,
  required double right,
  required double bottom,
  int headerR = 27,
  int headerG = 122,
  int headerB = 80,
}) {
  const w = 320;
  const h = 240;
  final im = img.Image(width: w, height: h);
  img.fill(im, color: img.ColorRgb8(40, 40, 40));
  img.fillRect(
    im,
    x1: (left * w).round(),
    y1: (top * h).round(),
    x2: (right * w).round(),
    y2: (bottom * h).round(),
    color: img.ColorRgb8(230, 228, 220),
  );
  img.fillRect(
    im,
    x1: (left * w).round() + 6,
    y1: (top * h).round() + 6,
    x2: (right * w).round() - 6,
    y2: (top * h).round() + 26,
    color: img.ColorRgb8(headerR, headerG, headerB),
  );
  for (var y = (top * h).round() + 40; y < (bottom * h).round() - 16; y += 16) {
    img.fillRect(
      im,
      x1: (left * w).round() + 18,
      y1: y,
      x2: (right * w).round() - 18,
      y2: y + 4,
      color: img.ColorRgb8(36, 36, 44),
    );
  }
  return Uint8List.fromList(img.encodeJpg(im, quality: 90));
}

class _LandFixturePipeline implements ReadingPipeline {
  @override
  Future<ReadingPageResult> readPage({
    required Uint8List greyImageBytes,
    required int pageIndex,
    void Function(ReadingProgressEvent event)? onProgress,
    ReadingCancelToken? cancelToken,
  }) async {
    onProgress?.call(
      const ReadingProgressEvent(stage: ReadingStage.detectingLines),
    );
    final lines = pageIndex == 0
        ? [
            RecognizedLine(
              pageIndex: 0,
              lineOrder: 0,
              text: 'খতিয়ান নং ১২৪৫',
              originalText: 'খতিয়ান নং ১২৪৫',
              box: DetectedLineBox.fromRect(
                const OcrRect(left: 0.08, top: 0.12, right: 0.90, bottom: 0.20),
              ),
              confidence: 0.95,
              script: 'bn',
              engineId: 'fixture',
            ),
            RecognizedLine(
              pageIndex: 0,
              lineOrder: 1,
              text: 'মৌজা: বিরুলযা',
              originalText: 'মৌজা: বিরুলযা',
              box: DetectedLineBox.fromRect(
                const OcrRect(left: 0.08, top: 0.24, right: 0.90, bottom: 0.32),
              ),
              confidence: 0.62,
              script: 'bn',
              engineId: 'fixture',
              uncertainWords: const [
                UncertainWord(
                  word: 'বিরুলযা',
                  wordIndex: 1,
                  confidence: 0.62,
                  alternatives: ['বিরুলিয়া'],
                ),
              ],
            ),
            RecognizedLine(
              pageIndex: 0,
              lineOrder: 2,
              text: 'মালিকের নাম: মোঃ আব্দুর রহমান',
              originalText: 'মালিকের নাম: মোঃ আব্দুর রহমান',
              box: DetectedLineBox.fromRect(
                const OcrRect(left: 0.08, top: 0.36, right: 0.90, bottom: 0.44),
              ),
              confidence: 0.94,
              script: 'bn',
              engineId: 'fixture',
            ),
          ]
        : [
            RecognizedLine(
              pageIndex: 1,
              lineOrder: 0,
              text: 'দাগ নং: ৩০২',
              originalText: 'দাগ নং: ৩০২',
              box: DetectedLineBox.fromRect(
                const OcrRect(left: 0.08, top: 0.14, right: 0.90, bottom: 0.22),
              ),
              confidence: 0.95,
              script: 'bn',
              engineId: 'fixture',
            ),
            RecognizedLine(
              pageIndex: 1,
              lineOrder: 1,
              text: 'জমির পরিমাণ: ১২.৫০ শতাংশ',
              originalText: 'জমির পরিমাণ: ১২.৫০ শতাংশ',
              box: DetectedLineBox.fromRect(
                const OcrRect(left: 0.08, top: 0.28, right: 0.90, bottom: 0.36),
              ),
              confidence: 0.93,
              script: 'bn',
              engineId: 'fixture',
            ),
          ];

    onProgress?.call(
      ReadingProgressEvent(
        stage: ReadingStage.readingLines,
        currentLine: lines.length,
        totalLines: lines.length,
      ),
    );
    return ReadingPageResult(
      pageIndex: pageIndex,
      lines: lines,
      hasHandwriting: false,
      elapsedMs: 120,
      engineSummary: 'fixture',
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('M2 emulator benchmark: FrameAnalyzerIsolate median <= 40 ms', (
    tester,
  ) async {
    final isolate = await FrameAnalyzerIsolate.spawn();
    addTearDown(isolate.dispose);

    const w = 320;
    const h = 240;
    final luma = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final inside = x >= 45 && x <= 275 && y >= 25 && y <= 215;
        luma[y * w + x] = inside ? 220 : 42;
      }
    }

    await isolate.analyzeLuma(luma, width: w, height: h, timestampMs: 0);

    final timings = <int>[];
    for (var i = 0; i < 21; i++) {
      final res = await isolate.analyzeLuma(
        luma,
        width: w,
        height: h,
        timestampMs: (i + 1) * 100,
        skipBlurCheck: true,
      );
      expect(res.quad, isNotNull);
      timings.add(res.elapsedMs);
    }
    timings.sort();
    final median = timings[timings.length ~/ 2];
    // ignore: avoid_print
    print(
      '[M2_EMULATOR_BENCH] FrameAnalyzerIsolate median=${median}ms (n=${timings.length})',
    );
    expect(median, lessThanOrEqualTo(40));
  });

  testWidgets(
    'Flow 2 (full M4): scan two-page land record, adjust page 2, read, see Key details, check one word, save',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await prefs.setBool('onboarding_complete', true);
      await prefs.setString('language_code', 'en');

      final steadyJpg = _makeSyntheticJpeg(
        left: 0.14,
        top: 0.12,
        right: 0.86,
        bottom: 0.88,
      );
      final movingFrames = [
        for (var i = 0; i < 4; i++)
          CaptureFrame(
            bytes: _makeSyntheticJpeg(
              left: 0.08 + i * 0.05,
              top: 0.12,
              right: 0.68 + i * 0.05,
              bottom: 0.86,
            ),
            width: 320,
            height: 240,
          ),
        for (var i = 0; i < 12; i++)
          CaptureFrame(
            bytes: steadyJpg,
            width: 320,
            height: 240,
            isSteady: true,
          ),
      ];

      final fakeSource = FakeCaptureSource(
        sequence: movingFrames,
        frameInterval: const Duration(milliseconds: 120),
      );
      addTearDown(fakeSource.dispose);

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          fakeCaptureSourceProvider.overrideWithValue(fakeSource),
          readingPipelineProvider.overrideWithValue(_LandFixturePipeline()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const RosidApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Open Document scan from Home shortcut.
      await tester.tap(find.text('Document'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Wait for moving-then-steady frames to auto-capture page 1.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 120));
        if (container.read(v2ScanProvider).pages.isNotEmpty) break;
      }
      expect(container.read(v2ScanProvider).pages.length, 1);

      // Capture page 2 via manual shutter.
      await tester.tap(find.byKey(const ValueKey('scan-shutter')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(container.read(v2ScanProvider).pages.length, 2);

      // Go to Adjust page (starts on Page 2 of 2), adjust filter, tap Read text.
      await tester.tap(find.byKey(const ValueKey('scan-done-pages')));
      await tester.pumpAndSettle();
      expect(find.text('Page 2 of 2'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('adjust-filter-grey')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('adjust-read-text')));

      // Wait for cleaning + reading to finish and land on Paper screen.
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 200));
        if (find.text('Key details').evaluate().isNotEmpty) break;
      }

      // Verify Key details (Khatian, Plot, Owner, Area conversion) & Check words banner.
      expect(find.text('Key details'), findsOneWidget);
      expect(find.text('১২৪৫'), findsOneWidget);
      expect(find.text('৩০২'), findsOneWidget);
      expect(find.textContaining('5,445 sq ft'), findsOneWidget);
      expect(find.byKey(const ValueKey('paper-check-banner')), findsOneWidget);

      // Tap Check them -> fix "বিরুলযা" -> "বিরুলিয়া" -> Looks right.
      await tester.tap(find.byKey(const ValueKey('paper-check-banner')));
      await tester.pumpAndSettle();
      expect(find.text('Check words'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('check-word-field')),
        'বিরুলিয়া',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('check-looks-right')));
      await tester.pumpAndSettle();

      // Verify correction persisted in DB!
      final db = container.read(databaseProvider);
      final corrections = await db.select(db.corrections).get();
      expect(corrections.any((c) => c.rightReading == 'বিরুলিয়া'), isTrue);
    },
  );

  testWidgets(
    'Flow 3 (ID card capture part): scans front, prompts turn over, scans back, composes A4 sheet',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await prefs.setBool('onboarding_complete', true);
      await prefs.setString('language_code', 'en');

      final frontJpg = _makeSyntheticJpeg(
        left: 0.12,
        top: 0.22,
        right: 0.88,
        bottom: 0.78,
        headerR: 27,
        headerG: 122,
        headerB: 80,
      );
      final backJpg = _makeSyntheticJpeg(
        left: 0.12,
        top: 0.22,
        right: 0.88,
        bottom: 0.78,
        headerR: 67,
        headerG: 51,
        headerB: 176,
      );
      final fakeSource = FakeCaptureSource(
        sequence: [
          CaptureFrame(bytes: frontJpg, width: 320, height: 240),
          CaptureFrame(bytes: backJpg, width: 320, height: 240),
        ],
        frameInterval: const Duration(milliseconds: 500),
      );
      addTearDown(fakeSource.dispose);

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          fakeCaptureSourceProvider.overrideWithValue(fakeSource),
          readingPipelineProvider.overrideWithValue(_LandFixturePipeline()),
        ],
      );
      addTearDown(container.dispose);
      container.read(v2ScanProvider.notifier).setAutoCapture(false);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const RosidApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('ID card'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Capture front side.
      await tester.tap(find.byKey(const ValueKey('scan-shutter')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text('Turn the card over'), findsOneWidget);
      expect(container.read(v2ScanProvider).pages.length, 1);
      expect(container.read(v2ScanProvider).pages.first.side, 'front');

      // Capture back side -> auto navigates to Adjust page with 2 sides.
      await tester.tap(find.byKey(const ValueKey('scan-shutter')));
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      expect(container.read(v2ScanProvider).pages.length, 2);
      expect(container.read(v2ScanProvider).pages[1].side, 'back');
      expect(find.text('Page 2 of 2'), findsOneWidget);

      // Tap Read text -> composes A4 sheet with both sides.
      await tester.tap(find.byKey(const ValueKey('adjust-read-text')));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 200));
        if (container.read(v2ScanProvider).composedIdCardPath != null) {
          break;
        }
      }
      final composedPath = container.read(v2ScanProvider).composedIdCardPath;
      expect(composedPath, isNotNull);
      expect(File(composedPath!).existsSync(), isTrue);
      // Allow the final route transition to finish before container teardown.
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
    },
  );
}
