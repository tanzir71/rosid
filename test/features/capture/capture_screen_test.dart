import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rosid/core/l10n/app_localizations.dart';
import 'package:rosid/core/profile/app_profile.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/data/files/private_file_store.dart';
import 'package:rosid/data/repositories/scan_repository.dart';
import 'package:rosid/features/capture/capture_screen.dart';
import 'package:rosid/features/capture/capture_session.dart';

class _MockFileStore extends Mock implements PrivateFileStore {}

class _MockScanRepository extends Mock implements ScanRepository {}

class _MockCameraController extends Mock implements CameraController {}

class _FakeCaptureNativeOperations implements CaptureNativeOperations {
  final cameraResult = Completer<XFile>();
  final galleryResult = Completer<List<XFile>>();
  final availableCameraResults = <Future<List<CameraDescription>>>[];
  final cameraControllers = <CameraController>[];
  Completer<List<XFile>>? lostGalleryResult;

  int cameraCalls = 0;
  int galleryCalls = 0;
  final deletedTemporaryPaths = <String>[];

  @override
  Future<List<CameraDescription>> availableCameraDescriptions() =>
      availableCameraResults.removeAt(0);

  @override
  bool canTakePicture(CameraController? controller) => true;

  @override
  CameraController createCameraController(CameraDescription description) =>
      cameraControllers.removeAt(0);

  @override
  Future<void> deleteTemporaryCameraFile(String path) async {
    deletedTemporaryPaths.add(path);
  }

  @override
  Future<void> deleteTemporaryGalleryFile(String path) async {
    deletedTemporaryPaths.add(path);
  }

  @override
  Future<List<XFile>> pickImages({
    required ScanMode mode,
    required double maximumDimension,
  }) {
    galleryCalls++;
    return galleryResult.future;
  }

  @override
  Future<List<XFile>> retrieveLostGalleryFiles() =>
      lostGalleryResult?.future ?? Future.value(const []);

