import 'dart:io' show Platform;

enum ScanMode { receipt, document }

enum HomeLayout { dashboard, documentsGrid }

class AppProfile {
  const AppProfile({
    required this.expenseTrackingDefault,
    required this.expenseTrackingLocked,
    required this.defaultScanMode,
    required this.homeLayout,
  });

  const AppProfile.android()
    : expenseTrackingDefault = true,
      expenseTrackingLocked = false,
      defaultScanMode = ScanMode.receipt,
      homeLayout = HomeLayout.dashboard;

  const AppProfile.ios()
    : expenseTrackingDefault = false,
      expenseTrackingLocked = false,
      defaultScanMode = ScanMode.document,
      homeLayout = HomeLayout.documentsGrid;

  final bool expenseTrackingDefault;
  final bool expenseTrackingLocked;
  final ScanMode defaultScanMode;
  final HomeLayout homeLayout;

  static AppProfile resolve({String? override, bool? isIOS}) {
    final normalized = (override ?? const String.fromEnvironment('APP_PROFILE'))
        .trim()
        .toLowerCase();
    if (normalized == 'ios') return const AppProfile.ios();
    if (normalized == 'android') return const AppProfile.android();
    return (isIOS ?? Platform.isIOS)
        ? const AppProfile.ios()
        : const AppProfile.android();
  }
}
