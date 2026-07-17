import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rosid/core/l10n/app_localizations_bn.dart';
import 'package:rosid/core/l10n/app_localizations_en.dart';
import 'package:rosid/core/profile/app_profile.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/repositories/scan_repository.dart';
import 'package:rosid/features/capture/capture_session.dart';
import 'package:rosid/features/crop/preprocess_controller.dart';
import 'package:rosid/features/review/receipt_review_controller.dart';
import 'package:rosid/ocr/models/ocr_models.dart';
import 'package:rosid/ocr/ocr_service.dart';

class _MockOcrService extends Mock implements OcrService {}

class _MockScanRepository extends Mock implements ScanRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const <PreprocessedImage>[]);
    registerFallbackValue(ScriptHint.automatic);
  });

  test('each parsed field is capped by its source block confidence', () async {
    final localizations = AppLocalizationsEn();
    final ocr = _MockOcrService();
    final scans = _MockScanRepository();
    when(
      () => ocr.recognize(any(), hint: any(named: 'hint')),
    ).thenAnswer((_) async => _lowConfidenceReceipt);
    when(
      () => scans.updateOcr(
        scanId: any(named: 'scanId'),
        rawText: any(named: 'rawText'),
        engine: any(named: 'engine'),
        meanConfidence: any(named: 'meanConfidence'),
      ),
    ).thenAnswer((_) async {});
    when(() => scans.getScan('scan-a')).thenAnswer(
      (_) async => Scan(
        id: 'scan-a',
        type: 'receipt',
        imagePath: '/private/a.jpg',
        ocrRawText: '',
        langHint: 'automatic',
        createdAt: DateTime(2026, 7, 17),
        updatedAt: DateTime(2026, 7, 17),
      ),
    );
    final container = ProviderContainer(
      overrides: [
        ocrServiceProvider.overrideWithValue(ocr),
        scanRepositoryProvider.overrideWithValue(scans),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(receiptReviewProvider.notifier)
        .initialize(
          session: _session,
          assets: [_asset],
          localizations: localizations,
        );

    final state = container.read(receiptReviewProvider);
    expect(state.total, '100.00');
    expect(state.confidence, isNotEmpty);
    expect(state.confidence['merchant'], greaterThan(0.6));
    expect(state.confidence['total'], lessThanOrEqualTo(0.2));
  });

  test('validation uses the active Bangla localization', () async {
    final bangla = AppLocalizationsBn();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final saved = await container
        .read(receiptReviewProvider.notifier)
        .save(localizations: bangla);

    expect(saved, isFalse);
    expect(
      container.read(receiptReviewProvider).errorMessage,
      bangla.receiptFieldsRequired,
    );
  });

  test('create flow rejects partially numeric receipt input', () async {
    final localizations = AppLocalizationsEn();
    final ocr = _MockOcrService();
    final scans = _MockScanRepository();
    when(
      () => ocr.recognize(any(), hint: any(named: 'hint')),
    ).thenAnswer((_) async => _lowConfidenceReceipt);
    when(
      () => scans.updateOcr(
        scanId: any(named: 'scanId'),
        rawText: any(named: 'rawText'),
        engine: any(named: 'engine'),
        meanConfidence: any(named: 'meanConfidence'),
      ),
    ).thenAnswer((_) async {});
    when(() => scans.getScan('scan-a')).thenAnswer(
      (_) async => Scan(
        id: 'scan-a',
        type: 'receipt',
        imagePath: '/private/a.jpg',
        ocrRawText: '',
        langHint: 'automatic',
        createdAt: DateTime(2026, 7, 17),
        updatedAt: DateTime(2026, 7, 17),
      ),
    );
    final container = ProviderContainer(
      overrides: [
        ocrServiceProvider.overrideWithValue(ocr),
        scanRepositoryProvider.overrideWithValue(scans),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(receiptReviewProvider.notifier);
    await controller.initialize(
      session: _session,
      assets: [_asset],
      localizations: localizations,
    );

    controller.setTotal('1,23');
    expect(await controller.save(localizations: localizations), isFalse);
    expect(
      container.read(receiptReviewProvider).errorMessage,
      localizations.validTotalAndTaxRequired,
    );

    controller
      ..setTotal('100.00')
      ..setTax('1/2');
    expect(await controller.save(localizations: localizations), isFalse);
    expect(
      container.read(receiptReviewProvider).errorMessage,
      localizations.validTotalAndTaxRequired,
    );

    controller.setTax('');
    var firstItem = container.read(receiptReviewProvider).items.first;
    controller.setItem(0, firstItem.copyWith(quantity: '1abc2'));
    expect(await controller.save(localizations: localizations), isFalse);
    expect(
      container.read(receiptReviewProvider).errorMessage,
      localizations.validLineItemRequired,
    );

    firstItem = container.read(receiptReviewProvider).items.first;
    controller.setItem(
      0,
      firstItem.copyWith(quantity: '1', unitPrice: '12x34'),
    );
    expect(await controller.save(localizations: localizations), isFalse);
    expect(
      container.read(receiptReviewProvider).errorMessage,
      localizations.validLineItemRequired,
    );
  });
}

const _session = CaptureSession(
  mode: ScanMode.receipt,
  languageHint: CaptureLanguageHint.automatic,
  scanId: 'scan-a',
  pagePaths: ['/private/a.jpg'],
);

const _asset = PreprocessedAsset(
  originalPath: '/private/a.jpg',
  colorPath: '/private/a-color.jpg',
  binaryPath: '/private/a-bw.jpg',
  width: 800,
  height: 1200,
  deskewAngle: 0,
  generation: 1,
);

final _lowConfidenceReceipt = OcrResult(
  blocks: [
    const OcrBlock(
      text: 'Corner Shop',
      boundingBox: OcrRect(left: 0, top: 0, right: 100, bottom: 10),
      confidence: 0.95,
      script: DetectedScript.latin,
      engineId: 'fake',
    ),
    for (var index = 0; index < 8; index++)
      OcrBlock(
        text: 'Item ${index + 1} 10.00',
        boundingBox: OcrRect(
          left: 0,
          top: 20 + index * 10,
          right: 100,
          bottom: 28 + index * 10,
        ),
        confidence: 0.95,
        script: DetectedScript.latin,
        engineId: 'fake',
      ),
    const OcrBlock(
      text: 'Total 100.00',
      boundingBox: OcrRect(left: 0, top: 110, right: 100, bottom: 120),
      confidence: 0.2,
      script: DetectedScript.latin,
      engineId: 'fake',
    ),
  ],
  engineIds: const {'fake'},
);
