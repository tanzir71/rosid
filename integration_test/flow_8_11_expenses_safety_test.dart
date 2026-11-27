import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:rosid/app.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/data/database/database_provider.dart';
import 'package:rosid/data/files/private_file_store.dart';
import 'package:rosid/features/capture/fake_capture_source.dart';
import 'package:rosid/features/capture/scan_camera_screen.dart';
import 'package:rosid/features/expenses/expenses_repository.dart';
import 'package:rosid/features/safety/backup_screen.dart';
import 'package:rosid/ocr/models/ocr_models.dart';
import 'package:rosid/ocr/pipeline/reading_interfaces.dart';
import 'package:rosid/ocr/pipeline/rosid_reading_pipeline.dart';
import 'package:rosid/safety/app_lock_service.dart';
import 'package:rosid/safety/backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Uint8List _makeReceiptJpeg() {
  final im = img.Image(width: 320, height: 480);
  img.fill(im, color: img.ColorRgb8(245, 245, 240));
  img.fillRect(
    im,
    x1: 30,
    y1: 30,
    x2: 290,
    y2: 450,
    color: img.ColorRgb8(255, 255, 255),
  );
  for (var y = 60; y < 420; y += 36) {
    img.fillRect(
      im,
      x1: 50,
      y1: y,
      x2: 270,
      y2: y + 8,
      color: img.ColorRgb8(40, 40, 46),
    );
  }
  return Uint8List.fromList(img.encodeJpg(im, quality: 88));
}

class _StubReceiptPipeline implements ReadingPipeline {
  @override
  Future<ReadingPageResult> readPage({
    required Uint8List greyImageBytes,
    required int pageIndex,
    void Function(ReadingProgressEvent event)? onProgress,
    ReadingCancelToken? cancelToken,
  }) async {
    onProgress?.call(
      const ReadingProgressEvent(
        stage: ReadingStage.readingLines,
        currentLine: 1,
        totalLines: 7,
      ),
    );
    const lines = [
      'Shwapno Super Shop',
      'Date: 24/11/2026',
      'Rice 5kg 550.00',
      'Soybean Oil 2L 450.00',
      'VAT 5% 50.00',
      'Paid by bKash',
      'Grand Total 1050.00',
    ];
    return ReadingPageResult(
      pageIndex: pageIndex,
      lines: [
        for (var i = 0; i < lines.length; i++)
          RecognizedLine(
            pageIndex: pageIndex,
            lineOrder: i,
            text: lines[i],
            originalText: lines[i],
            box: DetectedLineBox.fromRect(
              OcrRect(
                left: 0.08,
                top: 0.08 + i * 0.11,
                right: 0.90,
                bottom: 0.16 + i * 0.11,
              ),
            ),
            confidence: 0.96,
            script: 'en',
            engineId: 'fixture',
          ),
      ],
      hasHandwriting: false,
      elapsedMs: 12,
      engineSummary: 'fixture',
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Flows 8, 9, 10 & 11: Expenses + CSV, App lock PIN, Backup/Wipe/Restore, Bangla+Dark',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await prefs.setBool('onboarding_complete', true);
      await prefs.setString('language_code', 'en');
      await prefs.setBool('expense_tracking_enabled', false);
      await prefs.setBool('app_lock_enabled', false);

      final tmpDir = await getTemporaryDirectory();
      final receiptBytes = _makeReceiptJpeg();

      final fakeSource = FakeCaptureSource(
        sequence: [
          for (var i = 0; i < 6; i++)
            CaptureFrame(
              bytes: receiptBytes,
              width: 320,
              height: 480,
              isSteady: false,
            ),
        ],
        frameInterval: const Duration(milliseconds: 120),
      );
      addTearDown(fakeSource.dispose);

      final savedBackupPath = p.join(tmpDir.path, 'flow10_test.rosidbackup');
      if (await File(savedBackupPath).exists()) {
        await File(savedBackupPath).delete();
      }

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          fakeCaptureSourceProvider.overrideWithValue(fakeSource),
          readingPipelineProvider.overrideWithValue(_StubReceiptPipeline()),
          pinHasherProvider.overrideWithValue(
            const PinHasher(memoryKiB: 2048, iterations: 1),
          ),
          backupServiceProvider.overrideWithValue(
            const BackupService(memoryKiB: 2048, iterations: 1),
          ),
          backupIoHooksProvider.overrideWithValue(
            BackupIoHooks(
              saveOverride: (tempPath, _) async {
                await File(tempPath).copy(savedBackupPath);
                return savedBackupPath;
              },
              pickOverride: () async => savedBackupPath,
            ),
          ),
        ],
      );

