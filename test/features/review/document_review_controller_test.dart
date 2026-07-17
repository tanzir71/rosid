import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rosid/core/l10n/app_localizations_bn.dart';
import 'package:rosid/core/profile/app_profile.dart';
import 'package:rosid/core/l10n/app_localizations_en.dart';
import 'package:rosid/data/repositories/scan_repository.dart';
import 'package:rosid/features/capture/capture_session.dart';
import 'package:rosid/features/crop/preprocess_controller.dart';
import 'package:rosid/features/review/document_review_controller.dart';
import 'package:rosid/features/review/ocr_controller.dart';
import 'package:rosid/ocr/models/ocr_models.dart';
import 'package:rosid/ocr/ocr_service.dart';

class _MockOcrService extends Mock implements OcrService {}

class _MockScanRepository extends Mock implements ScanRepository {}

void main() {
  final localizations = AppLocalizationsEn();
  late _MockOcrService ocr;
  late _MockScanRepository scans;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(const <PreprocessedImage>[]);
    registerFallbackValue(ScriptHint.automatic);
  });

  setUp(() {
    ocr = _MockOcrService();
    scans = _MockScanRepository();
    when(
      () => scans.updateOcr(
        scanId: any(named: 'scanId'),
        rawText: any(named: 'rawText'),
        engine: any(named: 'engine'),
        meanConfidence: any(named: 'meanConfidence'),
      ),
    ).thenAnswer((_) async {});
    container = ProviderContainer(
      overrides: [
        ocrServiceProvider.overrideWithValue(ocr),
        scanRepositoryProvider.overrideWithValue(scans),
      ],
    );
    addTearDown(container.dispose);
  });

  test('recropping the same scan reruns OCR for the new generation', () async {
    var call = 0;
    when(() => ocr.recognize(any(), hint: any(named: 'hint'))).thenAnswer(
      (_) async => _result(call++ == 0 ? 'First text' : 'Second text'),
    );
    final controller = container.read(documentReviewProvider.notifier);

    await controller.initialize(
      session: _session,
      assets: [_asset(1)],
      localizations: localizations,
    );
    expect(container.read(documentReviewProvider).body, 'First text');

    await controller.initialize(
      session: _session,
      assets: [_asset(2)],
      localizations: localizations,
    );
    expect(container.read(documentReviewProvider).body, 'Second text');
    verify(() => ocr.recognize(any(), hint: any(named: 'hint'))).called(2);
  });

  test('reentering review retries OCR after an error', () async {
    when(
      () => ocr.recognize(any(), hint: any(named: 'hint')),
    ).thenThrow(StateError('native OCR failed'));
    final controller = container.read(documentReviewProvider.notifier);

    await controller.initialize(
      session: _session,
      assets: [_asset(1)],
      localizations: localizations,
    );
    expect(container.read(documentReviewProvider).errorMessage, isNotNull);

    when(
      () => ocr.recognize(any(), hint: any(named: 'hint')),
    ).thenAnswer((_) async => _result('Recovered text'));
    await controller.initialize(
      session: _session,
      assets: [_asset(1)],
      localizations: localizations,
    );

    expect(container.read(documentReviewProvider).body, 'Recovered text');
  });

  test('an obsolete OCR request cannot overwrite a recropped review', () async {
    final firstStarted = Completer<void>();
    final finishFirst = Completer<OcrResult>();
    var call = 0;
    when(() => ocr.recognize(any(), hint: any(named: 'hint'))).thenAnswer((_) {
      if (call++ == 0) {
        firstStarted.complete();
        return finishFirst.future;
      }
      return Future.value(_result('Fresh text'));
    });
    final controller = container.read(documentReviewProvider.notifier);

    final first = controller.initialize(
      session: _session,
      assets: [_asset(1)],
      localizations: localizations,
    );
    await firstStarted.future;
    controller.reset();
    container.read(ocrControllerProvider.notifier).reset();
    final second = controller.initialize(
      session: _session,
      assets: [_asset(2)],
      localizations: localizations,
    );
    finishFirst.complete(_result('Stale text'));

    await Future.wait([first, second]);
    expect(container.read(documentReviewProvider).body, 'Fresh text');
    verify(
      () => scans.updateOcr(
        scanId: 'scan-a',
        rawText: 'Fresh text',
        engine: 'fake',
        meanConfidence: 0.9,
      ),
    ).called(1);
    verifyNever(
      () => scans.updateOcr(
        scanId: 'scan-a',
        rawText: 'Stale text',
        engine: any(named: 'engine'),
        meanConfidence: any(named: 'meanConfidence'),
      ),
    );
  });

  test('validation uses the active Bangla localization', () async {
    final bangla = AppLocalizationsBn();
    final saved = await container
        .read(documentReviewProvider.notifier)
        .save(localizations: bangla);

    expect(saved, isFalse);
    expect(
      container.read(documentReviewProvider).errorMessage,
      bangla.documentTitleRequired,
    );
  });
}

const _session = CaptureSession(
  mode: ScanMode.document,
  languageHint: CaptureLanguageHint.automatic,
  scanId: 'scan-a',
  pagePaths: ['/private/a.jpg'],
);

PreprocessedAsset _asset(int generation) => PreprocessedAsset(
  originalPath: '/private/a.jpg',
  colorPath: '/private/a-color.jpg',
  binaryPath: '/private/a-bw.jpg',
  width: 800,
  height: 1200,
  deskewAngle: 0,
  generation: generation,
);

OcrResult _result(String text) => OcrResult(
  blocks: [
    OcrBlock(
      text: text,
      boundingBox: const OcrRect(left: 0, top: 0, right: 100, bottom: 20),
      confidence: 0.9,
      script: DetectedScript.latin,
      engineId: 'fake',
    ),
  ],
  engineIds: const {'fake'},
);