  @override
  Future<XFile> takePicture(CameraController? controller) {
    cameraCalls++;
    return cameraResult.future;
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(ScanMode.receipt);
    registerFallbackValue(<String>[]);
  });

  test('desktop gallery cleanup preserves the selected original', () async {
    if (Platform.isAndroid || Platform.isIOS) return;
    final directory = await Directory.systemTemp.createTemp(
      'rosid-gallery-original-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final original = File('${directory.path}${Platform.pathSeparator}scan.jpg');
    await original.writeAsString('user-owned original');

    await const PlatformCaptureNativeOperations().deleteTemporaryGalleryFile(
      original.path,
    );

    expect(await original.exists(), isTrue);
  });

  testWidgets(
    'camera initialization cannot publish across an inactive resume race',
    (tester) async {
      const description = CameraDescription(
        name: 'test-camera',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 90,
      );
      final first = _MockCameraController();
      final second = _MockCameraController();
      final firstInitialization = Completer<void>();
      final secondInitialization = Completer<void>();
      when(
        () => first.value,
      ).thenReturn(const CameraValue.uninitialized(description));
      when(
        () => second.value,
      ).thenReturn(const CameraValue.uninitialized(description));
      when(
        () => first.initialize(),
      ).thenAnswer((_) => firstInitialization.future);
      when(
        () => second.initialize(),
      ).thenAnswer((_) => secondInitialization.future);
      when(() => first.dispose()).thenAnswer((_) async {});
      when(() => second.dispose()).thenAnswer((_) async {});

      final files = _MockFileStore();
      final scans = _MockScanRepository();
      final nativeOperations = _FakeCaptureNativeOperations()
        ..availableCameraResults.addAll([
          Future.value([description]),
          Future.value([description]),
        ])
        ..cameraControllers.addAll([first, second]);
      final container = _captureContainer(files: files, scans: scans);
      addTearDown(container.dispose);

      await _openCapture(
        tester,
        container: container,
        nativeOperations: nativeOperations,
        initializeCamera: true,
      );
      await tester.pump();
      verify(() => first.initialize()).called(1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      verify(() => first.dispose()).called(1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      verify(() => second.initialize()).called(1);

      firstInitialization.complete();
      await tester.pump();
      verifyNever(() => first.dispose());

      secondInitialization.complete();
      await tester.pump();
      await tester.pump();
      verifyNever(() => second.dispose());

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      verify(() => second.dispose()).called(1);
    },
  );

  testWidgets('lost Android picker cache is discarded even after unmount', (
    tester,
  ) async {
    final files = _MockFileStore();
    final scans = _MockScanRepository();
    final nativeOperations = _FakeCaptureNativeOperations()
      ..lostGalleryResult = Completer<List<XFile>>();
    final container = _captureContainer(files: files, scans: scans);
    addTearDown(container.dispose);

    await _openCapture(
      tester,
      container: container,
      nativeOperations: nativeOperations,
    );
    await tester.pumpWidget(const SizedBox());
    nativeOperations.lostGalleryResult!.complete([
      XFile('/tmp/lost-picker-cache.jpg'),
    ]);
    await tester.pump();
    await tester.pump();

    expect(nativeOperations.deletedTemporaryPaths, [
      '/tmp/lost-picker-cache.jpg',
    ]);
  });

  for (final useSystemBack in [false, true]) {
    testWidgets(
      '${useSystemBack ? 'system back' : 'close'} discards before leaving capture',
      (tester) async {
        final files = _MockFileStore();
        final scans = _MockScanRepository();
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
        final container = ProviderContainer(
          overrides: [
            appProfileProvider.overrideWithValue(const AppProfile.android()),
            expenseTrackingEnabledProvider.overrideWithValue(true),
            privateFileStoreProvider.overrideWithValue(files),
            scanRepositoryProvider.overrideWithValue(scans),
          ],
        );
        addTearDown(container.dispose);
        await container
            .read(captureSessionProvider.notifier)
            .addSourcePath('/tmp/a.jpg');
        final scanId = container.read(captureSessionProvider).scanId!;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => const CaptureScreen(),
                      ),
                    ),
                    child: const Text('Open capture'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open capture'));
        await tester.pumpAndSettle();

        if (useSystemBack) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.byIcon(Icons.close));
        }
        await tester.pumpAndSettle();

        verify(() => scans.deleteScan(scanId)).called(1);
        verify(
          () => files.deleteScanArtifacts(
            scanId: scanId,
            knownPaths: any(named: 'knownPaths'),
          ),
        ).called(1);
        expect(find.text('Open capture'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'delayed camera capture blocks close and double taps, then cleans an abandoned file',
    (tester) async {
      final files = _MockFileStore();
      final scans = _MockScanRepository();
      final nativeOperations = _FakeCaptureNativeOperations();
      final container = _captureContainer(files: files, scans: scans);
      addTearDown(container.dispose);

      await _openCapture(
        tester,
        container: container,
        nativeOperations: nativeOperations,
      );

      await tester.tap(find.byKey(const ValueKey('capture-shutter')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('capture-shutter')));
      await tester.tap(find.byKey(const ValueKey('capture-gallery')));
      await tester.tap(find.byKey(const ValueKey('capture-close')));
      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(nativeOperations.cameraCalls, 1);
      expect(nativeOperations.galleryCalls, 0);
      expect(find.byType(CaptureScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      nativeOperations.cameraResult.complete(
        XFile('/tmp/abandoned-camera-capture.jpg'),
      );
      await tester.pump();
      await tester.pump();

      expect(nativeOperations.deletedTemporaryPaths, [
        '/tmp/abandoned-camera-capture.jpg',
      ]);
      verifyNever(
        () => files.persistCapture(
          sourcePath: any(named: 'sourcePath'),
          scanId: any(named: 'scanId'),
          pageIndex: any(named: 'pageIndex'),
        ),
      );
    },
  );

  testWidgets(
    'delayed gallery request blocks competing actions and cancellation permits close',
    (tester) async {
      final files = _MockFileStore();
      final scans = _MockScanRepository();
      final nativeOperations = _FakeCaptureNativeOperations();
      final container = _captureContainer(files: files, scans: scans);
      addTearDown(container.dispose);

      await _openCapture(
        tester,
        container: container,
        nativeOperations: nativeOperations,
      );

      await tester.tap(find.byKey(const ValueKey('capture-gallery')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('capture-gallery')));
      await tester.tap(find.byKey(const ValueKey('capture-shutter')));
      await tester.tap(find.byKey(const ValueKey('capture-close')));
      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(nativeOperations.galleryCalls, 1);
      expect(nativeOperations.cameraCalls, 0);
      expect(find.byType(CaptureScreen), findsOneWidget);

      nativeOperations.galleryResult.complete(const []);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('capture-close')));
      await tester.pumpAndSettle();

      expect(find.text('Open capture'), findsOneWidget);
      verifyNever(
        () => files.persistCapture(
          sourcePath: any(named: 'sourcePath'),
          scanId: any(named: 'scanId'),
          pageIndex: any(named: 'pageIndex'),
        ),
      );
    },
  );

  testWidgets('gallery result after disposal is never persisted', (
    tester,
  ) async {
    final files = _MockFileStore();
    final scans = _MockScanRepository();
    final nativeOperations = _FakeCaptureNativeOperations();
    final container = _captureContainer(files: files, scans: scans);
    addTearDown(container.dispose);

    await _openCapture(
      tester,
      container: container,
      nativeOperations: nativeOperations,
    );
    await tester.tap(find.byKey(const ValueKey('capture-gallery')));
    await tester.pump();

    await tester.pumpWidget(const SizedBox());
    nativeOperations.galleryResult.complete([
      XFile('/tmp/late-gallery-result.jpg'),
    ]);
    await tester.pump();
    await tester.pump();

    verifyNever(
      () => files.persistCapture(
        sourcePath: any(named: 'sourcePath'),
        scanId: any(named: 'scanId'),
        pageIndex: any(named: 'pageIndex'),
      ),
    );
    expect(nativeOperations.deletedTemporaryPaths, [
      '/tmp/late-gallery-result.jpg',
    ]);
  });

  testWidgets('gallery cache is deleted when private persistence fails', (
    tester,
  ) async {
    final files = _MockFileStore();
    final scans = _MockScanRepository();
    final nativeOperations = _FakeCaptureNativeOperations();
    when(
      () => files.persistCapture(
        sourcePath: any(named: 'sourcePath'),
        scanId: any(named: 'scanId'),
        pageIndex: any(named: 'pageIndex'),
      ),
    ).thenThrow(StateError('private copy failed'));
    final container = _captureContainer(files: files, scans: scans);
    addTearDown(container.dispose);

    await _openCapture(
      tester,
      container: container,
      nativeOperations: nativeOperations,
    );
    await tester.tap(find.byKey(const ValueKey('capture-gallery')));
    await tester.pump();

    nativeOperations.galleryResult.complete([
      XFile('/tmp/failed-gallery-cache.jpg'),
    ]);
    await tester.pump();
    await tester.pump();

    expect(nativeOperations.deletedTemporaryPaths, [
      '/tmp/failed-gallery-cache.jpg',
    ]);
    expect(find.textContaining('private copy failed'), findsOneWidget);
  });
}

ProviderContainer _captureContainer({
  required PrivateFileStore files,
  required ScanRepository scans,
}) {
  return ProviderContainer(
    overrides: [
      appProfileProvider.overrideWithValue(const AppProfile.android()),
      expenseTrackingEnabledProvider.overrideWithValue(true),
      privateFileStoreProvider.overrideWithValue(files),
      scanRepositoryProvider.overrideWithValue(scans),
    ],
  );
}

Future<void> _openCapture(
  WidgetTester tester, {
  required ProviderContainer container,
  required CaptureNativeOperations nativeOperations,
  bool initializeCamera = false,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => CaptureScreen(
                    nativeOperations: nativeOperations,
                    initializeCamera: initializeCamera,
                  ),
                ),
              ),
              child: const Text('Open capture'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open capture'));
  await tester.pumpAndSettle();
}
