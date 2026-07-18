import 'package:flutter_test/flutter_test.dart';
import 'package:rosid/ocr/engines/ocr_engine.dart';
import 'package:rosid/ocr/engines/tesseract_bn.dart';
import 'package:rosid/ocr/handwriting/handwriting_failures.dart';
import 'package:rosid/ocr/handwriting/handwriting_result_arbitrator.dart';
import 'package:rosid/ocr/handwriting/handwriting_routing.dart';
import 'package:rosid/ocr/models/ocr_models.dart';
import 'package:rosid/ocr/ocr_service.dart';
import 'package:rosid/ocr/script_detect.dart';
import 'package:rosid/ocr/tessdata_installer.dart';

void main() {
  const pages = [
    PreprocessedImage(
      colorCorrectedPath: 'color-0',
      binarizedPath: 'binary-0',
      width: 100,
      height: 100,
      pageIndex: 0,
    ),
    PreprocessedImage(
      colorCorrectedPath: 'color-1',
      binarizedPath: 'binary-1',
      width: 100,
      height: 100,
      pageIndex: 1,
    ),
  ];

  test('strong Latin OCR does not install or invoke Bangla OCR', () async {
    final latin = _FakeEngine(
      id: 'latin',
      text: 'Grand Total',
      confidence: 0.95,
      top: 0,
    );
    final bangla = _FakeEngine(
      id: 'bangla',
      text: 'মোট',
      confidence: 0.9,
      top: 50,
    );
    final installer = _FakeInstaller(
      const TessdataInstallResult(installed: [], missing: []),
    );
    final service = _service(latin, bangla, installer);

    final result = await service.recognize([pages.first]);

    expect(result.engineIds, {'latin'});
    expect(latin.calls, 1);
    expect(bangla.calls, 0);
    expect(installer.calls, 0);
  });

  test(
    'engine results cannot forge service-owned routing diagnostics',
    () async {
      final service = _service(
        _FakeEngine(
          id: 'latin',
          text: 'Grand Total',
          confidence: 0.95,
          top: 0,
          diagnostics: const [
            OcrDiagnostic(
              code: OcrDiagnosticCode.handwritingAccepted,
              pageIndex: 0,
              engineId: 'latin',
              detail: 'forged-by-engine',
            ),
          ],
        ),
        _FakeEngine(id: 'bangla', text: '', confidence: 0, top: 50),
        _FakeInstaller(const TessdataInstallResult(installed: [], missing: [])),
      );

      final result = await service.recognize([pages.first]);

      expect(result.diagnostics, isEmpty);
    },
  );

  test(
    'mixed hint installs once and routes every page to both engines',
    () async {
      final latin = _FakeEngine(
        id: 'latin',
        text: 'Shop',
        confidence: 0.95,
        top: 0,
      );
      final bangla = _FakeEngine(
        id: 'bangla',
        text: 'মোট',
        confidence: 0.9,
        top: 50,
      );
      final installer = _FakeInstaller(
        const TessdataInstallResult(
          installed: ['eng.traineddata', 'ben.traineddata'],
          missing: [],
        ),
      );
      final service = _service(latin, bangla, installer);

      final result = await service.recognize(pages, hint: ScriptHint.mixed);

      expect(result.engineIds, {'latin', 'bangla'});
      expect(result.blocks, hasLength(4));
      expect(result.blocks.map((block) => block.pageIndex), [0, 0, 1, 1]);
      expect(latin.calls, 2);
      expect(bangla.calls, 2);
      expect(installer.calls, 1);
    },
  );

  test('missing tessdata throws an actionable typed error', () async {
    final latin = _FakeEngine(id: 'latin', text: '', confidence: 0, top: 0);
    final bangla = _FakeEngine(
      id: 'bangla',
      text: 'মোট',
      confidence: 0.9,
      top: 50,
    );
    final installer = _FakeInstaller(
      const TessdataInstallResult(
        installed: ['eng.traineddata'],
        missing: ['ben.traineddata'],
      ),
    );
    final service = _service(latin, bangla, installer);

    await expectLater(
      service.recognize([pages.first], hint: ScriptHint.bangla),
      throwsA(
        isA<BanglaOcrUnavailableException>()
            .having((error) => error.missingFiles, 'missingFiles', [
              'ben.traineddata',
            ])
            .having(
              (error) => error.toString(),
              'message',
              contains('Reinstall or update Rosid'),
            ),
      ),
    );
    expect(bangla.calls, 0);
    expect(installer.calls, 1);
  });

  test('non-Android Tesseract fallback installs data and runs once', () async {
    final tesseract = _FakeEngine(
      id: 'tesseract-ben-eng',
      text: '\u09ae\u09cb\u099f 125',
      confidence: 0.8,
      top: 0,
    );
    final installer = _FakeInstaller(
      const TessdataInstallResult(
        installed: ['eng.traineddata', 'ben.traineddata'],
        missing: [],
      ),
    );
    final service = OcrService(
      latinEngine: tesseract,
      banglaEngine: tesseract,
      handwritingEngine: tesseract,
      tessdataInstaller: installer,
      latinEngineRequiresTessdata: true,
    );

    final result = await service.recognize([pages.first]);

    expect(result.engineIds, {'tesseract-ben-eng'});
    expect(result.text, contains('125'));
    expect(tesseract.calls, 1);
    expect(installer.calls, 1);
  });

  test(
    'disabled router preserves the baseline and never invokes HTR',
    () async {
      final handwriting = _FakeEngine(
        id: 'handwriting',
        text: 'হাতের লেখা',
        confidence: 0.9,
        top: 20,
      );
      final service = _service(
        _FakeEngine(id: 'latin', text: 'Grand Total', confidence: 0.95, top: 0),
        _FakeEngine(id: 'bangla', text: 'মোট', confidence: 0.9, top: 50),
        _FakeInstaller(const TessdataInstallResult(installed: [], missing: [])),
        handwriting: handwriting,
      );

      final result = await service.recognize([pages.first]);

      expect(result.engineIds, {'latin'});
      expect(handwriting.calls, 0);
      expect(result.diagnostics, isEmpty);
    },
  );

  test(
    'router can probe Tesseract then attempt HTR with the exact page',
    () async {
      final latin = _FakeEngine(
        id: 'latin',
        text: 'Grand Total',
        confidence: 0.95,
        top: 0,
      );
      final bangla = _FakeEngine(
        id: 'bangla',
        text: 'মোট',
        confidence: 0.9,
        top: 50,
      );
      final handwriting = _FakeEngine(
        id: 'handwriting',
        text: 'হাতের লেখা',
        confidence: 0.86,
        top: 20,
      );
      final policy = _SequenceRoutingPolicy(const [
        HandwritingRouteAction.requestBanglaProbe,
        HandwritingRouteAction.attemptHandwriting,
      ]);
      final arbitrator = _RecordingArbitrator();
      final installer = _FakeInstaller(
        const TessdataInstallResult(
          installed: ['eng.traineddata', 'ben.traineddata'],
          missing: [],
        ),
      );
      final service = _service(
        latin,
        bangla,
        installer,
        handwriting: handwriting,
        routingPolicy: policy,
        arbitrator: arbitrator,
      );

      final result = await service.recognize([pages.first]);

      expect(policy.contexts, hasLength(2));
      expect(policy.contexts.first.tesseractHasRun, isFalse);
      expect(policy.contexts.last.tesseractHasRun, isTrue);
      expect(bangla.calls, 1);
      expect(installer.calls, 1);
      expect(handwriting.calls, 1);
      expect(handwriting.images.single, same(pages.first));
      expect(handwriting.hints.single, ScriptHint.banglaHandwriting);
      expect(arbitrator.calls, 1);
      expect(arbitrator.fallback!.engineIds, {'latin', 'bangla'});
      expect(result.engineIds, {'handwriting'});
      expect(result.diagnostics.map((value) => value.code), [
        OcrDiagnosticCode.handwritingProbeRequested,
        OcrDiagnosticCode.handwritingAttempted,
        OcrDiagnosticCode.handwritingAccepted,
      ]);
      expect(result.diagnostics.map((value) => value.engineId), [
        'bangla',
        'handwriting',
        'handwriting',
      ]);
    },
  );

  test('recoverable HTR failure returns the complete baseline', () async {
    final handwriting = _FakeEngine(
      id: 'handwriting',
      text: '',
      confidence: 0,
      top: 0,
      error: const HandwritingModelUnavailableException('not installed'),
    );
    final arbitrator = _RecordingArbitrator();
    final service = _service(
      _FakeEngine(id: 'latin', text: 'Grand Total', confidence: 0.95, top: 0),
      _FakeEngine(id: 'bangla', text: 'মোট', confidence: 0.9, top: 50),
      _FakeInstaller(
        const TessdataInstallResult(
          installed: ['eng.traineddata', 'ben.traineddata'],
          missing: [],
        ),
      ),
      handwriting: handwriting,
      routingPolicy: _SequenceRoutingPolicy(const [
        HandwritingRouteAction.attemptHandwriting,
      ]),
      arbitrator: arbitrator,
    );

    final result = await service.recognize([pages.first]);

    expect(result.engineIds, {'latin', 'bangla'});
    expect(result.text, contains('Grand Total'));
    expect(result.text, contains('মোট'));
    expect(arbitrator.calls, 0);
    expect(result.diagnostics.map((value) => value.code), [
      OcrDiagnosticCode.handwritingAttempted,
      OcrDiagnosticCode.handwritingRecoverableFailure,
    ]);
  });

  test('invalid HTR output is rejected as a recoverable result', () async {
    final handwriting = _FakeEngine(
      id: 'handwriting',
      text: 'হাতের লেখা',
      confidence: double.nan,
      top: 20,
    );
    final arbitrator = _RecordingArbitrator();
    final service = _service(
      _FakeEngine(id: 'latin', text: 'Total', confidence: 0.95, top: 0),
      _FakeEngine(id: 'bangla', text: 'মোট', confidence: 0.9, top: 50),
      _FakeInstaller(
        const TessdataInstallResult(
          installed: ['eng.traineddata', 'ben.traineddata'],
          missing: [],
        ),
      ),
      handwriting: handwriting,
      routingPolicy: _SequenceRoutingPolicy(const [
        HandwritingRouteAction.attemptHandwriting,
      ]),
      arbitrator: arbitrator,
    );

    final result = await service.recognize([pages.first]);

    expect(result.engineIds, {'latin', 'bangla'});
    expect(arbitrator.calls, 0);
    expect(result.diagnostics.map((value) => value.code), [
      OcrDiagnosticCode.handwritingAttempted,
      OcrDiagnosticCode.handwritingInvalid,
    ]);
  });

  test('HTR output cannot advertise an unrelated engine', () async {
    final arbitrator = _RecordingArbitrator();
    final service = _service(
      _FakeEngine(id: 'latin', text: 'Total', confidence: 0.95, top: 0),
      _FakeEngine(id: 'bangla', text: 'মোট', confidence: 0.9, top: 50),
      _FakeInstaller(
        const TessdataInstallResult(
          installed: ['eng.traineddata', 'ben.traineddata'],
          missing: [],
        ),
      ),
      handwriting: _FakeEngine(
        id: 'handwriting',
        text: 'হাতের লেখা',
        confidence: 0.9,
        top: 20,
        extraEngineIds: const {'unrelated'},
      ),
      routingPolicy: _SequenceRoutingPolicy(const [
        HandwritingRouteAction.attemptHandwriting,
      ]),
      arbitrator: arbitrator,
    );

    final result = await service.recognize([pages.first]);

    expect(result.engineIds, {'latin', 'bangla'});
    expect(arbitrator.calls, 0);
    expect(result.diagnostics.map((value) => value.code), [
      OcrDiagnosticCode.handwritingAttempted,
      OcrDiagnosticCode.handwritingInvalid,
    ]);
  });

  test('empty HTR output preserves fallback without arbitration', () async {
    final arbitrator = _RecordingArbitrator();
    final service = _service(
      _FakeEngine(id: 'latin', text: 'Total', confidence: 0.95, top: 0),
      _FakeEngine(id: 'bangla', text: 'মোট', confidence: 0.9, top: 50),
      _FakeInstaller(
        const TessdataInstallResult(
          installed: ['eng.traineddata', 'ben.traineddata'],
          missing: [],
        ),
      ),
      handwriting: _FakeEngine(
        id: 'handwriting',
        text: '',
        confidence: 0,
        top: 0,
      ),
      routingPolicy: _SequenceRoutingPolicy(const [
        HandwritingRouteAction.attemptHandwriting,
      ]),
      arbitrator: arbitrator,
    );

    final result = await service.recognize([pages.first]);

    expect(result.engineIds, {'latin', 'bangla'});
    expect(arbitrator.calls, 0);
    expect(result.diagnostics.map((value) => value.code), [
      OcrDiagnosticCode.handwritingAttempted,
      OcrDiagnosticCode.handwritingEmpty,
    ]);
  });

  test('unexpected HTR failures are not hidden by fallback', () async {
    final service = _service(
      _FakeEngine(id: 'latin', text: 'Total', confidence: 0.95, top: 0),
      _FakeEngine(id: 'bangla', text: 'মোট', confidence: 0.9, top: 50),
      _FakeInstaller(
        const TessdataInstallResult(
          installed: ['eng.traineddata', 'ben.traineddata'],
          missing: [],
        ),
      ),
      handwriting: _FakeEngine(
        id: 'handwriting',
        text: '',
        confidence: 0,
        top: 0,
        error: StateError('programmer defect'),
      ),
      routingPolicy: _SequenceRoutingPolicy(const [
        HandwritingRouteAction.attemptHandwriting,
      ]),
      arbitrator: _RecordingArbitrator(),
    );

    await expectLater(
      service.recognize([pages.first]),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'failed Tesseract probe is exposed to policy and does not block healthy HTR',
    () async {
      final policy = _SequenceRoutingPolicy(const [
        HandwritingRouteAction.requestBanglaProbe,
        HandwritingRouteAction.attemptHandwriting,
      ]);
      final installer = _FakeInstaller(
        const TessdataInstallResult(
          installed: ['eng.traineddata'],
          missing: ['ben.traineddata'],
        ),
      );
      final service = _service(
        _FakeEngine(
          id: 'latin',
          text: 'uncertain text',
          confidence: 0.8,
          top: 0,
        ),
        _FakeEngine(id: 'bangla', text: 'মোট', confidence: 0.9, top: 50),
        installer,
        handwriting: _FakeEngine(
          id: 'handwriting',
          text: 'হাতের লেখা',
          confidence: 0.9,
          top: 20,
        ),
        routingPolicy: policy,
        arbitrator: _RecordingArbitrator(),
      );

      final result = await service.recognize([pages.first]);

      expect(policy.contexts, hasLength(2));
      expect(policy.contexts.last.tesseractUnavailable, isTrue);
      expect(installer.calls, 1);
      expect(result.engineIds, {'handwriting'});
      expect(result.diagnostics.map((value) => value.code), [
        OcrDiagnosticCode.handwritingProbeRequested,
        OcrDiagnosticCode.handwritingFallbackUnavailable,
        OcrDiagnosticCode.handwritingAttempted,
        OcrDiagnosticCode.handwritingAccepted,
      ]);
      expect(result.diagnostics.map((value) => value.engineId), [
        'bangla',
        'bangla',
        'handwriting',
        'handwriting',
      ]);
    },
  );

  test('failed requested probe cannot finish with an empty baseline', () async {
    final service = _service(
      _FakeEngine(id: 'latin', text: '', confidence: 0, top: 0),
      _FakeEngine(id: 'bangla', text: 'মোট', confidence: 0.9, top: 50),
      _FakeInstaller(
        const TessdataInstallResult(
          installed: ['eng.traineddata'],
          missing: ['ben.traineddata'],
        ),
      ),
      routingPolicy: _SequenceRoutingPolicy(const [
        HandwritingRouteAction.requestBanglaProbe,
        HandwritingRouteAction.finishBaseline,
      ]),
    );

    await expectLater(
      service.recognize([pages.first]),
      throwsA(isA<BanglaOcrUnavailableException>()),
    );
  });

  test('routing policy cannot mutate the live post-probe baseline', () async {
    final service = _service(
      _FakeEngine(id: 'latin', text: 'baseline', confidence: 0.9, top: 0),
      _FakeEngine(id: 'bangla', text: 'মোট', confidence: 0.9, top: 50),
      _FakeInstaller(
        const TessdataInstallResult(
          installed: ['eng.traineddata', 'ben.traineddata'],
          missing: [],
        ),
      ),
      routingPolicy: _MutatingSecondCallPolicy(),
    );

    final result = await service.recognize([pages.first]);

    expect(result.text, contains('baseline'));
    expect(result.text, contains('মোট'));
    expect(result.engineIds, {'latin', 'bangla'});
  });

  test('a repeated Tesseract probe request is a router defect', () async {
    final bangla = _FakeEngine(
      id: 'bangla',
      text: 'মোট',
      confidence: 0.9,
      top: 50,
    );
    final service = _service(
      _FakeEngine(id: 'latin', text: 'baseline', confidence: 0.8, top: 0),
      bangla,
      _FakeInstaller(
        const TessdataInstallResult(
          installed: ['eng.traineddata', 'ben.traineddata'],
          missing: [],
        ),
      ),
      routingPolicy: _SequenceRoutingPolicy(const [
        HandwritingRouteAction.requestBanglaProbe,
        HandwritingRouteAction.requestBanglaProbe,
      ]),
    );

    await expectLater(
      service.recognize([pages.first]),
      throwsA(isA<StateError>()),
    );
    expect(bangla.calls, 1);
  });

  test(
    'fallback and recoverable HTR failures produce one diagnostic each',
    () async {
      final installer = _FakeInstaller(
        const TessdataInstallResult(
          installed: ['eng.traineddata'],
          missing: ['ben.traineddata'],
        ),
      );
      final service = _service(
        _FakeEngine(id: 'latin', text: 'baseline', confidence: 0.9, top: 0),
        _FakeEngine(id: 'bangla', text: 'মোট', confidence: 0.9, top: 50),
        installer,
        handwriting: _FakeEngine(
          id: 'handwriting',
          text: '',
          confidence: 0,
          top: 0,
          error: const HandwritingInferenceException('failed'),
        ),
        routingPolicy: _SequenceRoutingPolicy(const [
          HandwritingRouteAction.attemptHandwriting,
        ]),
        arbitrator: _RecordingArbitrator(),
      );

      final result = await service.recognize([pages.first]);

      expect(result.engineIds, {'latin'});
      expect(installer.calls, 1);
      expect(result.diagnostics.map((value) => value.code), [
        OcrDiagnosticCode.handwritingFallbackUnavailable,
        OcrDiagnosticCode.handwritingAttempted,
        OcrDiagnosticCode.handwritingRecoverableFailure,
      ]);
    },
  );

  test(
    'invalid or unrelated arbitrator output propagates as a defect',
    () async {
      final service = _service(
        _FakeEngine(id: 'latin', text: 'baseline', confidence: 0.9, top: 0),
        _FakeEngine(id: 'bangla', text: 'মোট', confidence: 0.9, top: 50),
        _FakeInstaller(
          const TessdataInstallResult(
            installed: ['eng.traineddata', 'ben.traineddata'],
            missing: [],
          ),
        ),
        handwriting: _FakeEngine(
          id: 'handwriting',
          text: 'হাতের লেখা',
          confidence: 0.9,
          top: 20,
        ),
        routingPolicy: _SequenceRoutingPolicy(const [
          HandwritingRouteAction.attemptHandwriting,
        ]),
        arbitrator: const _FixedArbitrator(
          OcrResult(
            blocks: [
              OcrBlock(
                text: 'unrelated',
                boundingBox: OcrRect(left: 0, top: 0, right: 50, bottom: 20),
                confidence: 0.9,
                script: DetectedScript.latin,
                engineId: 'unrelated',
              ),
            ],
            engineIds: {'unrelated'},
          ),
        ),
      );

      await expectLater(
        service.recognize([pages.first]),
        throwsA(isA<StateError>()),
      );
    },
  );

  test(
    'fallback-only arbitration is recorded and preserves V1 zero geometry',
    () async {
      final arbitrator = _RecordingArbitrator(returnFallback: true);
      final service = _service(
        _FakeEngine(
          id: 'latin',
          text: 'baseline',
          confidence: 0.9,
          top: 0,
          zeroBounds: true,
          diagnostics: const [
            OcrDiagnostic(
              code: OcrDiagnosticCode.handwritingNotRouted,
              pageIndex: 0,
              engineId: 'latin',
              detail: 'baseline-evidence',
            ),
          ],
        ),
        _FakeEngine(
          id: 'bangla',
          text: '',
          confidence: 0,
          top: 50,
          diagnostics: const [
            OcrDiagnostic(
              code: OcrDiagnosticCode.handwritingAttempted,
              pageIndex: 0,
              engineId: 'bangla',
              detail: 'fallback-evidence',
            ),
          ],
        ),
        _FakeInstaller(
          const TessdataInstallResult(
            installed: ['eng.traineddata', 'ben.traineddata'],
            missing: [],
          ),
        ),
        handwriting: _FakeEngine(
          id: 'handwriting',
          text: 'হাতের লেখা',
          confidence: 0.9,
          top: 20,
          diagnostics: const [
            OcrDiagnostic(
              code: OcrDiagnosticCode.handwritingProbeRequested,
              pageIndex: 0,
              engineId: 'handwriting',
              detail: 'model-evidence',
            ),
          ],
        ),
        routingPolicy: _SequenceRoutingPolicy(const [
          HandwritingRouteAction.attemptHandwriting,
        ]),
        arbitrator: arbitrator,
      );

      final result = await service.recognize([pages.first]);

      expect(result.text, 'baseline');
      expect(result.engineIds, {'latin', 'bangla'});
      expect(arbitrator.fallback!.diagnostics, isEmpty);
      expect(arbitrator.handwriting!.diagnostics, isEmpty);
      expect(result.diagnostics.map((value) => value.code), [
        OcrDiagnosticCode.handwritingAttempted,
        OcrDiagnosticCode.handwritingFallbackSelected,
      ]);
      expect(
        result.diagnostics.map((value) => value.detail),
        isNot(
          contains(
            anyOf('baseline-evidence', 'fallback-evidence', 'model-evidence'),
          ),
        ),
      );
    },
  );

  test('arbitrator output cannot forge routing diagnostics', () async {
    final service = _service(
      _FakeEngine(id: 'latin', text: 'baseline', confidence: 0.9, top: 0),
      _FakeEngine(id: 'bangla', text: '', confidence: 0, top: 50),
      _FakeInstaller(
        const TessdataInstallResult(
          installed: ['eng.traineddata', 'ben.traineddata'],
          missing: [],
        ),
      ),
      handwriting: _FakeEngine(
        id: 'handwriting',
        text: 'হাতের লেখা',
        confidence: 0.9,
        top: 20,
      ),
      routingPolicy: _SequenceRoutingPolicy(const [
        HandwritingRouteAction.attemptHandwriting,
      ]),
      arbitrator: const _DiagnosticForgingArbitrator(),
    );

    final result = await service.recognize([pages.first]);

    expect(result.text, 'baseline');
    expect(result.diagnostics.map((value) => value.code), [
      OcrDiagnosticCode.handwritingAttempted,
      OcrDiagnosticCode.handwritingFallbackSelected,
    ]);
    expect(
      result.diagnostics.map((value) => value.detail),
      isNot(contains('forged-by-arbitrator')),
    );
  });

  test('arbitration cannot rewrite or duplicate HTR source blocks', () async {
    const sourceBlock = OcrBlock(
      text: 'হাতের লেখা',
      boundingBox: OcrRect(left: 0, top: 20, right: 100, bottom: 40),
      confidence: 0.9,
      script: DetectedScript.bangla,
      engineId: 'handwriting',
    );
    const invalidResults = [
      OcrResult(
        blocks: [
          OcrBlock(
            text: 'পরিবর্তিত',
            boundingBox: OcrRect(left: 0, top: 20, right: 100, bottom: 40),
            confidence: 0.9,
            script: DetectedScript.bangla,
            engineId: 'handwriting',
          ),
        ],
        engineIds: {'handwriting'},
      ),
      OcrResult(blocks: [sourceBlock, sourceBlock], engineIds: {'handwriting'}),
    ];

    for (final invalid in invalidResults) {
      final service = _service(
        _FakeEngine(id: 'latin', text: 'baseline', confidence: 0.9, top: 0),
        _FakeEngine(id: 'bangla', text: 'মোট', confidence: 0.9, top: 50),
        _FakeInstaller(
          const TessdataInstallResult(
            installed: ['eng.traineddata', 'ben.traineddata'],
            missing: [],
          ),
        ),
        handwriting: _FakeEngine(
          id: 'handwriting',
          text: 'হাতের লেখা',
          confidence: 0.9,
          top: 20,
        ),
        routingPolicy: _SequenceRoutingPolicy(const [
          HandwritingRouteAction.attemptHandwriting,
        ]),
        arbitrator: _FixedArbitrator(invalid),
      );

      await expectLater(
        service.recognize([pages.first]),
        throwsA(isA<StateError>()),
      );
    }
  });

  test('arbitration validates against pre-call source snapshots', () async {
    final service = _service(
      _FakeEngine(id: 'latin', text: 'baseline', confidence: 0.9, top: 0),
      _FakeEngine(id: 'bangla', text: 'মোট', confidence: 0.9, top: 50),
      _FakeInstaller(
        const TessdataInstallResult(
          installed: ['eng.traineddata', 'ben.traineddata'],
          missing: [],
        ),
      ),
      handwriting: _FakeEngine(
        id: 'handwriting',
        text: 'হাতের লেখা',
        confidence: 0.9,
        top: 20,
      ),
      routingPolicy: _SequenceRoutingPolicy(const [
        HandwritingRouteAction.attemptHandwriting,
      ]),
      arbitrator: const _MutatingArbitrator(),
    );

    await expectLater(
      service.recognize([pages.first]),
      throwsA(isA<StateError>()),
    );
  });

  test('shared iOS Tesseract fallback is not invoked twice for HTR', () async {
    final tesseract = _FakeEngine(
      id: 'tesseract-ben-eng',
      text: 'মোট 125',
      confidence: 0.4,
      top: 0,
    );
    final handwriting = _FakeEngine(
      id: 'handwriting',
      text: 'মোট ১২৫',
      confidence: 0.9,
      top: 20,
    );
    final installer = _FakeInstaller(
      const TessdataInstallResult(
        installed: ['eng.traineddata', 'ben.traineddata'],
        missing: [],
      ),
    );
    final service = OcrService(
      latinEngine: tesseract,
      banglaEngine: tesseract,
      handwritingEngine: handwriting,
      tessdataInstaller: installer,
      latinEngineRequiresTessdata: true,
      handwritingRoutingPolicy: _SequenceRoutingPolicy(const [
        HandwritingRouteAction.attemptHandwriting,
      ]),
      handwritingResultArbitrator: _RecordingArbitrator(),
    );

    final result = await service.recognize([pages.first]);

    expect(result.engineIds, {'handwriting'});
    expect(tesseract.calls, 1);
    expect(handwriting.calls, 1);
    expect(installer.calls, 1);
  });

  test(
    'healthy HTR can recover from an iOS primary Tesseract failure',
    () async {
      final tesseract = _FakeEngine(
        id: 'tesseract-ben-eng',
        text: '',
        confidence: 0,
        top: 0,
        error: const TesseractOcrRuntimeException('iOS', 'native-failed'),
      );
      final handwriting = _FakeEngine(
        id: 'handwriting',
        text: 'মোট ১২৫',
        confidence: 0.9,
        top: 20,
      );
      final policy = _SequenceRoutingPolicy(const [
        HandwritingRouteAction.attemptHandwriting,
      ]);
      final service = OcrService(
        latinEngine: tesseract,
        banglaEngine: tesseract,
        handwritingEngine: handwriting,
        tessdataInstaller: _FakeInstaller(
          const TessdataInstallResult(
            installed: ['eng.traineddata', 'ben.traineddata'],
            missing: [],
          ),
        ),
        latinEngineRequiresTessdata: true,
        handwritingRoutingPolicy: policy,
        handwritingResultArbitrator: _RecordingArbitrator(),
      );

      final result = await service.recognize([pages.first]);

      expect(policy.contexts.single.tesseractUnavailable, isTrue);
      expect(tesseract.calls, 1);
      expect(handwriting.calls, 1);
      expect(result.engineIds, {'handwriting'});
      expect(result.diagnostics.map((value) => value.code), [
        OcrDiagnosticCode.handwritingFallbackUnavailable,
        OcrDiagnosticCode.handwritingAttempted,
        OcrDiagnosticCode.handwritingAccepted,
      ]);
    },
  );

  test(
    'disabled iOS routing preserves the primary Tesseract failure',
    () async {
      final tesseract = _FakeEngine(
        id: 'tesseract-ben-eng',
        text: '',
        confidence: 0,
        top: 0,
        error: const TesseractOcrRuntimeException('iOS', 'native-failed'),
      );
      final handwriting = _FakeEngine(
        id: 'handwriting',
        text: 'মোট ১২৫',
        confidence: 0.9,
        top: 20,
      );
      final service = OcrService(
        latinEngine: tesseract,
        banglaEngine: tesseract,
        handwritingEngine: handwriting,
        tessdataInstaller: _FakeInstaller(
          const TessdataInstallResult(
            installed: ['eng.traineddata', 'ben.traineddata'],
            missing: [],
          ),
        ),
        latinEngineRequiresTessdata: true,
      );

      await expectLater(
        service.recognize([pages.first]),
        throwsA(isA<TesseractOcrRuntimeException>()),
      );
      expect(tesseract.calls, 1);
      expect(handwriting.calls, 0);
    },
  );

  test('dual iOS OCR failure does not become a silent empty result', () async {
    final tesseract = _FakeEngine(
      id: 'tesseract-ben-eng',
      text: '',
      confidence: 0,
      top: 0,
      error: const TesseractOcrRuntimeException('iOS', 'native-failed'),
    );
    final handwriting = _FakeEngine(
      id: 'handwriting',
      text: '',
      confidence: 0,
      top: 20,
      error: const HandwritingModelLoadException('model failed'),
    );
    final service = OcrService(
      latinEngine: tesseract,
      banglaEngine: tesseract,
      handwritingEngine: handwriting,
      tessdataInstaller: _FakeInstaller(
        const TessdataInstallResult(
          installed: ['eng.traineddata', 'ben.traineddata'],
          missing: [],
        ),
      ),
      latinEngineRequiresTessdata: true,
      handwritingRoutingPolicy: _SequenceRoutingPolicy(const [
        HandwritingRouteAction.attemptHandwriting,
      ]),
      handwritingResultArbitrator: _RecordingArbitrator(),
    );

    await expectLater(
      service.recognize([pages.first]),
      throwsA(isA<TesseractOcrRuntimeException>()),
    );
    expect(tesseract.calls, 1);
    expect(handwriting.calls, 1);
  });
}

OcrService _service(
  OcrEngine latin,
  OcrEngine bangla,
  TessdataInstaller installer, {
  OcrEngine? handwriting,
  HandwritingRoutingPolicy routingPolicy =
      const DisabledHandwritingRoutingPolicy(),
  HandwritingResultArbitrator arbitrator =
      const UnconfiguredHandwritingResultArbitrator(),
}) {
  return OcrService(
    latinEngine: latin,
    banglaEngine: bangla,
    handwritingEngine:
        handwriting ??
        _FakeEngine(id: 'handwriting', text: '', confidence: 0, top: 0),
    tessdataInstaller: installer,
    handwritingRoutingPolicy: routingPolicy,
    handwritingResultArbitrator: arbitrator,
  );
}

class _FakeEngine implements OcrEngine {
  _FakeEngine({
    required this.id,
    required this.text,
    required this.confidence,
    required this.top,
    this.error,
    this.extraEngineIds = const {},
    this.zeroBounds = false,
    this.diagnostics = const [],
  });

  @override
  final String id;
  final String text;
  final double confidence;
  final double top;
  final Object? error;
  final Set<String> extraEngineIds;
  final bool zeroBounds;
  final List<OcrDiagnostic> diagnostics;
  int calls = 0;
  final List<PreprocessedImage> images = [];
  final List<ScriptHint?> hints = [];

  @override
  Set<ScriptHint> get supportedScripts => ScriptHint.values.toSet();

  @override
  Future<OcrResult> recognize(
    PreprocessedImage image, {
    ScriptHint? hint,
  }) async {
    calls++;
    images.add(image);
    hints.add(hint);
    if (error case final error?) throw error;
    final blocks = text.isEmpty
        ? const <OcrBlock>[]
        : [
            OcrBlock(
              text: text,
              boundingBox: zeroBounds
                  ? const OcrRect.empty()
                  : OcrRect(left: 0, top: top, right: 100, bottom: top + 20),
              confidence: confidence,
              script: ScriptDetector.classify(text),
              engineId: id,
              pageIndex: image.pageIndex,
            ),
          ];
    return OcrResult(
      blocks: blocks,
      engineIds: {id, ...extraEngineIds},
      diagnostics: diagnostics,
    );
  }
}

class _SequenceRoutingPolicy implements HandwritingRoutingPolicy {
  _SequenceRoutingPolicy(this.actions) : assert(actions.isNotEmpty);

  final List<HandwritingRouteAction> actions;
  final List<HandwritingRouteContext> contexts = [];

  @override
  Future<HandwritingRouteAction> next(HandwritingRouteContext context) async {
    contexts.add(context);
    final index = (contexts.length - 1).clamp(0, actions.length - 1);
    return actions[index];
  }
}

class _MutatingSecondCallPolicy implements HandwritingRoutingPolicy {
  int calls = 0;

  @override
  Future<HandwritingRouteAction> next(HandwritingRouteContext context) async {
    calls++;
    if (calls == 1) return HandwritingRouteAction.requestBanglaProbe;
    context.baselineResult.blocks.clear();
    context.baselineResult.engineIds.clear();
    return HandwritingRouteAction.finishBaseline;
  }
}

class _RecordingArbitrator implements HandwritingResultArbitrator {
  _RecordingArbitrator({this.returnFallback = false});

  final bool returnFallback;
  int calls = 0;
  OcrResult? fallback;
  OcrResult? handwriting;

  @override
  OcrResult combine({
    required OcrResult fallback,
    required OcrResult handwriting,
  }) {
    calls++;
    this.fallback = fallback;
    this.handwriting = handwriting;
    return returnFallback ? fallback : handwriting;
  }
}

class _FixedArbitrator implements HandwritingResultArbitrator {
  const _FixedArbitrator(this.result);

  final OcrResult result;

  @override
  OcrResult combine({
    required OcrResult fallback,
    required OcrResult handwriting,
  }) => result;
}

class _DiagnosticForgingArbitrator implements HandwritingResultArbitrator {
  const _DiagnosticForgingArbitrator();

  @override
  OcrResult combine({
    required OcrResult fallback,
    required OcrResult handwriting,
  }) => OcrResult(
    blocks: fallback.blocks,
    engineIds: fallback.engineIds,
    diagnostics: const [
      OcrDiagnostic(
        code: OcrDiagnosticCode.handwritingAccepted,
        pageIndex: 0,
        engineId: 'arbitrator',
        detail: 'forged-by-arbitrator',
      ),
    ],
  );
}

class _MutatingArbitrator implements HandwritingResultArbitrator {
  const _MutatingArbitrator();

  @override
  OcrResult combine({
    required OcrResult fallback,
    required OcrResult handwriting,
  }) {
    final source = fallback.blocks.first;
    final fabricated = OcrBlock(
      text: 'fabricated',
      boundingBox: source.boundingBox,
      confidence: source.confidence,
      script: source.script,
      engineId: source.engineId,
      pageIndex: source.pageIndex,
    );
    fallback.blocks
      ..clear()
      ..add(fabricated);
    return OcrResult(blocks: fallback.blocks, engineIds: fallback.engineIds);
  }
}

class _FakeInstaller extends TessdataInstaller {
  _FakeInstaller(this.result);

  final TessdataInstallResult result;
  int calls = 0;

  @override
  Future<TessdataInstallResult> install() async {
    calls++;
    return result;
  }
}
