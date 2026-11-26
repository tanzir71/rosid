import 'dart:typed_data';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:rosid/core/l10n/app_localizations.dart';
import 'package:rosid/core/profile/app_profile.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/core/theme/app_theme.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/database/database_provider.dart';
import 'package:rosid/data/repositories/scan_repository.dart';
import 'package:rosid/features/capture/reading_progress_screen.dart';
import 'package:rosid/ocr/models/ocr_models.dart';
import 'package:rosid/ocr/pipeline/onnx_latin_recognizer.dart';
import 'package:rosid/ocr/pipeline/onnx_line_detector.dart';
import 'package:rosid/ocr/pipeline/post_reading.dart';
import 'package:rosid/ocr/pipeline/reading_interfaces.dart';
import 'package:rosid/ocr/pipeline/rosid_reading_pipeline.dart';
import 'package:rosid/ocr/pipeline/script_router.dart';
import 'package:rosid/parsing/receipt_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

Uint8List _blankPagePng() {
  final page = img.Image(width: 400, height: 300);
  img.fill(page, color: img.ColorRgb8(250, 250, 248));
  return Uint8List.fromList(img.encodePng(page));
}

void main() {
  group('ONNX detector & CTC decoder pure-Dart helpers', () {
    test('extractLineBoxesFromProbMap merges same-line fragments and orders top-to-bottom', () {
      const mw = 100;
      const mh = 100;
      final map = Float32List(mw * mh);

      void fillRect(int x0, int y0, int x1, int y1, double p) {
        for (var y = y0; y < y1; y++) {
          for (var x = x0; x < x1; x++) {
            map[y * mw + x] = p;
          }
        }
      }

      // Line 1 (two fragments on same y band: item name + price)
      fillRect(10, 15, 45, 22, 0.9);
      fillRect(70, 15, 90, 22, 0.85);
      // Line 2 below
      fillRect(10, 55, 85, 62, 0.92);

      final boxes = extractLineBoxesFromProbMap(
        map,
        mapWidth: mw,
        mapHeight: mh,
        origWidth: 800,
        origHeight: 800,
      );

      expect(boxes, hasLength(2));
      expect(boxes[0].boundingRect.top, lessThan(boxes[1].boundingRect.top));
      // Merged line 1 spans both fragments
      expect(boxes[0].boundingRect.left, lessThan(120));
      expect(boxes[0].boundingRect.right, greaterThan(680));
    });

    test('ctcGreedyDecode collapses repeats and skips blanks with softmax confidence', () {
      final dict = ['<blank>', 'A', 'B', 'C'];
      // 5 timesteps: A, A, blank, B, C -> "ABC"
      final logits = Float32List.fromList([
        0, 6, 0, 0, // A
        0, 5, 0, 0, // repeat A (collapsed)
        7, 0, 0, 0, // blank
        0, 0, 6, 0, // B
        0, 0, 0, 6, // C
      ]);

      final (text, conf) = ctcGreedyDecode(
        logits,
        timeSteps: 5,
        numClasses: 4,
        dict: dict,
      );
      expect(text, 'ABC');
      expect(conf, greaterThan(0.95));
    });
  });

  group('ScriptRouter matra detection', () {
    test(
      'assigns higher matraScore to horizontal head-line than vertical strokes',
      () {
        final bnLike = img.Image(width: 120, height: 40);
        img.fill(bnLike, color: img.ColorRgb8(255, 255, 255));
        // Continuous horizontal matra bar in upper third + vertical stems below
        img.fillRect(
          bnLike,
          x1: 10,
          y1: 10,
          x2: 110,
          y2: 13,
          color: img.ColorRgb8(20, 20, 20),
        );
        for (var x = 14; x < 106; x += 12) {
          img.fillRect(
            bnLike,
            x1: x,
            y1: 13,
            x2: x + 2,
            y2: 32,
            color: img.ColorRgb8(20, 20, 20),
          );
        }

        final latinLike = img.Image(width: 120, height: 40);
        img.fill(latinLike, color: img.ColorRgb8(255, 255, 255));
        // Separated vertical letters with no continuous horizontal matra
        for (var x = 12; x < 108; x += 14) {
          img.fillRect(
            latinLike,
            x1: x,
            y1: 8,
            x2: x + 2,
            y2: 32,
            color: img.ColorRgb8(20, 20, 20),
          );
        }

        const router = ScriptRouter();
        expect(router.matraScore(bnLike), greaterThan(0.75));
        expect(router.matraScore(latinLike), lessThan(0.30));
        expect(router.route(bnLike), LineScriptRoute.bangla);
        expect(router.route(latinLike), LineScriptRoute.latin);
      },
    );
  });

  group('PostReadingProcessor (NFC, remembered corrections, alternatives, handwriting)', () {
    test('normalizes NFD Bangla to NFC, applies repeated correction, suggests alternatives', () {
      const processor = PostReadingProcessor();
      // Decomposed য় (U+09AF + U+09BC) -> NFC U+09DF
      const rawLine = RecognizedLine(
        pageIndex: 0,
        lineOrder: 0,
        text: 'খতি\u09af\u09bcান বি\u09b0ুলযা',
        originalText: 'খতি\u09af\u09bcান বি\u09b0ুলযা',
        box: DetectedLineBox(
          topLeft: (0, 0),
          topRight: (200, 0),
          bottomRight: (200, 30),
          bottomLeft: (0, 30),
          score: 0.9,
        ),
        confidence: 0.65,
        script: 'bn',
        engineId: 'test',
      );

      final out = processor.processLine(
        rawLine,
        remembered: const [
          RememberedCorrection(
            wrongText: 'বিরুলযা',
            rightText: 'বিরুলিয়া',
            count: 1,
          ),
        ],
      );

      expect(out.text, contains('খতিয়ান'));
      expect(out.uncertainWords, isNotEmpty);
      final target = out.uncertainWords.firstWhere((u) => u.word == 'বিরুলযা');
      expect(target.alternatives.first, 'বিরুলিয়া');

      // When count >= 2, auto-applies remembered correction
      final autoOut = processor.processLine(
        rawLine,
        remembered: const [
          RememberedCorrection(
            wrongText: 'বিরুলযা',
            rightText: 'বিরুলিয়া',
            count: 3,
          ),
        ],
      );
      expect(autoOut.text, contains('বিরুলিয়া'));
      expect(autoOut.corrected, isTrue);
    });

    test(
      'detectHandwriting triggers on low-confidence uneven-stroke lines',
      () {
        const processor = PostReadingProcessor();
        final lines = [
          for (var i = 0; i < 4; i++)
            RecognizedLine(
              pageIndex: 0,
              lineOrder: i,
              text: 'হাতে লেখা নোট $i',
              originalText: 'হাতে লেখা নোট $i',
              box: DetectedLineBox.fromRect(
                OcrRect(
                  left: 10,
                  top: i * 30.0,
                  right: 200,
                  bottom: (i + 1) * 30.0,
                ),
              ),
              confidence: 0.52,
              script: 'bn',
              engineId: 'test',
            ),
        ];
        expect(
          processor.detectHandwriting(
            lines: lines,
            strokeVariances: const [0.55, 0.62, 0.48, 0.59],
          ),
          isTrue,
        );
        expect(
          processor.detectHandwriting(
            lines: lines,
            strokeVariances: const [0.18, 0.21, 0.19, 0.22],
          ),
          isFalse,
        );
      },
    );
  });

  group('RosidReadingPipeline & SQLite text_lines persistence', () {
    test('stores every line with 4-point box and confidence in text_lines and full text in scans', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = ScanRepository(db);
      await repo.createScan(
        id: 'scan-m3-1',
        mode: ScanMode.document,
        imagePath: '/tmp/p0.jpg',
        langHint: 'auto',
        createdAt: DateTime(2026, 11, 27),
      );

      final pipeline = RosidReadingPipeline(
        lineDetector: _StubLineDetector([
          DetectedLineBox.fromRect(
            const OcrRect(left: 20, top: 20, right: 350, bottom: 55),
          ),
          DetectedLineBox.fromRect(
            const OcrRect(left: 20, top: 70, right: 350, bottom: 105),
          ),
        ]),
        latinRecognizer: _StubLineRecognizer('en', [
          const LineRecognition(
            text: 'Grand Total 540.00',
            confidence: 0.94,
            engineId: 'ppocr-v5-en-onnx',
          ),
          const LineRecognition(
            text: '???',
            confidence: 0.25,
            engineId: 'ppocr-v5-en-onnx',
          ),
        ]),
        banglaRecognizer: _StubLineRecognizer('bn', [
          const LineRecognition(
            text: 'খতিয়ান নং ১২৪৫',
            confidence: 0.89,
            engineId: 'tesseract-line-ben',
          ),
        ]),
      );

      final events = <ReadingProgressEvent>[];
      final res = await pipeline.readPage(
        greyImageBytes: _blankPagePng(),
        pageIndex: 0,
        onProgress: events.add,
      );
      expect(res.lines, hasLength(2));
      expect(events.any((e) => e.stage == ReadingStage.readingLines), isTrue);

      await persistReadingResults(
        db: db,
        scanId: 'scan-m3-1',
        pageResults: [res],
      );

      final storedLines = await db.select(db.textLines).get();
      expect(storedLines, hasLength(2));
      for (final row in storedLines) {
        expect(row.boxJson, isNotEmpty);
        expect(DetectedLineBox.fromBoxJson(row.boxJson), isNotNull);
        expect(row.confidence, greaterThan(0));
      }
      final scan = await (db.select(
        db.scans,
      )..where((s) => s.id.equals('scan-m3-1'))).getSingle();
      expect(scan.ocrRawText, contains('Grand Total 540.00'));
      expect(scan.ocrRawText, contains('খতিয়ান নং ১২৪৫'));
    });

    test(
      'ReadingCancelToken stops reading pipeline cleanly mid-page',
      () async {
        final token = ReadingCancelToken();
        var calls = 0;
        final pipeline = RosidReadingPipeline(
          lineDetector: _StubLineDetector([
            for (var i = 0; i < 6; i++)
              DetectedLineBox.fromRect(
                OcrRect(
                  left: 10,
                  top: i * 35.0,
                  right: 300,
                  bottom: i * 35.0 + 25,
                ),
              ),
          ]),
          latinRecognizer: _CallbackLineRecognizer((_) {
            calls++;
            if (calls == 2) token.cancel();
            return const LineRecognition(
              text: 'Line',
              confidence: 0.95,
              engineId: 'en',
            );
          }),
          banglaRecognizer: _StubLineRecognizer('bn', const []),
        );

        final res = await pipeline.readPage(
          greyImageBytes: _blankPagePng(),
          pageIndex: 0,
          cancelToken: token,
        );
        expect(calls, 2);
        expect(res.lines.length, lessThanOrEqualTo(2));
      },
    );
  });

  group('ReadingProgressScreen Cancel widget test', () {
    testWidgets('tapping Cancel pops screen and cancels reading token', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'language_code': 'en'});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final router = GoRouter(
        initialLocation: '/reading',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('HOME_SENTINEL')),
          ),
          GoRoute(
            path: '/reading',
            builder: (_, _) => const ReadingProgressScreen(
              autoStart: false,
              previewSnapshot: ReadingProgressSnapshot(
                cleanStep: ReadingStepState.done,
                scriptStep: ReadingStepState.done,
                readStep: ReadingStepState.active,
                currentLine: 3,
                totalLines: 10,
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Line 3 of 10'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reading-cancel')));
      await tester.pumpAndSettle();
      expect(find.text('HOME_SENTINEL'), findsOneWidget);
    });
  });

  group('Extended ReceiptParser (VAT invoices, BIN, Rocket, Nagad, bKash)', () {
    test(
      'skips BIN line for merchant name and detects Rocket & Bangla Nagad',
      () {
        const parser = ReceiptParser();

        final rocketInvoice = parser.parse('''
Agora Gulshan
BIN: 001245678-0101
Date: 15/11/2026
Miniket Rice 5kg   380.00
VAT 5%   19.00
Grand Total   399.00
Paid via Rocket
''');
        expect(rocketInvoice.merchant.value, 'Agora Gulshan');
        expect(rocketInvoice.total.value, closeTo(399.0, 0.01));
        expect(rocketInvoice.tax.value, closeTo(19.0, 0.01));
        expect(rocketInvoice.paymentMethod.value, 'Rocket');

        final bnNagad = parser.parse('''
স্বপ্ন সুপার শপ
মূসক নিবন্ধন: ০০১২৩৪৫৬৭
সর্বমোট   ৫২০.০০ টাকা
পেমেন্ট: নগদ
''');
        expect(bnNagad.merchant.value, 'স্বপ্ন সুপার শপ');
        expect(bnNagad.total.value, closeTo(520.0, 0.01));
        expect(bnNagad.paymentMethod.value, 'Nagad');

        final bnCash = parser.parse('''
বিসমিল্লাহ মুদি স্টোর
সর্বমোট   ৩১০.০০ টাকা
পেমেন্ট: নগদ টাকা
''');
        expect(bnCash.paymentMethod.value, 'Cash');
      },
    );
  });
}

class _StubLineDetector implements LineDetector {
  const _StubLineDetector(this.boxes);

  final List<DetectedLineBox> boxes;

  @override
  Future<List<DetectedLineBox>> detect(img.Image greyPage) async => boxes;
}

class _StubLineRecognizer implements LineRecognizer {
  _StubLineRecognizer(this.id, this._outputs);

  @override
  final String id;
  final List<LineRecognition> _outputs;
  int _idx = 0;

  @override
  Future<LineRecognition> recognize(img.Image lineCrop) async {
    if (_outputs.isEmpty) {
      return LineRecognition(text: '', confidence: 0, engineId: id);
    }
    return _outputs[_idx++ % _outputs.length];
  }
}

class _CallbackLineRecognizer implements LineRecognizer {
  const _CallbackLineRecognizer(this.fn);

  final LineRecognition Function(img.Image) fn;

  @override
  String get id => 'callback';

  @override
  Future<LineRecognition> recognize(img.Image lineCrop) async => fn(lineCrop);
}
