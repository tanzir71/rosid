import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosid/app.dart';
import 'package:rosid/core/profile/app_profile.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/database/database_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<SharedPreferences> preferences() async {
    SharedPreferences.setMockInitialValues({});
    return SharedPreferences.getInstance();
  }

  testWidgets('renders the navigable app shell', (tester) async {
    final prefs = await preferences();
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appProfileProvider.overrideWithValue(const AppProfile.android()),
          databaseProvider.overrideWithValue(database),
        ],
        child: const RosidApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('This month'), findsOneWidget);
    expect(find.byIcon(Icons.document_scanner_outlined), findsOneWidget);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('History'), findsWidgets);
  });

  testWidgets('uses Bangla labels from persisted language setting', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'language_code': 'bn'});
    final prefs = await SharedPreferences.getInstance();
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appProfileProvider.overrideWithValue(const AppProfile.android()),
          databaseProvider.overrideWithValue(database),
        ],
        child: const RosidApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('হোম'), findsOneWidget);
    expect(find.text('ইতিহাস'), findsOneWidget);
    expect(find.text('সেটিংস'), findsOneWidget);
  });

  testWidgets('iOS profile starts documents-first and can enable expenses', (
    tester,
  ) async {
    final prefs = await preferences();
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appProfileProvider.overrideWithValue(const AppProfile.ios()),
          databaseProvider.overrideWithValue(database),
        ],
        child: const RosidApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No documents yet'), findsOneWidget);
    expect(find.text('This month'), findsNothing);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    final expenseSwitch = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Expense tracking'),
    );
    expect(expenseSwitch.value, isFalse);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Expense tracking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(find.text('This month'), findsOneWidget);
  });
}
