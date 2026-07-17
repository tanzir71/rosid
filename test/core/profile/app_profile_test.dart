import 'package:flutter_test/flutter_test.dart';
import 'package:rosid/core/profile/app_profile.dart';

void main() {
  group('AppProfile', () {
    test('Android is receipts-first', () {
      final profile = AppProfile.resolve(override: 'android', isIOS: true);

      expect(profile.expenseTrackingDefault, isTrue);
      expect(profile.defaultScanMode, ScanMode.receipt);
      expect(profile.homeLayout, HomeLayout.dashboard);
    });

    test('iOS is documents-first', () {
      final profile = AppProfile.resolve(override: 'ios', isIOS: false);

      expect(profile.expenseTrackingDefault, isFalse);
      expect(profile.defaultScanMode, ScanMode.document);
      expect(profile.homeLayout, HomeLayout.documentsGrid);
    });

    test('unknown override falls back to platform', () {
      expect(
        AppProfile.resolve(override: 'unknown', isIOS: true).homeLayout,
        HomeLayout.documentsGrid,
      );
    });
  });
}
