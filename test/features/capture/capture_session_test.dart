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
    registerFallbackValue(<String>[]);
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

  test('discard deletes the database row and every scan artifact', () async {
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
    when(() => scans.deleteScan(any())).thenAnswer((_) async {});
    when(
      () => files.deleteScanArtifacts(
        scanId: any(named: 'scanId'),
        knownPaths: any(named: 'knownPaths'),
      ),
    ).thenAnswer((_) async {});
    final value = container();
    final controller = value.read(captureSessionProvider.notifier);
    await controller.addSourcePath('/tmp/a.jpg');
    final scanId = value.read(captureSessionProvider).scanId!;

    await controller.discard();

    verify(() => scans.deleteScan(scanId)).called(1);
    verify(
      () => files.deleteScanArtifacts(
        scanId: scanId,
        knownPaths: any(named: 'knownPaths'),
      ),
    ).called(1);
    expect(value.read(captureSessionProvider).scanId, isNull);
    expect(value.read(captureSessionProvider).pagePaths, isEmpty);
  });

  test('database failure removes the newly copied private image', () async {
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
    ).thenThrow(StateError('database unavailable'));
    when(() => files.deleteIfPresent(any())).thenAnswer((_) async {});
    final value = container();

    expect(
      await value
          .read(captureSessionProvider.notifier)
          .addSourcePath('/tmp/a.jpg'),
      isFalse,
    );

    verify(() => files.deleteIfPresent('/private/page-0.jpg')).called(1);
    expect(value.read(captureSessionProvider).pagePaths, isEmpty);
  });
}
