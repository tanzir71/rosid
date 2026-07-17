import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosid/app.dart';
import 'package:rosid/core/profile/app_profile.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<SharedPreferences> preferences() async {
    SharedPreferences.setMockInitialValues({});
    return SharedPreferences.getInstance();
  }

  testWidgets('renders the navigable app shell', (tester) async {
    final prefs = await preferences();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appProfileProvider.overrideWithValue(const AppProfile.android()),
        ],
        child: const RosidApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rosid keeps every scan on this device.'), findsOneWidget);
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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appProfileProvider.overrideWithValue(const AppProfile.android()),
        ],
        child: const RosidApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('হোম'), findsOneWidget);
    expect(find.text('ইতিহাস'), findsOneWidget);
    expect(find.text('সেটিংস'), findsOneWidget);
  });
}
