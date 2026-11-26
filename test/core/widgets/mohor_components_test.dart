import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rosid/core/l10n/app_localizations.dart';
import 'package:rosid/core/theme/app_theme.dart';
import 'package:rosid/core/theme/rosid_icons.dart';
import 'package:rosid/core/widgets/rosid_controls.dart';
import 'package:rosid/core/widgets/rosid_inputs.dart';
import 'package:rosid/core/widgets/rosid_navigation.dart';
import 'package:rosid/core/widgets/rosid_paper_thumbnail.dart';

import '../../helpers/golden_fonts.dart';

Widget _showcase({required ThemeData theme, required Locale locale}) {
  final isBn = locale.languageCode == 'bn';
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      appBar: RosidTopBar(
        title: isBn ? 'রসিদ উপাদান' : 'Mohor components',
        showBack: true,
        trailing: [
          RosidPill(
            label: isBn ? 'অফলাইন' : 'Offline',
            tone: RosidTone.good,
            icon: RosidIcons.shield,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                RosidButton(
                  label: isBn ? 'এগিয়ে যান' : 'Primary',
                  kind: RosidButtonKind.primary,
                  onPressed: () {},
                ),
                RosidButton(
                  label: isBn ? 'শব্দ দেখুন' : 'Tonal',
                  kind: RosidButtonKind.tonal,
                  onPressed: () {},
                ),
                RosidButton(
                  label: isBn ? 'অনুবাদ' : 'Outline',
                  kind: RosidButtonKind.outline,
                  icon: RosidIcons.translate,
                  onPressed: () {},
                ),
                RosidButton(
                  label: isBn ? 'এখন নয়' : 'Ghost',
                  kind: RosidButtonKind.ghost,
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                RosidChip(
                  label: isBn ? 'সব' : 'All',
                  selected: true,
                  onTap: () {},
                ),
                RosidChip(
                  label: isBn ? 'জমি' : 'Land',
                  selected: false,
                  onTap: () {},
                ),
                RosidPill(
                  label: isBn ? 'ইংরেজি' : 'English',
                  tone: RosidTone.accent,
                ),
                RosidPill(
                  label: isBn ? '৩টি শব্দ' : '3 to check',
                  tone: RosidTone.warn,
                ),
                RosidPill(
                  label: isBn ? 'ত্রুটি' : 'Error',
                  tone: RosidTone.bad,
                ),
                RosidPill(
                  label: isBn ? 'স্বাভাবিক' : 'Neutral',
                  tone: RosidTone.neutral,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                RosidStamp(
                  label: isBn ? 'খসড়া' : 'DRAFT',
                  tone: RosidStampTone.accent,
                ),
                const SizedBox(width: 12),
                RosidStamp(
                  label: isBn ? 'সংরক্ষিত' : 'SAVED',
                  tone: RosidStampTone.good,
                ),
                const SizedBox(width: 12),
                RosidStamp(
                  label: isBn ? 'বাতিল' : 'ALERT',
                  tone: RosidStampTone.bad,
                ),
              ],
            ),
            const SizedBox(height: 12),
            RosidField(
              label: isBn ? 'শিরোনাম' : 'Default field',
              hint: isBn ? 'এখানে লিখুন' : 'Type here',
              leadingIcon: RosidIcons.search,
            ),
            const SizedBox(height: 10),
            RosidField(
              label: isBn ? 'রসিদ যা পড়েছে' : 'Check field',
              hint: isBn ? 'বিরুলিয়া' : 'Birulia',
              fieldState: RosidFieldState.check,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                RosidToggle(value: true, onChanged: (_) {}),
                RosidToggle(value: false, onChanged: (_) {}),
                const SizedBox(width: 8),
                RosidRadio(selected: true, onTap: () {}),
                RosidRadio(selected: false, onTap: () {}),
                const SizedBox(width: 8),
                const RosidCheckbox(checked: true),
                const SizedBox(width: 8),
                const RosidCheckbox(checked: false),
              ],
            ),
            const SizedBox(height: 12),
            const Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                RosidPaperThumbnail(kind: RosidPaperKind.letter),
                RosidPaperThumbnail(kind: RosidPaperKind.land),
                RosidPaperThumbnail(kind: RosidPaperKind.certificate),
                RosidPaperThumbnail(kind: RosidPaperKind.id),
                RosidPaperThumbnail(kind: RosidPaperKind.receipt),
                RosidPaperThumbnail(kind: RosidPaperKind.notes),
              ],
            ),
            const SizedBox(height: 12),
            RosidReaderTabs(
              active: RosidReaderTab.text,
              scanLabel: isBn ? 'স্ক্যান' : 'Scan',
              textLabel: isBn ? 'লেখা' : 'Text',
              englishLabel: isBn ? 'ইংরেজি' : 'English',
              onChanged: (_) {},
            ),
            const SizedBox(height: 12),
            RosidPaperRow(
              title: isBn ? 'খতিয়ান, বিরুলিয়া' : 'Khatian, Birulia',
              subtitle: isBn ? 'জমির রেকর্ড, আজ' : 'Land record, today',
              kind: RosidPaperKind.land,
              trailingTop: isBn ? '১ পৃষ্ঠা' : '1 page',
              pillLabel: isBn ? '৩টি শব্দ দেখে নিন' : '3 words to check',
              pillTone: RosidTone.warn,
              onTap: () {},
            ),
            RosidCheckRow(
              title: isBn ? 'জন্ম নিবন্ধন সনদ' : 'Birth certificate',
              subtitle: isBn ? 'তৈরি' : 'Ready',
              status: RosidCheckStatus.done,
              onTap: () {},
            ),
            RosidCheckRow(
              title: isBn ? 'খতিয়ান, বিরুলিয়া' : 'Land record',
              subtitle: isBn ? '৩টি শব্দ দেখে নিন' : '3 words to check',
              status: RosidCheckStatus.check,
              actionLabel: isBn ? 'দেখুন' : 'Check',
              onAction: () {},
            ),
            RosidCheckRow(
              title: isBn ? 'দাখিলা' : 'Land tax receipt',
              subtitle: isBn ? 'এখনও নেই' : 'Missing',
              status: RosidCheckStatus.missing,
              actionLabel: isBn ? 'স্ক্যান' : 'Scan',
              onAction: () {},
            ),
          ],
        ),
      ),
      bottomNavigationBar: RosidNavDock(
        activeTab: RosidNavTab.home,
        showExpenses: true,
        homeLabel: isBn ? 'হোম' : 'Home',
        libraryLabel: isBn ? 'কাগজপত্র' : 'Library',
        bundlesLabel: isBn ? 'ফাইল' : 'Bundles',
        expensesLabel: isBn ? 'খরচ' : 'Expenses',
        scanTooltip: isBn ? 'স্ক্যান' : 'Scan',
        onSelectTab: (_) {},
        onScanPressed: () {},
      ),
    ),
  );
}

