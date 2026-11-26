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
import 'package:rosid/core/widgets/rosid_navigation.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/database/database_provider.dart';
import 'package:rosid/data/repositories/bundle_repository.dart';
import 'package:rosid/features/bundles/bundle_checklist_screen.dart';
import 'package:rosid/features/bundles/bundle_export_screen.dart';
import 'package:rosid/features/bundles/bundles_screen.dart';
import 'package:rosid/features/library/library_screen.dart';
import 'package:rosid/features/library/library_search_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/golden_fonts.dart';

BundleDetailView _makeVisaBundleEn() {
  final now = DateTime(2026, 11, 26);
  final bundle = Bundle(
    id: 'b-visa',
    title: 'UK student visa, Farhana',
    purpose: 'student_visa',
    dueDate: DateTime(2027, 1, 15),
    createdAt: now,
    updatedAt: now,
  );
  BundleItem mkItem(String id, String title, int order, String? scanId) =>
      BundleItem(
        id: id,
        bundleId: 'b-visa',
        title: title,
        itemOrder: order,
        expectedKind: 'document',
        linkedScanId: scanId,
      );
  return BundleDetailView(
    bundle: bundle,
    items: [
      BundleItemView(
        item: mkItem('i1', 'Passport', 0, 's1'),
        status: BundleItemStatus.ready,
        pageCount: 2,
        hasEnglishDraft: false,
        wordsToCheck: 0,
      ),
      BundleItemView(
        item: mkItem('i2', 'National ID, both sides', 1, 's2'),
        status: BundleItemStatus.ready,
        pageCount: 1,
        hasEnglishDraft: false,
        wordsToCheck: 0,
      ),
      BundleItemView(
        item: mkItem('i3', 'জন্ম নিবন্ধন সনদ', 2, 's3'),
        status: BundleItemStatus.needsWork,
        pageCount: 1,
        hasEnglishDraft: true,
        wordsToCheck: 0,
      ),
      BundleItemView(
        item: mkItem('i4', 'HSC certificate', 3, 's4'),
        status: BundleItemStatus.ready,
        pageCount: 1,
        hasEnglishDraft: false,
        wordsToCheck: 0,
      ),
      BundleItemView(
        item: mkItem('i5', 'Bank solvency certificate', 4, 's5'),
        status: BundleItemStatus.ready,
        pageCount: 1,
        hasEnglishDraft: false,
        wordsToCheck: 0,
      ),
      BundleItemView(
        item: mkItem('i6', 'খতিয়ান, বিরুলিয়া', 5, 's6'),
        status: BundleItemStatus.needsWork,
        pageCount: 1,
        hasEnglishDraft: false,
        wordsToCheck: 3,
      ),
      BundleItemView(
        item: mkItem('i7', 'Land tax receipt (দাখিলা)', 6, null),
        status: BundleItemStatus.missing,
        pageCount: 0,
        hasEnglishDraft: false,
        wordsToCheck: 0,
      ),
      BundleItemView(
        item: mkItem('i8', 'Sponsor letter', 7, null),
        status: BundleItemStatus.missing,
        pageCount: 0,
        hasEnglishDraft: false,
        wordsToCheck: 0,
      ),
      BundleItemView(
        item: mkItem('i9', 'Trade licence', 8, 's9'),
        status: BundleItemStatus.ready,
        pageCount: 1,
        hasEnglishDraft: false,
        wordsToCheck: 0,
      ),
      BundleItemView(
        item: mkItem('i10', 'Bank statement', 9, 's10'),
        status: BundleItemStatus.ready,
        pageCount: 2,
        hasEnglishDraft: false,
        wordsToCheck: 0,
      ),
      BundleItemView(
        item: mkItem('i11', 'Offer letter', 10, 's11'),
        status: BundleItemStatus.ready,
        pageCount: 1,
        hasEnglishDraft: false,
        wordsToCheck: 0,
      ),
    ],
  );
}

