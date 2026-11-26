import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:rosid/core/l10n/app_localizations.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/core/theme/app_theme.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/database/database_provider.dart';
import 'package:rosid/data/files/private_file_store.dart';
import 'package:rosid/features/capture/adjust_page_screen.dart';
import 'package:rosid/features/capture/fake_capture_source.dart';
import 'package:rosid/features/capture/scan_camera_screen.dart';
import 'package:rosid/features/capture/scan_controller.dart';
import 'package:rosid/ocr/preprocess/document_quad.dart';
import 'package:rosid/ocr/preprocess/image_cleaner.dart';
import 'package:shared_preferences/shared_preferences.dart';

Uint8List _makePaperJpeg({
  required double left,
  required double top,
  required double right,
  required double bottom,
}) {
  const w = 320;
  const h = 240;
  final im = img.Image(width: w, height: h);
  img.fill(im, color: img.ColorRgb8(42, 42, 42));
  img.fillRect(
    im,
    x1: (left * w).round(),
    y1: (top * h).round(),
    x2: (right * w).round(),
    y2: (bottom * h).round(),
    color: img.ColorRgb8(224, 222, 214),
  );
  // Dark ink lines so Laplacian variance is high if needed
  for (var y = (top * h).round() + 18; y < (bottom * h).round() - 18; y += 16) {
    img.fillRect(
      im,
      x1: (left * w).round() + 16,
      y1: y,
      x2: (right * w).round() - 16,
      y2: y + 3,
      color: img.ColorRgb8(38, 38, 44),
    );
  }
  return Uint8List.fromList(img.encodeJpg(im, quality: 88));
}