void main() {
  setUpAll(loadRosidTestFonts);

  testWidgets('Mohor components interactive smoke test', (tester) async {
    var tapped = 0;
    var toggleVal = false;
    RosidReaderTab tab = RosidReaderTab.scan;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Column(
              children: [
                RosidButton(
                  label: 'Tap me',
                  onPressed: () => setState(() => tapped++),
                ),
                RosidToggle(
                  value: toggleVal,
                  onChanged: (v) => setState(() => toggleVal = v),
                ),
                RosidReaderTabs(
                  active: tab,
                  scanLabel: 'Scan',
                  textLabel: 'Text',
                  englishLabel: 'English',
                  onChanged: (next) => setState(() => tab = next),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Tap me'));
    await tester.tap(find.byType(RosidToggle));
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(tapped, 1);
    expect(toggleVal, isTrue);
    expect(tab, RosidReaderTab.english);
  });

  final matrix = <(String, ThemeData, Locale)>[
    ('components_light_en', AppTheme.light(), const Locale('en')),
    ('components_dark_en', AppTheme.dark(), const Locale('en')),
    ('components_light_bn', AppTheme.light(), const Locale('bn')),
    ('components_dark_bn', AppTheme.dark(), const Locale('bn')),
  ];

  for (final entry in matrix) {
    testWidgets('golden: ${entry.$1}', (tester) async {
      tester.view.physicalSize = const Size(412, 1180);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_showcase(theme: entry.$2, locale: entry.$3));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/${entry.$1}.png'),
      );
    });
  }
}