BundleDetailView _makeVisaBundleBn() {
  final now = DateTime(2026, 11, 26);
  final bundle = Bundle(
    id: 'b-visa-bn',
    title: 'যুক্তরাজ্য স্টুডেন্ট ভিসা, ফারহানা',
    purpose: 'student_visa',
    dueDate: DateTime(2027, 1, 15),
    createdAt: now,
    updatedAt: now,
  );
  BundleItem mkItem(String id, String title, int order, String? scanId) =>
      BundleItem(
        id: id,
        bundleId: 'b-visa-bn',
        title: title,
        itemOrder: order,
        expectedKind: 'document',
        linkedScanId: scanId,
      );
  return BundleDetailView(
    bundle: bundle,
    items: [
      BundleItemView(
        item: mkItem('b1', 'পাসপোর্ট', 0, 's1'),
        status: BundleItemStatus.ready,
        pageCount: 2,
        hasEnglishDraft: false,
        wordsToCheck: 0,
      ),
      BundleItemView(
        item: mkItem('b2', 'জাতীয় পরিচয়পত্র, দুই পিঠ', 1, 's2'),
        status: BundleItemStatus.ready,
        pageCount: 1,
        hasEnglishDraft: false,
        wordsToCheck: 0,
      ),
      BundleItemView(
        item: mkItem('b3', 'জন্ম নিবন্ধন সনদ', 2, 's3'),
        status: BundleItemStatus.needsWork,
        pageCount: 1,
        hasEnglishDraft: true,
        wordsToCheck: 0,
      ),
      BundleItemView(
        item: mkItem('b4', 'এইচএসসি সনদ', 3, 's4'),
        status: BundleItemStatus.ready,
        pageCount: 1,
        hasEnglishDraft: false,
        wordsToCheck: 0,
      ),
      BundleItemView(
        item: mkItem('b5', 'ব্যাংক সলভেন্সি সনদ', 4, 's5'),
        status: BundleItemStatus.ready,
        pageCount: 1,
        hasEnglishDraft: false,
        wordsToCheck: 0,
      ),
      BundleItemView(
        item: mkItem('b6', 'খতিয়ান, বিরুলিয়া', 5, 's6'),
        status: BundleItemStatus.needsWork,
        pageCount: 1,
        hasEnglishDraft: false,
        wordsToCheck: 3,
      ),
      BundleItemView(
        item: mkItem('b7', 'ভূমি উন্নয়ন করের দাখিলা', 6, null),
        status: BundleItemStatus.missing,
        pageCount: 0,
        hasEnglishDraft: false,
        wordsToCheck: 0,
      ),
      BundleItemView(
        item: mkItem('b8', 'স্পনসরের চিঠি', 7, null),
        status: BundleItemStatus.missing,
        pageCount: 0,
        hasEnglishDraft: false,
        wordsToCheck: 0,
      ),
      BundleItemView(
        item: mkItem('b9', 'ট্রেড লাইসেন্স', 8, 's9'),
        status: BundleItemStatus.ready,
        pageCount: 1,
        hasEnglishDraft: false,
        wordsToCheck: 0,
      ),
      BundleItemView(
        item: mkItem('b10', 'ব্যাংক স্টেটমেন্ট', 9, 's10'),
        status: BundleItemStatus.ready,
        pageCount: 2,
        hasEnglishDraft: false,
        wordsToCheck: 0,
      ),
      BundleItemView(
        item: mkItem('b11', 'অফার লেটার', 10, 's11'),
        status: BundleItemStatus.ready,
        pageCount: 1,
        hasEnglishDraft: false,
        wordsToCheck: 0,
      ),
    ],
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
    Locale locale = const Locale('en'),
    RosidNavTab? dockTab,
  }) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Widget screen = child;
    if (dockTab != null) {
      screen = Stack(
        children: [
          child,
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Material(
              type: MaterialType.transparency,
              child: RosidNavDock(
                activeTab: dockTab,
                showExpenses: true,
                onSelectTab: (_) {},
                onScanPressed: () {},
                homeLabel: 'Home',
                libraryLabel: 'Library',
                bundlesLabel: 'Bundles',
                expensesLabel: 'Expenses',
                scanTooltip: 'Scan',
              ),
            ),
          ),
        ],
      );
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$goldenName.png'),
    );
  }

  testWidgets('M7 screen golden: library', (tester) async {
    SharedPreferences.setMockInitialValues({
      'language_code': 'en',
      'expense_tracking_enabled': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await pumpPhone(
      tester,
      db,
      prefs,
      LibraryScreen(
        previewPapers: [
          LibraryPaperRowData(
            scanId: 'p1',
            title: 'খতিয়ান, বিরুলিয়া',
            kind: 'land',
            date: DateTime(2026, 11, 26),
            pageCount: 1,
            wordsToCheck: 3,
            hasEnglishDraft: false,
          ),
          LibraryPaperRowData(
            scanId: 'p2',
            title: 'জন্ম নিবন্ধন সনদ',
            kind: 'certificate',
            date: DateTime(2026, 11, 26),
            pageCount: 1,
            wordsToCheck: 0,
            hasEnglishDraft: true,
          ),
          LibraryPaperRowData(
            scanId: 'p3',
            title: 'National ID, both sides',
            kind: 'id',
            date: DateTime(2026, 11, 25),
            pageCount: 1,
            wordsToCheck: 0,
            hasEnglishDraft: false,
          ),
          LibraryPaperRowData(
            scanId: 'p4',
            title: 'Shwapno, Banani',
            kind: 'receipt',
            date: DateTime(2026, 11, 24),
            pageCount: 1,
            wordsToCheck: 0,
            hasEnglishDraft: false,
            amountLabel: '৳1,840',
          ),
          LibraryPaperRowData(
            scanId: 'p5',
            title: 'ট্রেড লাইসেন্স',
            kind: 'licence',
            date: DateTime(2026, 11, 20),
            pageCount: 2,
            wordsToCheck: 0,
            hasEnglishDraft: false,
            renewBy: DateTime(2027, 6, 30),
          ),
          LibraryPaperRowData(
            scanId: 'p6',
            title: 'HSC certificate',
            kind: 'certificate',
            date: DateTime(2026, 10, 28),
            pageCount: 1,
            wordsToCheck: 0,
            hasEnglishDraft: false,
          ),
          LibraryPaperRowData(
            scanId: 'p7',
            title: 'বিদ্যুৎ বিল, অক্টোবর',
            kind: 'bill',
            date: DateTime(2026, 10, 12),
            pageCount: 1,
            wordsToCheck: 0,
            hasEnglishDraft: false,
            amountLabel: '৳2,310',
          ),
        ],
      ),
      'm7_library',
      dockTab: RosidNavTab.library,
    );
  });

  testWidgets('M7 screen golden: library-search', (tester) async {
    SharedPreferences.setMockInitialValues({'language_code': 'en'});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await pumpPhone(
      tester,
      db,
      prefs,
      const LibraryScreen(
        previewSearchResult: LibrarySearchResult(
          query: 'বিরুলিয়া',
          paperCount: 3,
          elapsedMs: 4,
          hits: [
            LibrarySearchHit(
              scanId: 's1',
              title: 'খতিয়ান, বিরুলিয়া',
              kind: 'land',
              isEnglishDraft: false,
              pageNumber: 1,
              snippetLine: 'মৌজা: বিরুলিয়া জে.এল. নং: ৩৫',
              matchedTerms: ['বিরুলিয়া', 'birulia'],
            ),
            LibrarySearchHit(
              scanId: 's1',
              title: 'খতিয়ান, বিরুলিয়া',
              kind: 'land',
              isEnglishDraft: true,
              pageNumber: 1,
              snippetLine: 'Mouza: Birulia J.L. No. 35',
              matchedTerms: ['বিরুলিয়া', 'birulia'],
            ),
            LibrarySearchHit(
              scanId: 's2',
              title: 'নামজারি খতিয়ান',
              kind: 'land',
              isEnglishDraft: false,
              pageNumber: 2,
              snippetLine: 'সাং বিরুলিয়া সাভার, ঢাকা',
              matchedTerms: ['বিরুলিয়া', 'birulia'],
            ),
            LibrarySearchHit(
              scanId: 's3',
              title: 'ভূমি উন্নয়ন কর রশিদ',
              kind: 'receipt',
              isEnglishDraft: false,
              pageNumber: 1,
              snippetLine: 'মৌজা বিরুলিয়া খতিয়ান ১২৪৫',
              matchedTerms: ['বিরুলিয়া', 'birulia'],
            ),
          ],
        ),
      ),
      'm7_library_search',
      dockTab: RosidNavTab.library,
    );
  });

  testWidgets('M7 screen golden: bundles', (tester) async {
    SharedPreferences.setMockInitialValues({'language_code': 'en'});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final now = DateTime(2026, 11, 26);
    final landBundle = BundleDetailView(
      bundle: Bundle(
        id: 'b-land',
        title: 'জমির কাগজ, সাভার',
        purpose: 'land_papers',
        dueDate: null,
        createdAt: now,
        updatedAt: now,
      ),
      items: [
        for (var i = 0; i < 4; i++)
          BundleItemView(
            item: BundleItem(
              id: 'l$i',
              bundleId: 'b-land',
              title: 'Land $i',
              itemOrder: i,
              expectedKind: 'land',
              linkedScanId: 's$i',
            ),
            status: BundleItemStatus.ready,
            pageCount: 1,
            hasEnglishDraft: false,
            wordsToCheck: 0,
          ),
        BundleItemView(
          item: const BundleItem(
            id: 'l4',
            bundleId: 'b-land',
            title: 'Mutation record (নামজারি)',
            itemOrder: 4,
            expectedKind: 'land',
          ),
          status: BundleItemStatus.missing,
          pageCount: 0,
          hasEnglishDraft: false,
          wordsToCheck: 0,
        ),
        BundleItemView(
          item: const BundleItem(
            id: 'l5',
            bundleId: 'b-land',
            title: 'Dakhila',
            itemOrder: 5,
            expectedKind: 'land',
          ),
          status: BundleItemStatus.missing,
          pageCount: 0,
          hasEnglishDraft: false,
          wordsToCheck: 0,
        ),
      ],
    );

    final templates = await BundleRepository(db).loadTemplates();
    await pumpPhone(
      tester,
      db,
      prefs,
      BundlesScreen(
        previewBundles: [_makeVisaBundleEn(), landBundle],
        previewTemplates: templates,
      ),
      'm7_bundles',
      dockTab: RosidNavTab.bundles,
    );
  });

  testWidgets('M7 screen golden: bundle-checklist', (tester) async {
    SharedPreferences.setMockInitialValues({'language_code': 'en'});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await pumpPhone(
      tester,
      db,
      prefs,
      BundleChecklistScreen(
        bundleId: 'b-visa',
        previewDetail: _makeVisaBundleEn(),
        previewItemSubtitles: const {
          'i2': 'On one page',
          'i4': 'Already in English',
          'i9': 'English draft, certified copy added',
        },
      ),
      'm7_bundle_checklist',
    );
  });

  testWidgets('M7 screen golden: bundle-checklist-bn', (tester) async {
    SharedPreferences.setMockInitialValues({'language_code': 'bn'});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await pumpPhone(
      tester,
      db,
      prefs,
      BundleChecklistScreen(
        bundleId: 'b-visa-bn',
        previewDetail: _makeVisaBundleBn(),
        previewItemSubtitles: const {
          'b2': 'এক পৃষ্ঠায়',
          'b4': 'আগে থেকেই ইংরেজিতে',
          'b9': 'ইংরেজি খসড়া, সত্যায়িত কপি যুক্ত',
        },
      ),
      'm7_bundle_checklist_bn',
      locale: const Locale('bn'),
    );
  });

  testWidgets('M7 screen golden: bundle-export', (tester) async {
    SharedPreferences.setMockInitialValues({'language_code': 'en'});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final visa = _makeVisaBundleEn();
    final fiveReady = BundleDetailView(
      bundle: visa.bundle,
      items: [
        visa.items[0],
        visa.items[1],
        BundleItemView(
          item: const BundleItem(
            id: 'i3',
            bundleId: 'b-visa',
            title: 'Birth certificate, English draft',
            itemOrder: 2,
            expectedKind: 'certificate',
            linkedScanId: 's3',
          ),
          status: BundleItemStatus.ready,
          pageCount: 3,
          hasEnglishDraft: true,
          wordsToCheck: 0,
        ),
        visa.items[3],
        visa.items[4],
      ],
    );

    await pumpPhone(
      tester,
      db,
      prefs,
      BundleExportScreen(
        bundleId: 'b-visa',
        previewDetail: fiveReady,
        previewFileName: 'UK-student-visa-Farhana.pdf',
        previewSummary: '14 pages, 6.2 MB',
        previewReadyCountLabel: '9 ready papers',
        previewDraftWarningTitle: 'birth certificate',
        previewItemMeta: const {
          'i1': '2 pages, 0.9 MB',
          'i2': '1 page, 0.4 MB',
          'i3': '3 pages, 1.1 MB',
          'i4': '1 page, 0.6 MB',
          'i5': '1 page, 0.5 MB',
        },
      ),
      'm7_bundle_export',
    );
  });
}
