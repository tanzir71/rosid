import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rosid/app.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Flow 1: First run chooses English, picks two purposes, skips camera, lands on Home',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const RosidApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1: Choose English
      await tester.ensureVisible(find.text('English'));
      expect(find.text('English'), findsOneWidget);
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('welcome-continue-language')));
      await tester.pumpAndSettle();

      // Step 2: Pick purposes (toggle Receipts and spending on, keep Land)
      expect(find.text('What do you need Rosid for?'), findsOneWidget);
      await tester.ensureVisible(find.text('Receipts and spending'));
      await tester.tap(find.text('Receipts and spending'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('welcome-continue-purpose')));
      await tester.pumpAndSettle();

      // Step 3: Skip camera -> import photos path ends on Home
      expect(find.text('Allow the camera to scan'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('welcome-skip-camera')));
      await tester.pumpAndSettle();

      // Landed on Home
      expect(find.text('What are you scanning?'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(prefs.getBool('onboarding_complete'), isTrue);
      expect(prefs.getString('language_code'), 'en');
    },
  );
}
