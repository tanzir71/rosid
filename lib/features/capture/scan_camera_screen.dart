import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rosid/core/extensions/l10n_extension.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/core/theme/rosid_icons.dart';
import 'package:rosid/core/theme/tokens.g.dart';
import 'package:rosid/core/utils/bangla_digits.dart';
import 'package:rosid/core/widgets/rosid_paper_thumbnail.dart';
import 'package:rosid/features/capture/fake_capture_source.dart';
import 'package:rosid/features/capture/frame_analyzer.dart';
import 'package:rosid/features/capture/scan_controller.dart';
import 'package:rosid/ocr/preprocess/document_quad.dart';

/// Optional provider for injecting a [FakeCaptureSource] in tests or debug
/// runs with `--dart-define=ROSID_FAKE_CAMERA=true`. Always `null` in release.
final fakeCaptureSourceProvider = Provider<CaptureFrameSource?>((ref) => null);

/// Scan camera screen matching `design/screens/scan-camera.png` and
/// `design/screens/scan-id-card-back.png`.
class ScanCameraScreen extends ConsumerStatefulWidget {
  const ScanCameraScreen({
    super.key,
    this.initialMode = V2ScanMode.document,
    this.initializeCamera = true,
    this.useBackgroundIsolate = true,
    this.previewBackground,
    this.previewQuad,
    this.previewHint,
    this.previewSteadyProgress,
  });

  final V2ScanMode initialMode;

  @visibleForTesting
  final bool initializeCamera;

  @visibleForTesting
  final bool useBackgroundIsolate;

  /// Optional preview content for deterministic golden tests.
  @visibleForTesting
  final Widget? previewBackground;

  @visibleForTesting
  final DocumentQuad? previewQuad;

  @visibleForTesting
  final CaptureQualityHint? previewHint;

  @visibleForTesting
  final double? previewSteadyProgress;

  @override
  ConsumerState<ScanCameraScreen> createState() => _ScanCameraScreenState();
}