void main() {
  group('V2ScanController unit tests (quad, rotate, reorder, filter)', () {
    test('edits quad, rotates, changes filter, reorders without modifying original path', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final tempDir = await Directory.systemTemp.createTemp('rosid_m2_ctrl_');
      addTearDown(() => tempDir.delete(recursive: true));

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          privateFileStoreProvider.overrideWithValue(
            PrivateFileStore(rootDirectory: tempDir),
          ),
        ],
      );
      addTearDown(container.dispose);

      final ctrl = container.read(v2ScanProvider.notifier);
      ctrl.startSession(V2ScanMode.document);
      final jpg = _makePaperJpeg(
        left: 0.15,
        top: 0.12,
        right: 0.85,
        bottom: 0.88,
      );
      final p1 = await ctrl.addCapturedBytes(jpg);
      final p2 = await ctrl.addCapturedBytes(jpg);
      expect(p1, isNotNull);
      expect(p2, isNotNull);

      // Select first page and update quad, rotation, filter.
      ctrl.selectPage(0);
      const customQuad = DocumentQuad(
        topLeft: NormalizedPoint(0.12, 0.14),
        topRight: NormalizedPoint(0.88, 0.13),
        bottomRight: NormalizedPoint(0.87, 0.89),
        bottomLeft: NormalizedPoint(0.11, 0.87),
      );
      await ctrl.updateCurrentQuad(customQuad);
      await ctrl.rotateCurrentPage();
      await ctrl.setCurrentFilter(PageFilterMode.grey);

      final updated = container.read(v2ScanProvider);
      expect(updated.pages[0].quad.topLeft.x, closeTo(0.12, 0.001));
      expect(updated.pages[0].rotationQuarterTurns, 1);
      expect(updated.pages[0].filter, PageFilterMode.grey);
      expect(updated.pages[0].originalPath, p1!.originalPath);

      // Reorder page 0 after page 1.
      await ctrl.reorderPages(0, 2);
      final reordered = container.read(v2ScanProvider);
      expect(reordered.pages[0].pageId, p2!.pageId);
      expect(reordered.pages[1].pageId, p1.pageId);

      // Verify persisted metadata in SQLite scan_pages.
      final rows = await db.select(db.scanPages).get();
      final p1Row = rows.firstWhere((r) => r.id == p1.pageId);
      expect(p1Row.rotation, 90);
      expect(p1Row.filter, 'grey');
      expect(p1Row.pageIndex, 1);
      expect(p1Row.quadJson, isNotNull);
      expect(p1Row.imagePath, p1.originalPath);
    });
  });

  group('AdjustPageScreen widget test (magnifier, rotate, filter)', () {
    testWidgets(
      'shows MagnifierLoupe while dragging a corner and hides on release',
      (tester) async {
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

        container.read(v2ScanProvider.notifier).setPagesForTesting([
          const CapturedPageDraft(
            pageId: 'p-1',
            originalPath: '/unused/p1.jpg',
            quad: DocumentQuad(
              topLeft: NormalizedPoint(0.15, 0.15),
              topRight: NormalizedPoint(0.85, 0.15),
              bottomRight: NormalizedPoint(0.85, 0.85),
              bottomLeft: NormalizedPoint(0.15, 0.85),
            ),
          ),
          const CapturedPageDraft(
            pageId: 'p-2',
            originalPath: '/unused/p2.jpg',
          ),
        ]);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.light(),
              locale: const Locale('en'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const AdjustPageScreen(
                previewPageWidget: ColoredBox(color: Color(0xFFF5F3EA)),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Page 1 of 2'), findsOneWidget);
        expect(find.byKey(const ValueKey('adjust-magnifier')), findsNothing);

        final canvasFinder = find.byKey(const ValueKey('adjust-quad-canvas'));
        final topLeftCanvas = tester.getTopLeft(canvasFinder);
        final canvasSize = tester.getSize(canvasFinder);
        final cornerPos = Offset(
          topLeftCanvas.dx + canvasSize.width * 0.15,
          topLeftCanvas.dy + canvasSize.height * 0.15,
        );

        final gesture = await tester.startGesture(cornerPos);
        await tester.pump();
        await gesture.moveBy(const Offset(24, 18));
        await tester.pump();

        expect(find.byKey(const ValueKey('adjust-magnifier')), findsOneWidget);
        expect(
          container.read(v2ScanProvider).pages.first.quad.topLeft.x,
          greaterThan(0.16),
        );

        await gesture.up();
        await tester.pump();
        expect(find.byKey(const ValueKey('adjust-magnifier')), findsNothing);

        // Tap Rotate and Grey filter
        await tester.tap(find.byKey(const ValueKey('adjust-rotate')));
        await tester.pump();
        expect(
          container.read(v2ScanProvider).pages.first.rotationQuarterTurns,
          1,
        );

        await tester.tap(find.byKey(const ValueKey('adjust-filter-grey')));
        await tester.pump();
        expect(
          container.read(v2ScanProvider).pages.first.filter,
          PageFilterMode.grey,
        );
      },
    );
  });

  group('ScanCameraScreen fake-camera auto-capture test', () {
    testWidgets(
      'does not auto-capture while moving, fires auto-capture once steady',
      (tester) async {
        SharedPreferences.setMockInitialValues({'language_code': 'en'});
        final prefs = await SharedPreferences.getInstance();
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final tempDir = Directory.systemTemp.createTempSync('rosid_m2_cam_');
        addTearDown(() {
          if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
        });

        final streamCtrl = StreamController<CaptureFrame>.broadcast();
        addTearDown(streamCtrl.close);
        final steadyJpg = _makePaperJpeg(
          left: 0.15,
          top: 0.12,
          right: 0.85,
          bottom: 0.88,
        );
        final manualSource = _ControlledCaptureSource(
          stream: streamCtrl.stream,
          stillBytes: steadyJpg,
        );

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWithValue(db),
            privateFileStoreProvider.overrideWithValue(
              PrivateFileStore(rootDirectory: tempDir),
            ),
            fakeCaptureSourceProvider.overrideWithValue(manualSource),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.light(),
              locale: const Locale('en'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const ScanCameraScreen(
                initialMode: V2ScanMode.document,
                initializeCamera: false,
                useBackgroundIsolate: false,
              ),
            ),
          ),
        );
        await tester.pump();

        // Feed moving frames (large corner shift each time) -> must NOT capture.
        for (var i = 0; i < 4; i++) {
          final shift = i * 0.06;
          streamCtrl.add(
            CaptureFrame(
              bytes: _makePaperJpeg(
                left: 0.08 + shift,
                top: 0.12,
                right: 0.68 + shift,
                bottom: 0.86,
              ),
              width: 320,
              height: 240,
            ),
          );
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 140)),
          );
          await tester.pump();
        }
        expect(container.read(v2ScanProvider).pages, isEmpty);

        // Now feed steady identical frames over > 1200 ms -> MUST auto-capture.
        for (var i = 0; i < 16; i++) {
          streamCtrl.add(
            CaptureFrame(
              bytes: steadyJpg,
              width: 320,
              height: 240,
              isSteady: true,
            ),
          );
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 110)),
          );
          await tester.pump();
          if (container.read(v2ScanProvider).pages.isNotEmpty) break;
        }
        // Pump real async + microtasks alternately so disk/DB writes settle.
        for (var k = 0; k < 6; k++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump();
        }
        expect(find.text('Edges found. Hold steady'), findsOneWidget);
        expect(container.read(v2ScanProvider).pages.length, 1);
      },
    );
  });
}

class _ControlledCaptureSource implements CaptureFrameSource {
  _ControlledCaptureSource({required this.stream, required this.stillBytes});

  final Stream<CaptureFrame> stream;
  final Uint8List stillBytes;

  @override
  Stream<CaptureFrame> get frames => stream;

  @override
  Future<Uint8List> captureStill() async => stillBytes;

  @override
  Future<void> dispose() async {}
}
