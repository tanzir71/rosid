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
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/database/database_provider.dart';
import 'package:rosid/data/repositories/record_repository.dart';
import 'package:rosid/data/repositories/scan_repository.dart';
import 'package:rosid/export/export_models.dart';
import 'package:rosid/features/export/cover_detail_screen.dart';
import 'package:rosid/features/export/export_id_card_screen.dart';
import 'package:rosid/features/export/export_preview_screen.dart';
import 'package:rosid/features/export/export_saved_screen.dart';
import 'package:rosid/features/export/paper_export_options_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/golden_fonts.dart';

Future<AppDatabase> _seedExportPaper() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final scans = ScanRepository(db);
  final records = RecordRepository(db);
  await scans.createScan(
    id: 'khatian-m6',
    mode: ScanMode.document,
    imagePath: '/sample/khatian.jpg',
    langHint: 'bn',
    createdAt: DateTime(2026, 11, 26),
  );
  await (db.update(db.scans)..where((s) => s.id.equals('khatian-m6'))).write(
    const ScansCompanion(kind: Value('land')),
  );
  await records.saveDocument(
    scanId: 'khatian-m6',
    title: 'খতিয়ান, বিরুলিয়া',
    body: 'খতিয়ান নং ১২৪৫\nজেলা: ঢাকা, উপজেলা: সাভার',
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
    String goldenName,
  ) async {
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

  testWidgets('M6 screen golden: export-options', (tester) async {
    SharedPreferences.setMockInitialValues({'language_code': 'en'});
    final prefs = await SharedPreferences.getInstance();
    final db = await _seedExportPaper();
    addTearDown(db.close);

    await pumpPhone(
      tester,
      db,
      prefs,
      const PaperExportOptionsScreen(
        scanId: 'khatian-m6',
        previewConfig: PaperExportConfig(
          includeScan: true,
          includeEnglish: true,
          includeBangla: false,
          fileType: ExportFileType.pdf,
          pageSize: ExportPageSize.a4,
          maxSizeBytes: 2 * 1024 * 1024,
          watermarkEnabled: true,
          watermarkText: 'For visa application only',
          watermarkDateText: '26 Nov 2026',
          includeTranslatorPage: true,
        ),
        previewFileName: 'Khatian-Birulia-English.pdf',
        previewSizeSummary: '3 pages, 1.4 MB',
      ),
      'm6_export_options',
    );
  });

  testWidgets('M6 screen golden: export-preview-certification', (tester) async {
    SharedPreferences.setMockInitialValues({'language_code': 'en'});
    final prefs = await SharedPreferences.getInstance();
    final db = await _seedExportPaper();
    addTearDown(db.close);

    await pumpPhone(
      tester,
      db,
      prefs,
      const ExportPreviewScreen(
        scanId: 'khatian-m6',
        initialPage: 1,
        previewWatermark: 'For visa application only',
        previewEnglishLines: [
          'Directorate of Land Records and Surveys',
          'Khatian No. 1245',
          'District: Dhaka               Upazila: Savar',
          'Mouza: Birulia                 J.L. No. 35',
          'Owner: MD ABDUR RAHMAN',
          'Father: Late Abdul Karim',
          'Plot (Dag) No. 302        Class: Homestead',
          'Area: 12.50 decimals',
        ],
      ),
      'm6_export_preview_certification',
    );
  });

  testWidgets('M6 screen golden: export-id-one-page', (tester) async {
    SharedPreferences.setMockInitialValues({'language_code': 'en'});
    final prefs = await SharedPreferences.getInstance();
    final db = await _seedExportPaper();
    addTearDown(db.close);

    await pumpPhone(
      tester,
      db,
      prefs,
      const ExportIdCardScreen(
        scanId: 'khatian-m6',
        previewDateText: '26 Nov 2026',
        previewWatermarkOn: true,
      ),
      'm6_export_id_one_page',
    );
  });

  testWidgets('M6 screen golden: export-saved', (tester) async {
    SharedPreferences.setMockInitialValues({'language_code': 'en'});
    final prefs = await SharedPreferences.getInstance();
    final db = await _seedExportPaper();
    addTearDown(db.close);

    await pumpPhone(
      tester,
      db,
      prefs,
      const ExportSavedScreen(
        scanId: 'khatian-m6',
        previewLocation: 'Downloads, Rosid, Khatian-Birulia-English.pdf',
        previewSummary: '3 pages, 1.4 MB',
        previewBundleName: 'UK student visa, Farhana',
      ),
      'm6_export_saved',
    );
  });

  testWidgets('M6 screen golden: safety-cover-detail', (tester) async {
    SharedPreferences.setMockInitialValues({'language_code': 'en'});
    final prefs = await SharedPreferences.getInstance();
    final db = await _seedExportPaper();
    addTearDown(db.close);

    await pumpPhone(
      tester,
      db,
      prefs,
      const CoverDetailScreen(
        scanId: 'khatian-m6',
        previewRegions: [
          CoverRegion(
            pageIndex: 0,
            left: 0.12,
            top: 0.72,
            right: 0.88,
            bottom: 0.86,
            style: CoverStyle.blackBar,
          ),
        ],
      ),
      'm6_safety_cover_detail',
    );
  });
}
