import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:drift/drift.dart';
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
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/database/database_provider.dart';
import 'package:rosid/data/repositories/record_repository.dart';
import 'package:rosid/data/repositories/scan_repository.dart';
import 'package:rosid/data/repositories/startup_cleanup_repository.dart';
import 'package:rosid/features/home/home_screen.dart';
import 'package:rosid/features/settings/settings_screen.dart';
import 'package:rosid/features/shared/app_shell.dart';
import 'package:rosid/features/welcome/welcome_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/golden_fonts.dart';

Future<AppDatabase> _seedSampleDatabase({required bool bangla}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final scans = ScanRepository(db);
  final records = RecordRepository(db);
  final now = DateTime.now();

  await scans.createScan(
    id: 'khatian-1',
    mode: ScanMode.document,
    imagePath: '/sample/khatian.jpg',
    langHint: 'bn',
    createdAt: now,
  );
  await (db.update(db.scans)..where((s) => s.id.equals('khatian-1'))).write(
    const ScansCompanion(kind: Value('land'), checkCount: Value(3)),
  );
  await records.saveDocument(
    scanId: 'khatian-1',
    title: 'খতিয়ান, বিরুলিয়া',
    body: 'খতিয়ান নং ১২৪৫, মৌজা: বিরুলিয়া',
    tags: const [],
  );

  await scans.createScan(
    id: 'birth-1',
    mode: ScanMode.document,
    imagePath: '/sample/birth.jpg',
    langHint: 'bn',
    createdAt: now.subtract(const Duration(minutes: 5)),
  );
  await (db.update(db.scans)..where((s) => s.id.equals('birth-1'))).write(
    const ScansCompanion(kind: Value('certificate'), checkCount: Value(0)),
  );
  await records.saveDocument(
    scanId: 'birth-1',
    title: 'জন্ম নিবন্ধন সনদ',
    body: 'জন্ম নিবন্ধন সনদ',
    tags: const [],
  );

  await db
      .into(db.bundles)
      .insert(
        BundlesCompanion.insert(
          id: 'b-visa',
          title: bangla
              ? 'যুক্তরাজ্য স্টুডেন্ট ভিসা, ফারহানা'
              : 'UK student visa, Farhana',
          purpose: const Value('visa'),
          createdAt: now,
          updatedAt: now,
        ),
      );
  for (var i = 0; i < 11; i++) {
    await db
        .into(db.bundleItems)
        .insert(
          BundleItemsCompanion.insert(
            id: 'bi-$i',
            bundleId: 'b-visa',
            title: i == 7
                ? (bangla
                      ? 'ভূমি উন্নয়ন করের দাখিলা এখনও নেই'
                      : 'Land tax receipt (দাখিলা) is still missing')
                : 'Item $i',
            itemOrder: i,
            linkedScanId: i < 7 ? const Value('birth-1') : const Value.absent(),
          ),
        );
  }
  return db;
}

Widget _wrapScreen({
  required Widget child,
  required SharedPreferences prefs,
  required AppDatabase db,
  required ThemeMode themeMode,
  required Locale locale,
}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      databaseProvider.overrideWithValue(db),
      startupCleanupProvider.overrideWith((ref) async => 0),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
}

void main() {
  setUpAll(loadRosidTestFonts);

  Future<void> pumpPhone(
    WidgetTester tester,
    Widget widget,
    String goldenName,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$goldenName.png'),
    );
  }

  testWidgets('M1 screen golden: first-run-1-language', (tester) async {
    SharedPreferences.setMockInitialValues({'language_code': 'bn'});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await pumpPhone(
      tester,
      _wrapScreen(
        child: const WelcomeLanguageScreen(),
        prefs: prefs,
        db: db,
        themeMode: ThemeMode.light,
        locale: const Locale('en'),
      ),
      'm1_first_run_1_language',
    );
  });

  testWidgets('M1 screen golden: first-run-2-what-you-need', (tester) async {
    SharedPreferences.setMockInitialValues({'language_code': 'en'});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await pumpPhone(
      tester,
      _wrapScreen(
        child: const WelcomePurposeScreen(),
        prefs: prefs,
        db: db,
        themeMode: ThemeMode.light,
        locale: const Locale('en'),
      ),
      'm1_first_run_2_what_you_need',
    );
  });

  testWidgets('M1 screen golden: first-run-3-camera', (tester) async {
    SharedPreferences.setMockInitialValues({'language_code': 'en'});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await pumpPhone(
      tester,
      _wrapScreen(
        child: const WelcomeCameraScreen(),
        prefs: prefs,
        db: db,
        themeMode: ThemeMode.light,
        locale: const Locale('en'),
      ),
      'm1_first_run_3_camera',
    );
  });

  testWidgets('M1 screen golden: home', (tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
      'language_code': 'en',
      'expense_tracking_enabled': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final db = await _seedSampleDatabase(bangla: false);
    addTearDown(db.close);

    await pumpPhone(
      tester,
      _wrapScreen(
        child: const AppShell(location: '/', child: HomeScreen()),
        prefs: prefs,
        db: db,
        themeMode: ThemeMode.light,
        locale: const Locale('en'),
      ),
      'm1_home',
    );
  });

  testWidgets('M1 screen golden: home-bn', (tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
      'language_code': 'bn',
      'expense_tracking_enabled': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final db = await _seedSampleDatabase(bangla: true);
    addTearDown(db.close);

    await pumpPhone(
      tester,
      _wrapScreen(
        child: const AppShell(location: '/', child: HomeScreen()),
        prefs: prefs,
        db: db,
        themeMode: ThemeMode.light,
        locale: const Locale('bn'),
      ),
      'm1_home_bn',
    );
  });

  testWidgets('M1 screen golden: home-dark', (tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
      'language_code': 'en',
      'expense_tracking_enabled': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final db = await _seedSampleDatabase(bangla: false);
    addTearDown(db.close);

    await pumpPhone(
      tester,
      _wrapScreen(
        child: const AppShell(location: '/', child: HomeScreen()),
        prefs: prefs,
        db: db,
        themeMode: ThemeMode.dark,
        locale: const Locale('en'),
      ),
      'm1_home_dark',
    );
  });

  testWidgets('M1 screen golden: settings', (tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
      'language_code': 'en',
      'expense_tracking_enabled': true,
      'app_lock_enabled': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await pumpPhone(
      tester,
      _wrapScreen(
        child: const SettingsScreen(),
        prefs: prefs,
        db: db,
        themeMode: ThemeMode.light,
        locale: const Locale('en'),
      ),
      'm1_settings',
    );
  });
}