      // Clean DB state before starting
      final initDb = container.read(databaseProvider);
      await initDb.delete(initDb.scans).go();
      await initDb.delete(initDb.bundles).go();
      await container.read(privateFileStoreProvider).deleteAllAppData();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const RosidApp(),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // ==================== FLOW 8: Expenses ====================
      await tester.tap(find.byKey(const ValueKey('home-settings-button')));
      await tester.pumpAndSettle();
      final expToggle = find.byKey(const ValueKey('settings-expenses-toggle'));
      await tester.scrollUntilVisible(expToggle, 200);
      await tester.tap(expToggle);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('rosid-top-bar-back')));
      await tester.pumpAndSettle();

      // Scan a receipt via the Receipt shortcut on Home
      await tester.tap(find.text('Receipt').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('scan-shutter')));
      // Receipt mode auto-navigates straight to AdjustPageScreen!
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 200));
        if (find
            .byKey(const ValueKey('adjust-read-text'))
            .evaluate()
            .isNotEmpty) {
          break;
        }
      }
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('adjust-read-text')));

      // Wait for cleaning + OCR + receipt parsing to land on Check Receipt screen
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 200));
        if (find
            .byKey(const ValueKey('check-receipt-total-value'))
            .evaluate()
            .isNotEmpty) {
          break;
        }
      }
      await tester.pumpAndSettle();

      // Lands on Check Receipt screen with parsed total matching fixture (৳1,050.00)
      expect(
        find.byKey(const ValueKey('check-receipt-total-value')),
        findsOneWidget,
      );
      expect(find.textContaining('1,050.00'), findsOneWidget);

      // Save receipt
      await tester.tap(find.byKey(const ValueKey('check-receipt-save')));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Open Expenses tab & verify month total updated
      await tester.tap(find.text('Expenses').last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('expenses-month-total')),
        findsOneWidget,
      );
      expect(find.textContaining('1,050'), findsWidgets);

      // Verify CSV generation for the month
      final csvRes = await container
          .read(expensesRepositoryProvider)
          .writeMonthCsvExport(DateTime(2026, 11, 1), languageCode: 'en');
      expect(File(csvRes.filePath).existsSync(), isTrue);
      expect(csvRes.csvContent, contains('Shwapno Super Shop'));
      expect(csvRes.csvContent, contains('1050.00'));
      expect(csvRes.csvContent, contains('50.00'));
      expect(csvRes.csvContent, contains('bKash'));

      // ==================== FLOW 9: App lock ====================
      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-settings-button')));
      await tester.pumpAndSettle();

      final lockToggle = find.byKey(const ValueKey('settings-applock-toggle'));
      await tester.scrollUntilVisible(lockToggle, 200);
      await tester.tap(lockToggle);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('pin-setup-first')),
        '2580',
      );
      await tester.enterText(
        find.byKey(const ValueKey('pin-setup-confirm')),
        '2580',
      );
      await tester.tap(find.byKey(const ValueKey('pin-setup-save')));
      // Wait for Argon2id PIN hashing to finish and enable App lock
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 150));
        if (container.read(appLockControllerProvider).enabled) break;
      }
      await tester.pumpAndSettle();
      expect(container.read(appLockControllerProvider).enabled, isTrue);

      // Simulate background > 60s and resume -> AppLockScreen appears
      final lockCtrl = container.read(appLockControllerProvider.notifier);
      final t0 = DateTime.now().subtract(const Duration(seconds: 90));
      lockCtrl.onAppBackgrounded(t0);
      await lockCtrl.onAppResumed(DateTime.now());
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('app-lock-screen')), findsOneWidget);

      // Wrong PIN 1111 stays locked
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const ValueKey('pin-key-1')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const ValueKey('app-lock-unlock-btn')));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 150));
        if (find.textContaining('Wrong PIN').evaluate().isNotEmpty) break;
      }
      await tester.pumpAndSettle();
      expect(find.textContaining('Wrong PIN'), findsOneWidget);

      // Correct PIN 2580 unlocks
      for (final d in const ['2', '5', '8', '0']) {
        await tester.tap(find.byKey(ValueKey('pin-key-$d')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const ValueKey('app-lock-unlock-btn')));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 150));
        if (!container.read(appLockControllerProvider).isLocked) break;
      }
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('app-lock-screen')), findsNothing);

      // Disable app lock so Flow 10/11 continue cleanly
      await lockCtrl.disable();
      await tester.pumpAndSettle();

      // ==================== FLOW 10: Backup -> Delete all -> Restore ====================
      final backupRow = find.byKey(const ValueKey('settings-backup-row'));
      await tester.scrollUntilVisible(backupRow, 200);
      await tester.tap(backupRow);
      await tester.pumpAndSettle();

      // Make backup file with password
      await tester.tap(find.byKey(const ValueKey('backup-make-btn')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('backup-password-input')),
        'rosid2026',
      );
      await tester.enterText(
        find.byKey(const ValueKey('backup-password-confirm')),
        'rosid2026',
      );
      await tester.tap(find.byKey(const ValueKey('backup-password-submit')));
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 200));
        if (File(savedBackupPath).existsSync()) break;
      }
      await tester.pumpAndSettle();
      expect(File(savedBackupPath).existsSync(), isTrue);

      // Go back to Settings and Delete everything
      await tester.tap(find.byKey(const ValueKey('rosid-top-bar-back')));
      await tester.pumpAndSettle();
      final deleteRow = find.byKey(const ValueKey('settings-delete-all'));
      await tester.scrollUntilVisible(deleteRow, 300);
      await tester.tap(deleteRow);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-delete-confirm')));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify scans table is now empty
      final emptyDb = container.read(databaseProvider);
      expect((await emptyDb.select(emptyDb.scans).get()).length, 0);

      // Open Back up and move -> Bring papers from backup file
      await tester.scrollUntilVisible(backupRow, -300);
      await tester.tap(backupRow);
      await tester.pumpAndSettle();
      // Dismiss any lingering "Saved" snackbar covering the bottom restore button.
      ScaffoldMessenger.of(
        tester.element(find.byKey(const ValueKey('backup-restore-btn'))),
      ).clearSnackBars();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('backup-restore-btn')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('backup-password-input')),
        'rosid2026',
      );
      await tester.tap(find.byKey(const ValueKey('backup-password-submit')));
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 200));
        if (find.textContaining('Papers restored').evaluate().isNotEmpty) break;
      }
      await tester.pumpAndSettle();

      // Verify receipt paper is back in restored database!
      final restoredDb = container.read(databaseProvider);
      final restoredReceipts = await restoredDb
          .select(restoredDb.receipts)
          .get();
      expect(restoredReceipts.length, 1);
      expect(restoredReceipts.single.merchant, 'Shwapno Super Shop');
      expect(restoredReceipts.single.total, closeTo(1050.0, 0.01));

      // ==================== FLOW 11: Bangla + Dark theme ====================
      await tester.tap(find.byKey(const ValueKey('rosid-top-bar-back')));
      await tester.pumpAndSettle();
      final langBtn = find.byKey(const ValueKey('settings-language-toggle'));
      await tester.scrollUntilVisible(langBtn, -300);
      await tester.tap(langBtn);
      await tester.pumpAndSettle();

      final themeRow = find.byKey(const ValueKey('settings-theme-row'));
      await tester.tap(themeRow);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('theme-option-dark')));
      await tester.pumpAndSettle();

      // Verify settings switched to বাংলা and Dark theme
      expect(container.read(appSettingsProvider).languageCode, 'bn');
      expect(container.read(appSettingsProvider).themeMode, ThemeMode.dark);
      expect(find.text('সেটিংস'), findsOneWidget);

      // Return to Home in বাংলা + Dark and verify Bangla UI renders
      await tester.tap(find.byKey(const ValueKey('rosid-top-bar-back')));
      await tester.pumpAndSettle();
      expect(find.text('কী স্ক্যান করবেন?'), findsOneWidget);

      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      container.dispose();
    },
  );
}
