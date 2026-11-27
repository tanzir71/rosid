import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:rosid/core/l10n/app_localizations.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/core/theme/app_theme.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/features/expenses/expenses_repository.dart';
import 'package:rosid/features/safety/lock_screen.dart';
import 'package:rosid/safety/app_lock_service.dart';
import 'package:rosid/safety/backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBiometricAuth implements BiometricAuthenticator {
  _FakeBiometricAuth({this.available = true, this.succeed = true});

  final bool available;
  final bool succeed;
  int calls = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate({required String reason}) async {
    calls++;
    return succeed;
  }
}

class _RecordingSecurityService extends PlatformSecurityService {
  final List<bool> states = [];

  @override
  Future<void> setSecure(bool enabled) async {
    states.add(enabled);
  }
}

class _InstantTestPinHasher extends PinHasher {
  const _InstantTestPinHasher();

  @override
  Future<String> hashPin(String pin) async => 'test-hash:$pin';

  @override
  Future<bool> verifyPin(String pin, String encodedHash) async =>
      encodedHash == 'test-hash:$pin';
}

void main() {
  group('Receipt items-add-up logic and CSV export', () {
    test('matches exact sum, matches sum + VAT, and flags mismatch', () {
      final exact = evaluateReceiptItemsSum(
        total: 1840.0,
        itemAmounts: const [420, 310, 260, 350, 280, 220],
      );
      expect(exact.itemCount, 6);
      expect(exact.itemsSum, closeTo(1840.0, 0.01));
      expect(exact.matchesTotal, isTrue);

      final withTax = evaluateReceiptItemsSum(
        total: 1050.0,
        itemAmounts: const [600, 400],
        tax: 50.0,
      );
      expect(withTax.matchesTotal, isTrue);

      final mismatch = evaluateReceiptItemsSum(
        total: 1840.0,
        itemAmounts: const [420, 310, 260],
      );
      expect(mismatch.itemCount, 3);
      expect(mismatch.itemsSum, closeTo(990.0, 0.01));
      expect(mismatch.matchesTotal, isFalse);
    });

    test('CSV export includes VAT and Paid with columns', () {
      final now = DateTime(2026, 11, 24);
      final csv = buildExpensesCsv([
        ExpenseReceiptRow(
          receipt: Receipt(
            id: 'r1',
            scanId: 's1',
            merchant: 'Shwapno, Banani',
            dateOfPurchase: now,
            total: 1840,
            currency: 'BDT',
            tax: 87.62,
            paymentMethod: 'Card',
            categoryId: 'cat_groceries',
            note: 'Monthly shop',
            fieldConfidenceJson: '{}',
          ),
          scan: Scan(
            id: 's1',
            type: 'receipt',
            kind: 'receipt',
            language: 'en',
            checkCount: 0,
            imagePath: '',
            ocrRawText: '',
            langHint: 'auto',
            createdAt: now,
            updatedAt: now,
          ),
          categoryName: 'Groceries',
          items: const [
            LineItem(
              id: 'li1',
              receiptId: 'r1',
              name: 'Rice',
              qty: 1,
              amount: 420,
            ),
          ],
        ),
      ]);
      expect(csv, contains('Date,Shop,Category,Total,VAT,Paid with,Currency'));
      expect(csv, contains('Shwapno, Banani'));
      expect(csv, contains('1840.00'));
      expect(csv, contains('87.62'));
      expect(csv, contains('Card'));
      expect(csv, contains('Rice'));
    });
  });

  group('PIN lock, timeout, FLAG_SECURE, and fake fingerprint', () {
    test(
      'PinHasher uses random salt, never stores plaintext, verifies PIN',
      () async {
        const hasher = PinHasher(memoryKiB: 1024, iterations: 1);
        final h1 = await hasher.hashPin('2580');
        final h2 = await hasher.hashPin('2580');

        expect(h1, isNot(equals(h2)));
        expect(h1.contains('2580'), isFalse);
        expect(await hasher.verifyPin('2580', h1), isTrue);
        expect(await hasher.verifyPin('1111', h1), isFalse);
      },
    );

    test('AppLockController locks on start, after 60s background, and toggles FLAG_SECURE', () async {
      SharedPreferences.setMockInitialValues({'language_code': 'en'});
      final prefs = await SharedPreferences.getInstance();
      final security = _RecordingSecurityService();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          pinHasherProvider.overrideWithValue(
            const PinHasher(memoryKiB: 1024, iterations: 1),
          ),
          platformSecurityServiceProvider.overrideWithValue(security),
          biometricAuthenticatorProvider.overrideWithValue(
            _FakeBiometricAuth(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final ctrl = container.read(appLockControllerProvider.notifier);
      await ctrl.enableWithPin('2580');
      expect(container.read(appLockControllerProvider).enabled, isTrue);
      expect(container.read(appLockControllerProvider).isLocked, isFalse);

      // Backgrounded for 20s (< 60s) -> stays unlocked
      final t0 = DateTime(2026, 11, 27, 10, 0, 0);
      ctrl.onAppBackgrounded(t0);
      await ctrl.onAppResumed(t0.add(const Duration(seconds: 20)));
      expect(container.read(appLockControllerProvider).isLocked, isFalse);

      // Backgrounded for 61s (>= 60s) -> locks and enables FLAG_SECURE
      ctrl.onAppBackgrounded(t0);
      await ctrl.onAppResumed(t0.add(const Duration(seconds: 61)));
      expect(container.read(appLockControllerProvider).isLocked, isTrue);
      expect(security.states.last, isTrue);

      // Wrong PIN stays locked
      expect(await ctrl.unlockWithPin('9999'), isFalse);
      expect(container.read(appLockControllerProvider).isLocked, isTrue);

      // Right PIN unlocks and clears FLAG_SECURE
      expect(await ctrl.unlockWithPin('2580'), isTrue);
      expect(container.read(appLockControllerProvider).isLocked, isFalse);
      expect(security.states.last, isFalse);

      // Fresh startup with saved prefs starts locked!
      final container2 = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          pinHasherProvider.overrideWithValue(
            const PinHasher(memoryKiB: 1024, iterations: 1),
          ),
          platformSecurityServiceProvider.overrideWithValue(security),
        ],
      );
      addTearDown(container2.dispose);
      expect(container2.read(appLockControllerProvider).isLocked, isTrue);
    });

    testWidgets(
      'AppLockScreen unlocks via fake fingerprint and flags wrong PIN',
      (tester) async {
        SharedPreferences.setMockInitialValues({'language_code': 'en'});
        final prefs = await SharedPreferences.getInstance();
        final fakeBio = _FakeBiometricAuth(available: true, succeed: true);
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            pinHasherProvider.overrideWithValue(const _InstantTestPinHasher()),
            biometricAuthenticatorProvider.overrideWithValue(fakeBio),
            platformSecurityServiceProvider.overrideWithValue(
              _RecordingSecurityService(),
            ),
          ],
        );
        addTearDown(container.dispose);

        final ctrl = container.read(appLockControllerProvider.notifier);
        await ctrl.enableWithPin('2580');
        await ctrl.lockNow();

        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

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
              home: const AppLockScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Enter wrong PIN 1111
        for (var i = 0; i < 4; i++) {
          await tester.tap(find.byKey(const ValueKey('pin-key-1')));
          await tester.pump();
        }
        await tester.tap(find.byKey(const ValueKey('app-lock-unlock-btn')));
        await tester.pumpAndSettle();
        expect(find.textContaining('Wrong PIN'), findsOneWidget);
        expect(container.read(appLockControllerProvider).isLocked, isTrue);

        // Tap fingerprint button -> fake biometric unlocks!
        await tester.tap(
          find.byKey(const ValueKey('app-lock-fingerprint-btn')),
        );
        await tester.pumpAndSettle();
        expect(fakeBio.calls, 1);
        expect(container.read(appLockControllerProvider).isLocked, isFalse);
      },
    );
  });

  group('Encrypted Backup round trip, wrong password, and truncated file', () {
    late Directory tempRoot;
    late Directory docsDir;
    late String dbPath;
    late BackupService backupService;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('rosid_m8_bk_');
      docsDir = Directory(p.join(tempRoot.path, 'docs'));
      await docsDir.create(recursive: true);
      dbPath = p.join(docsDir.path, 'rosid.sqlite');
      backupService = const BackupService(memoryKiB: 2048, iterations: 1);
    });

    tearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    Future<Map<String, String>> hashPrivateFiles(Directory docs) async {
      final out = <String, String>{};
      final rosidDir = Directory(p.join(docs.path, 'rosid'));
      if (!await rosidDir.exists()) return out;
      await for (final entity in rosidDir.list(recursive: true)) {
        if (entity is File) {
          final rel = p.relative(entity.path, from: rosidDir.path);
          final digest = await Sha256().hash(await entity.readAsBytes());
          out[rel] = base64Encode(digest.bytes);
        }
      }
      return out;
    }

    test('full round trip restores identical tables and file hashes; wrong password & truncated leave data untouched', () async {
      // Seed real database + private files.
      final scansDir = Directory(p.join(docsDir.path, 'rosid', 'scans'));
      final procDir = Directory(p.join(docsDir.path, 'rosid', 'processed'));
      await scansDir.create(recursive: true);
      await procDir.create(recursive: true);
      final imgFile = File(p.join(scansDir.path, 's1_0.jpg'));
      final procFile = File(p.join(procDir.path, 's1_0_clean.jpg'));
      await imgFile.writeAsBytes([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      await procFile.writeAsBytes([99, 98, 97, 96, 95, 94]);

      var db = AppDatabase.forTesting(NativeDatabase(File(dbPath)));
      final now = DateTime(2026, 11, 26, 12, 0);
      await db
          .into(db.scans)
          .insert(
            ScansCompanion.insert(
              id: 's1',
              type: 'document',
              kind: const Value('land'),
              imagePath: imgFile.path,
              ocrRawText: const Value('খতিয়ান নং ১২৪৫'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.scanPages)
          .insert(
            ScanPagesCompanion.insert(
              id: 'p1',
              scanId: 's1',
              imagePath: imgFile.path,
              processedPath: Value(procFile.path),
              pageIndex: 0,
            ),
          );
      await db
          .into(db.documents)
          .insert(
            DocumentsCompanion.insert(
              id: 'd1',
              scanId: 's1',
              title: 'খতিয়ান, বিরুলিয়া',
              body: const Value('খতিয়ান নং ১২৪৫'),
            ),
          );
      await db
          .into(db.names)
          .insert(
            NamesCompanion.insert(
              id: 'n1',
              bangla: 'বিরুলিয়া',
              english: 'Birulia',
              category: const Value('place'),
              confirmed: const Value(true),
            ),
          );
      await db
          .into(db.bundles)
          .insert(
            BundlesCompanion.insert(
              id: 'b1',
              title: 'Land papers',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.bundleItems)
          .insert(
            BundleItemsCompanion.insert(
              id: 'bi1',
              bundleId: 'b1',
              title: 'Khatian',
              itemOrder: 0,
              linkedScanId: const Value('s1'),
            ),
          );

      final origHashes = await hashPrivateFiles(docsDir);
      expect(origHashes.length, 2);

      // 1. Create encrypted backup.
      final backupPath = p.join(tempRoot.path, 'out.rosidbackup');
      final created = await backupService.createBackup(
        db: db,
        password: 'strong-pass-2026',
        outputFilePath: backupPath,
        appDocsDir: docsDir,
        tempDir: tempRoot,
      );
      expect(created.paperCount, 1);
      expect(File(backupPath).existsSync(), isTrue);

      // 2. Wipe database & files completely.
      await db.close();
      await File(dbPath).delete();
      await Directory(p.join(docsDir.path, 'rosid')).delete(recursive: true);

      // Seed a canary row to confirm wrong password & truncated file leave current data intact.
      db = AppDatabase.forTesting(NativeDatabase(File(dbPath)));
      await db
          .into(db.scans)
          .insert(
            ScansCompanion.insert(
              id: 'canary',
              type: 'document',
              imagePath: 'canary.jpg',
              createdAt: now,
              updatedAt: now,
            ),
          );

      // 3. Wrong password must fail cleanly and NOT touch canary!
      await expectLater(
        () => backupService.restoreBackup(
          backupFilePath: backupPath,
          password: 'wrong-password',
          targetDatabasePath: dbPath,
          targetAppDocsDir: docsDir,
          closeLiveDatabase: () async => db.close(),
          reopenLiveDatabase: () async {
            db = AppDatabase.forTesting(NativeDatabase(File(dbPath)));
          },
          tempDir: tempRoot,
        ),
        throwsA(isA<BackupWrongPasswordException>()),
      );
      expect((await db.select(db.scans).get()).single.id, 'canary');

      // 4. Truncated file must fail cleanly and NOT touch canary!
      final truncatedPath = p.join(tempRoot.path, 'trunc.rosidbackup');
      final fullBytes = await File(backupPath).readAsBytes();
      await File(truncatedPath)
          .writeAsBytes(fullBytes.sublist(0, fullBytes.length ~/ 2));
      await expectLater(
        () => backupService.restoreBackup(
          backupFilePath: truncatedPath,
          password: 'strong-pass-2026',
          targetDatabasePath: dbPath,
          targetAppDocsDir: docsDir,
          closeLiveDatabase: () async => db.close(),
          reopenLiveDatabase: () async {
            db = AppDatabase.forTesting(NativeDatabase(File(dbPath)));
          },
          tempDir: tempRoot,
        ),
        throwsA(
          anyOf(
            isA<BackupWrongPasswordException>(),
            isA<BackupFormatException>(),
          ),
        ),
      );
      expect((await db.select(db.scans).get()).single.id, 'canary');

      // 5. Corrupt magic header fails with BackupFormatException and leaves canary untouched!
      final badHeaderPath = p.join(tempRoot.path, 'bad.rosidbackup');
      await File(badHeaderPath).writeAsBytes(List<int>.filled(128, 0x42));
      await expectLater(
        () => backupService.restoreBackup(
          backupFilePath: badHeaderPath,
          password: 'strong-pass-2026',
          targetDatabasePath: dbPath,
          targetAppDocsDir: docsDir,
          closeLiveDatabase: () async => db.close(),
          reopenLiveDatabase: () async {
            db = AppDatabase.forTesting(NativeDatabase(File(dbPath)));
          },
          tempDir: tempRoot,
        ),
        throwsA(isA<BackupFormatException>()),
      );
      expect((await db.select(db.scans).get()).single.id, 'canary');

      // 6. Valid restore replaces canary with original tables and identical file hashes!
      final restored = await backupService.restoreBackup(
        backupFilePath: backupPath,
        password: 'strong-pass-2026',
        targetDatabasePath: dbPath,
        targetAppDocsDir: docsDir,
        closeLiveDatabase: () async => db.close(),
        reopenLiveDatabase: () async {
          db = AppDatabase.forTesting(NativeDatabase(File(dbPath)));
        },
        tempDir: tempRoot,
      );
      expect(restored.paperCount, 1);
      expect(restored.restoredFiles, 2);

      final scans = await db.select(db.scans).get();
      final docs = await db.select(db.documents).get();
      final names = await db.select(db.names).get();
      final bundles = await db.select(db.bundles).get();
      final bundleItems = await db.select(db.bundleItems).get();

      expect(scans.single.id, 's1');
      expect(docs.single.title, 'খতিয়ান, বিরুলিয়া');
      expect(names.single.english, 'Birulia');
      expect(bundles.single.title, 'Land papers');
      expect(bundleItems.single.linkedScanId, 's1');

      final restoredHashes = await hashPrivateFiles(docsDir);
      expect(restoredHashes, equals(origHashes));

      await db.close();
    });
  });
}
