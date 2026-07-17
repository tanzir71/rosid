import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rosid/core/profile/app_profile.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/data/files/private_file_store.dart';
import 'package:rosid/data/repositories/scan_repository.dart';
import 'package:rosid/features/capture/capture_session.dart';

class _MockFileStore extends Mock implements PrivateFileStore {}

class _MockScanRepository extends Mock implements ScanRepository {}

void main() {
  late _MockFileStore files;
  late _MockScanRepository scans;

  setUpAll(() {
    registerFallbackValue(ScanMode.receipt);
  });

  setUp(() {
    files = _MockFileStore();
    scans = _MockScanRepository();
  });

  ProviderContainer container({
    AppProfile profile = const AppProfile.android(),
    bool expenses = true,
  }) {
    final value = ProviderContainer(
      overrides: [
        appProfileProvider.overrideWithValue(profile),
        expenseTrackingEnabledProvider.overrideWithValue(expenses),
        privateFileStoreProvider.overrideWithValue(files),
        scanRepositoryProvider.overrideWithValue(scans),
      ],
    );
    addTearDown(value.dispose);
    return value;
  }

  test('Android expense profile starts in receipt mode', () {
    expect(container().read(captureSessionProvider).mode, ScanMode.receipt);
  });

  test('expense-off iOS profile starts and stays in document mode', () {
    final value = container(profile: const AppProfile.ios(), expenses: false);
    final controller = value.read(captureSessionProvider.notifier);

    expect(value.read(captureSessionProvider).mode, ScanMode.document);
    controller.setMode(ScanMode.receipt);
    expect(value.read(captureSessionProvider).mode, ScanMode.document);
  });

  test('first captured path persists a scan row', () async {
    when(
      () => files.persistCapture(
        sourcePath: any(named: 'sourcePath'),
        scanId: any(named: 'scanId'),
        pageIndex: any(named: 'pageIndex'),
      ),
    ).thenAnswer((_) async => '/private/page-0.jpg');
    when(
      () => scans.createScan(
        id: any(named: 'id'),
        mode: any(named: 'mode'),
        imagePath: any(named: 'imagePath'),
        langHint: any(named: 'langHint'),
        createdAt: any(named: 'createdAt'),
      ),
    ).thenAnswer((_) async {});
    final value = container();

    expect(
      await value
          .read(captureSessionProvider.notifier)
          .addSourcePath('/tmp/a.jpg'),
      isTrue,
    );
    expect(value.read(captureSessionProvider).pagePaths, [
      '/private/page-0.jpg',
    ]);
    verify(
      () => scans.createScan(
        id: any(named: 'id'),
        mode: ScanMode.receipt,
        imagePath: '/private/page-0.jpg',
        langHint: 'automatic',
        createdAt: any(named: 'createdAt'),
      ),
    ).called(1);
  });
}