class _ScanCameraScreenState extends ConsumerState<ScanCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  bool _cameraReady = false;
  bool _cameraDeniedOrUnavailable = false;
  bool _flashOn = false;
  bool _capturing = false;
  bool _streaming = false;

  FrameAnalyzerIsolate? _isolate;
  FrameAnalyzer? _directAnalyzer;
  bool _analyzingFrame = false;
  FrameAnalysisResult? _lastAnalysis;
  Uint8List? _fakePreviewBytes;
  StreamSubscription<CaptureFrame>? _fakeSub;
  DateTime _lastAutoCaptureAt = DateTime.fromMillisecondsSinceEpoch(0);
  final List<int> _frameTimingsMs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      if (!mounted) return;
      final scanState = ref.read(v2ScanProvider);
      if (scanState.pages.isEmpty) {
        ref.read(v2ScanProvider.notifier).startSession(widget.initialMode);
      }
      _startCapturePipeline();
    });
  }

  Future<void> _startCapturePipeline() async {
    if (!mounted) return;
    if (widget.previewBackground != null) return;

    final fakeSource = kReleaseMode
        ? null
        : ref.read(fakeCaptureSourceProvider);
    if (fakeSource != null) {
      if (widget.useBackgroundIsolate) {
        _isolate ??= await FrameAnalyzerIsolate.spawn();
      } else {
        _directAnalyzer ??= FrameAnalyzer();
      }
      _fakeSub = fakeSource.frames.listen(_handleFakeFrame);
      return;
    }

    if (!widget.initializeCamera) return;
    await _initLiveCamera();
  }

  Future<void> _initLiveCamera() async {
    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        setState(() => _cameraDeniedOrUnavailable = true);
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _isolate ??= await FrameAnalyzerIsolate.spawn();
      setState(() {
        _camera = controller;
        _cameraReady = true;
        _cameraDeniedOrUnavailable = false;
      });
      await _startImageStream(controller);
    } on Object {
      if (mounted) {
        setState(() => _cameraDeniedOrUnavailable = true);
      }
    }
  }

  Future<void> _startImageStream(CameraController controller) async {
    if (_streaming || !controller.value.isInitialized) return;
    try {
      _streaming = true;
      await controller.startImageStream(_handleCameraImage);
    } on Object {
      _streaming = false;
    }
  }

  void _handleCameraImage(CameraImage image) {
    if (_analyzingFrame || _capturing || _isolate == null || !mounted) return;
    if (image.planes.isEmpty) return;
    _analyzingFrame = true;

    // Stride-downsample Y plane to <= 320 px on long side without copying full
    // multi-megapixel buffers.
    final yPlane = image.planes.first;
    final srcW = image.width;
    final srcH = image.height;
    final stride = math.max(1, (math.max(srcW, srcH) / 320.0).ceil());
    final dstW = math.max(1, srcW ~/ stride);
    final dstH = math.max(1, srcH ~/ stride);
    final luma = Uint8List(dstW * dstH);
    final rowStride = yPlane.bytesPerRow;
    final src = yPlane.bytes;

    var outIdx = 0;
    for (var y = 0; y < dstH; y++) {
      final rowOff = (y * stride) * rowStride;
      for (var x = 0; x < dstW; x++) {
        final idx = rowOff + (x * stride);
        luma[outIdx++] = idx < src.length ? src[idx] : 0;
      }
    }

    unawaited(
      _isolate!
          .analyzeLuma(luma, width: dstW, height: dstH)
          .then(_onFrameResult)
          .catchError((Object _) {
            _analyzingFrame = false;
          }),
    );
  }

  void _handleFakeFrame(CaptureFrame frame) {
    if (!mounted) return;
    setState(() => _fakePreviewBytes = frame.bytes);
    if (_analyzingFrame || _capturing) return;
    if (_directAnalyzer != null) {
      _analyzingFrame = true;
      final res = _directAnalyzer!.analyzeEncoded(
        frame.bytes,
        skipBlurCheck: true,
      );
      _onFrameResult(res);
      return;
    }
    if (_isolate == null) return;
    _analyzingFrame = true;
    unawaited(
      _isolate!
          .analyzeEncoded(frame.bytes, skipBlurCheck: true)
          .then(_onFrameResult)
          .catchError((Object _) {
            _analyzingFrame = false;
          }),
    );
  }

  void _onFrameResult(FrameAnalysisResult result) {
    _analyzingFrame = false;
    if (!mounted) return;
    _frameTimingsMs.add(result.elapsedMs);
    if (_frameTimingsMs.length == 20 && kDebugMode) {
      final sorted = List<int>.from(_frameTimingsMs)..sort();
      debugPrint(
        '[M2] FrameAnalyzer median=${sorted[sorted.length ~/ 2]}ms '
        '(n=${sorted.length})',
      );
    }

    setState(() => _lastAnalysis = result);

    final scanState = ref.read(v2ScanProvider);
    final cooledDown =
        DateTime.now().difference(_lastAutoCaptureAt).inMilliseconds > 1400;
    if (scanState.autoCapture && result.isSteady && !_capturing && cooledDown) {
      _lastAutoCaptureAt = DateTime.now();
      unawaited(_captureNow());
    }
  }

  Future<void> _captureNow() async {
    if (_capturing || !mounted) return;
    setState(() => _capturing = true);
    try {
      final detectedQuad = _lastAnalysis?.quad;
      final fakeSource = kReleaseMode
          ? null
          : ref.read(fakeCaptureSourceProvider);
      if (fakeSource != null) {
        final bytes = await fakeSource.captureStill();
        await ref
            .read(v2ScanProvider.notifier)
            .addCapturedBytes(bytes, detectedQuad: detectedQuad);
      } else {
        final camera = _camera;
        if (camera == null || !camera.value.isInitialized) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(context.l10n.captureFailed)));
          }
          return;
        }
        if (_streaming) {
          try {
            await camera.stopImageStream();
          } on Object {
            // Some emulators fail stopImageStream when already paused.
          }
          _streaming = false;
        }
        final file = await camera.takePicture();
        try {
          await ref
              .read(v2ScanProvider.notifier)
              .addCapturedFile(file.path, detectedQuad: detectedQuad);
        } finally {
          try {
            await File(file.path).delete();
          } on Object {
            // Best-effort temp cleanup.
          }
        }
        if (mounted && _camera != null && _camera!.value.isInitialized) {
          await _startImageStream(_camera!);
        }
      }

      _isolate?.reset();
      _directAnalyzer?.reset();
      if (!mounted) return;
      final updated = ref.read(v2ScanProvider);
      if (updated.isIdComplete) {
        context.push('/scan/adjust');
      } else if (updated.mode == V2ScanMode.receipt) {
        context.push('/scan/adjust');
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.captureFailed)));
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _importFromGallery() async {
    if (_capturing) return;
    setState(() => _capturing = true);
    try {
      final picker = ImagePicker();
      final mode = ref.read(v2ScanProvider).mode;
      final List<XFile> picked;
      if (mode == V2ScanMode.document || mode == V2ScanMode.translate) {
        picked = await picker.pickMultiImage(imageQuality: 100);
      } else {
        final single = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 100,
        );
        picked = single == null ? const [] : [single];
      }
      if (picked.isEmpty || !mounted) return;
      _isolate ??= await FrameAnalyzerIsolate.spawn();
      for (final file in picked) {
        final bytes = await File(file.path).readAsBytes();
        final analysis = await _isolate!.analyzeEncoded(
          bytes,
          skipBlurCheck: true,
        );
        await ref
            .read(v2ScanProvider.notifier)
            .addCapturedFile(file.path, detectedQuad: analysis.quad);
      }
      if (mounted && ref.read(v2ScanProvider).pages.isNotEmpty) {
        await context.push('/scan/adjust');
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.captureFailed)));
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _toggleFlash() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) return;
    final next = !_flashOn;
    try {
      await camera.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _flashOn = next);
    } on Object {
      // Emulator cameras without flash silently ignore torch requests.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      final cam = _camera;
      _camera = null;
      _cameraReady = false;
      _streaming = false;
      if (cam != null) {
        unawaited(cam.dispose());
      }
    } else if (widget.initializeCamera &&
        widget.previewBackground == null &&
        (kReleaseMode || ref.read(fakeCaptureSourceProvider) == null)) {
      unawaited(_initLiveCamera());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_fakeSub?.cancel());
    _isolate?.dispose();
    unawaited(_camera?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final scanState = ref.watch(v2ScanProvider);
    final expenseEnabled = ref.watch(expenseTrackingEnabledProvider);

    final activeQuad = widget.previewQuad ?? _lastAnalysis?.quad;
    final activeHint =
        widget.previewHint ?? _lastAnalysis?.hint ?? CaptureQualityHint.noPaper;
    final steadyProgress =
        widget.previewSteadyProgress ?? _lastAnalysis?.steadyProgress ?? 0.0;

    return Scaffold(
      backgroundColor: RosidColorTokens.cameraSceneDark,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildViewfinder(context, scanState),
                if (scanState.mode == V2ScanMode.idCard)
                  const _IdCardGuideOverlay()
                else if (activeQuad != null)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _LiveQuadPainter(quad: activeQuad),
                    ),
                  ),
                Positioned(
                  left: 16,
                  right: 16,
                  top: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          _CameraCircleButton(
                            key: const ValueKey('scan-close'),
                            icon: RosidIcons.close,
                            tooltip: l10n.cancel,
                            onTap: () {
                              ref.read(v2ScanProvider.notifier).clearSession();
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go('/');
                              }
                            },
                          ),
                          const Spacer(),
                          if (scanState.mode == V2ScanMode.idCard)
                            _IdStepPill(isBackStep: scanState.isIdBackStep)
                          else
                            _AutoCapturePill(
                              enabled: scanState.autoCapture,
                              onTap: () => ref
                                  .read(v2ScanProvider.notifier)
                                  .setAutoCapture(!scanState.autoCapture),
                            ),
                          const Spacer(),
                          _CameraCircleButton(
                            key: const ValueKey('scan-flash'),
                            icon: RosidIcons.flash,
                            tooltip: l10n.flash,
                            active: _flashOn,
                            onTap: _toggleFlash,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 18,
                  child: scanState.isIdBackStep
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.turnCardOver,
                              textAlign: TextAlign.center,
                              style: RosidTextTokens.uiTitle.copyWith(
                                color: RosidColorTokens.inkPrimaryDark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.idBothSidesNote,
                              textAlign: TextAlign.center,
                              style: RosidTextTokens.uiCaption.copyWith(
                                color: RosidColorTokens.inkSecondaryDark,
                              ),
                            ),
                          ],
                        )
                      : Center(
                          child: _QualityHintPill(
                            hint: activeHint,
                            label: _hintLabel(context, activeHint),
                          ),
                        ),
                ),
              ],
            ),
          ),
          _CameraBottomBar(
            mode: scanState.mode,
            expenseEnabled: expenseEnabled,
            pages: scanState.pages,
            isIdBackStep: scanState.isIdBackStep,
            steadyProgress: steadyProgress,
            capturing: _capturing,
            locale: locale,
            onModeSelected: (m) => ref.read(v2ScanProvider.notifier).setMode(m),
            onImport: _importFromGallery,
            onShutter: _captureNow,
            onDonePages: () => context.push('/scan/adjust'),
          ),
        ],
      ),
    );
  }

  Widget _buildViewfinder(BuildContext context, V2ScanState scanState) {
    if (widget.previewBackground != null) {
      return widget.previewBackground!;
    }
    if (_fakePreviewBytes != null) {
      return Image.memory(
        _fakePreviewBytes!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }
    if (_cameraReady && _camera != null && _camera!.value.isInitialized) {
      return CameraPreview(_camera!);
    }
    if (_cameraDeniedOrUnavailable) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const RosidIcon(
                RosidIcons.camera,
                size: 40,
                color: RosidColorTokens.inkSecondaryDark,
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.cameraUnavailable,
                textAlign: TextAlign.center,
                style: RosidTextTokens.uiBody.copyWith(
                  color: RosidColorTokens.inkPrimaryDark,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return const ColoredBox(color: RosidColorTokens.cameraSceneDark);
  }

  String _hintLabel(BuildContext context, CaptureQualityHint hint) {
    final l10n = context.l10n;
    return switch (hint) {
      CaptureQualityHint.noPaper => l10n.hintNoPaper,
      CaptureQualityHint.moveCloser => l10n.hintMoveCloser,
      CaptureQualityHint.tooDark => l10n.hintTooDark,
      CaptureQualityHint.glare => l10n.hintGlare,
      CaptureQualityHint.holdSteady => l10n.hintHoldSteady,
      CaptureQualityHint.edgesFoundHoldSteady => l10n.hintEdgesFound,
    };
  }
}

class _CameraCircleButton extends StatelessWidget {
  const _CameraCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
    super.key,
  });

  final RosidIcons icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: const Color(0xCC1A1B2E),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: RosidIcon(
                icon,
                size: 20,
                color: active
                    ? RosidColorTokens.accentBaseDark
                    : RosidColorTokens.inkPrimaryDark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AutoCapturePill extends StatelessWidget {
  const _AutoCapturePill({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xCC1A1B2E),
      borderRadius: BorderRadius.circular(RosidSizeTokens.radiusPill),
      child: InkWell(
        key: const ValueKey('scan-auto-toggle'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(RosidSizeTokens.radiusPill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RosidIcon(
                RosidIcons.wand,
                size: 16,
                color: enabled
                    ? RosidColorTokens.accentBaseDark
                    : RosidColorTokens.inkTertiaryDark,
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.autoCapture,
                style: RosidTextTokens.uiLabel.copyWith(
                  color: enabled
                      ? RosidColorTokens.inkPrimaryDark
                      : RosidColorTokens.inkSecondaryDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdStepPill extends StatelessWidget {
  const _IdStepPill({required this.isBackStep});

  final bool isBackStep;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xCC1A1B2E),
        borderRadius: BorderRadius.circular(RosidSizeTokens.radiusPill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isBackStep) ...[
              const RosidIcon(
                RosidIcons.check,
                size: 15,
                color: RosidColorTokens.goodBaseDark,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              l10n.idFront,
              style: RosidTextTokens.uiLabel.copyWith(
                color: isBackStep
                    ? RosidColorTokens.inkSecondaryDark
                    : RosidColorTokens.inkPrimaryDark,
              ),
            ),
            const SizedBox(width: 8),
            const RosidIcon(
              RosidIcons.chevronRight,
              size: 14,
              color: RosidColorTokens.inkTertiaryDark,
            ),
            const SizedBox(width: 8),
            Text(
              l10n.idBack,
              style: RosidTextTokens.uiLabel.copyWith(
                color: isBackStep
                    ? RosidColorTokens.inkPrimaryDark
                    : RosidColorTokens.inkTertiaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QualityHintPill extends StatelessWidget {
  const _QualityHintPill({required this.hint, required this.label});

  final CaptureQualityHint hint;
  final String label;

  @override
  Widget build(BuildContext context) {
    final (icon, iconColor) = switch (hint) {
      CaptureQualityHint.edgesFoundHoldSteady => (
        RosidIcons.checkCircle,
        RosidColorTokens.goodBaseDark,
      ),
      CaptureQualityHint.tooDark || CaptureQualityHint.glare => (
        RosidIcons.alert,
        RosidColorTokens.warnBaseDark,
      ),
      CaptureQualityHint.noPaper ||
      CaptureQualityHint.moveCloser ||
      CaptureQualityHint.holdSteady => (
        RosidIcons.scan,
        RosidColorTokens.accentBaseDark,
      ),
    };

    return DecoratedBox(
      key: const ValueKey('scan-quality-hint'),
      decoration: BoxDecoration(
        color: const Color(0xE01A1B2E),
        borderRadius: BorderRadius.circular(RosidSizeTokens.radiusPill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RosidIcon(icon, size: 16, color: iconColor),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RosidTextTokens.uiLabel.copyWith(
                  color: RosidColorTokens.inkPrimaryDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraBottomBar extends StatelessWidget {
  const _CameraBottomBar({
    required this.mode,
    required this.expenseEnabled,
    required this.pages,
    required this.isIdBackStep,
    required this.steadyProgress,
    required this.capturing,
    required this.locale,
    required this.onModeSelected,
    required this.onImport,
    required this.onShutter,
    required this.onDonePages,
  });

  final V2ScanMode mode;
  final bool expenseEnabled;
  final List<CapturedPageDraft> pages;
  final bool isIdBackStep;
  final double steadyProgress;
  final bool capturing;
  final Locale locale;
  final ValueChanged<V2ScanMode> onModeSelected;
  final VoidCallback onImport;
  final VoidCallback onShutter;
  final VoidCallback onDonePages;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final visibleModes = <(V2ScanMode, String)>[
      (V2ScanMode.document, l10n.document),
      (V2ScanMode.idCard, l10n.idCard),
      if (expenseEnabled) (V2ScanMode.receipt, l10n.receipt),
    ];

    return Container(
      color: RosidColorTokens.bgCanvasDark,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final (m, label) in visibleModes)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: InkWell(
                      key: ValueKey('scan-mode-${m.name}'),
                      onTap: () => onModeSelected(m),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              label,
                              style: RosidTextTokens.uiLabel.copyWith(
                                color: _isSelectedMode(m)
                                    ? RosidColorTokens.inkPrimaryDark
                                    : RosidColorTokens.inkTertiaryDark,
                              ),
                            ),
                            const SizedBox(height: 5),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              width: 18,
                              height: 3,
                              decoration: BoxDecoration(
                                color: _isSelectedMode(m)
                                    ? RosidColorTokens.accentBaseDark
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _SideActionTile(
                      key: const ValueKey('scan-import'),
                      label: l10n.importPhotos,
                      onTap: capturing ? null : onImport,
                      child: const RosidIcon(
                        RosidIcons.image,
                        size: 22,
                        color: RosidColorTokens.inkPrimaryDark,
                      ),
                    ),
                  ),
                ),
                _ShutterButton(
                  key: const ValueKey('scan-shutter'),
                  progress: steadyProgress,
                  busy: capturing,
                  onTap: capturing ? null : onShutter,
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: pages.isNotEmpty
                        ? _SideActionTile(
                            key: const ValueKey('scan-done-pages'),
                            label: isIdBackStep
                                ? l10n.idFront
                                : localizeDigits(
                                    l10n.donePages(pages.length),
                                    locale,
                                  ),
                            onTap: isIdBackStep || capturing
                                ? null
                                : onDonePages,
                            child: RosidPaperThumbnail(
                              kind: isIdBackStep
                                  ? RosidPaperKind.id
                                  : RosidPaperKind.letter,
                              width: isIdBackStep ? 36 : 28,
                              height: isIdBackStep ? 24 : 36,
                            ),
                          )
                        : const SizedBox(width: 56),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _isSelectedMode(V2ScanMode target) {
    if (mode == V2ScanMode.translate && target == V2ScanMode.document) {
      return true;
    }
    return mode == target;
  }
}

class _SideActionTile extends StatelessWidget {
  const _SideActionTile({
    required this.label,
    required this.child,
    required this.onTap,
    super.key,
  });

  final String label;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RosidSizeTokens.radiusControl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: RosidColorTokens.bgSunkenDark,
              borderRadius: BorderRadius.circular(
                RosidSizeTokens.radiusControl,
              ),
            ),
            child: Center(child: child),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: RosidTextTokens.uiMicro.copyWith(
              color: RosidColorTokens.inkSecondaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({
    required this.progress,
    required this.busy,
    required this.onTap,
    super.key,
  });

  final double progress;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 74,
        height: 74,
        child: CustomPaint(
          painter: _ShutterRingPainter(progress: progress.clamp(0.0, 1.0)),
          child: Center(
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: busy
                    ? RosidColorTokens.inkTertiaryDark
                    : RosidColorTokens.inkPrimaryDark,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShutterRingPainter extends CustomPainter {
  const _ShutterRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 3;
    final basePaint = Paint()
      ..color = const Color(0xFF3D3E52)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawCircle(center, radius, basePaint);

    if (progress > 0.01) {
      final arcPaint = Paint()
        ..color = RosidColorTokens.accentBaseDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ShutterRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _LiveQuadPainter extends CustomPainter {
  const _LiveQuadPainter({required this.quad});

  final DocumentQuad quad;

  @override
  void paint(Canvas canvas, Size size) {
    Offset pt(NormalizedPoint p) => Offset(p.x * size.width, p.y * size.height);
    final tl = pt(quad.topLeft);
    final tr = pt(quad.topRight);
    final br = pt(quad.bottomRight);
    final bl = pt(quad.bottomLeft);

    final path = Path()
      ..moveTo(tl.dx, tl.dy)
      ..lineTo(tr.dx, tr.dy)
      ..lineTo(br.dx, br.dy)
      ..lineTo(bl.dx, bl.dy)
      ..close();

    final fillPaint = Paint()
      ..color = RosidColorTokens.accentBaseDark.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    final strokePaint = Paint()
      ..color = RosidColorTokens.accentBaseDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);

    final fillCircle = Paint()
      ..color = RosidColorTokens.accentBaseDark
      ..style = PaintingStyle.fill;
    final borderCircle = Paint()
      ..color = RosidColorTokens.bgCanvasDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final corner in [tl, tr, br, bl]) {
      canvas.drawCircle(corner, 6.5, fillCircle);
      canvas.drawCircle(corner, 6.5, borderCircle);
    }
  }

  @override
  bool shouldRepaint(covariant _LiveQuadPainter oldDelegate) =>
      oldDelegate.quad != quad;
}

class _IdCardGuideOverlay extends StatelessWidget {
  const _IdCardGuideOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 42),
          child: AspectRatio(
            aspectRatio: 85.6 / 54.0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: RosidColorTokens.accentBaseDark,
                  width: 2.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
