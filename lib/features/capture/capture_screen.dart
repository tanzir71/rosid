import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rosid/core/extensions/l10n_extension.dart';
import 'package:rosid/core/profile/app_profile.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/features/capture/capture_session.dart';

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  Object? _cameraError;
  bool _flashEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(
      () => ref.read(captureSessionProvider.notifier).startNew(),
    );
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw CameraException('none', 'No camera');
      final controller = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _camera = controller);
    } on Object catch (error) {
      if (mounted) setState(() => _cameraError = error);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      camera.dispose();
      _camera = null;
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) return;
    final file = await camera.takePicture();
    final added = await ref
        .read(captureSessionProvider.notifier)
        .addSourcePath(file.path);
    if (!mounted || !added) return;
    if (ref.read(captureSessionProvider).mode == ScanMode.receipt) {
      await context.push('/crop');
    }
  }

  Future<void> _importFromGallery() async {
    final picker = ImagePicker();
    final mode = ref.read(captureSessionProvider).mode;
    final files = mode == ScanMode.document
        ? await picker.pickMultiImage(imageQuality: 100)
        : [
            await picker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 100,
            ),
          ].whereType<XFile>().toList();
    if (files.isEmpty) return;
    for (final file in files) {
      if (!await ref
          .read(captureSessionProvider.notifier)
          .addSourcePath(file.path)) {
        break;
      }
    }
    if (mounted && ref.read(captureSessionProvider).pagePaths.isNotEmpty) {
      await context.push('/crop');
    }
  }

  Future<void> _toggleFlash() async {
    final camera = _camera;
    if (camera == null) return;
    final enabled = !_flashEnabled;
    await camera.setFlashMode(enabled ? FlashMode.torch : FlashMode.off);
    if (mounted) setState(() => _flashEnabled = enabled);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(captureSessionProvider);
    final expenseEnabled = ref.watch(expenseTrackingEnabledProvider);
    ref.listen(captureSessionProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_camera?.value.isInitialized ?? false)
              CameraPreview(_camera!)
            else
              _CameraFallback(error: _cameraError),
            const _DocumentGuide(),
            Positioned(
              left: 12,
              right: 12,
              top: 8,
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.close),
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    onPressed: _camera == null ? null : _toggleFlash,
                    tooltip: context.l10n.flash,
                    icon: Icon(
                      _flashEnabled ? Icons.flash_on : Icons.flash_off,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 18,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.74),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (expenseEnabled)
                        SegmentedButton<ScanMode>(
                          segments: [
                            ButtonSegment(
                              value: ScanMode.receipt,
                              label: Text(context.l10n.receipt),
                              icon: const Icon(Icons.receipt_long),
                            ),
                            ButtonSegment(
                              value: ScanMode.document,
                              label: Text(context.l10n.document),
                              icon: const Icon(Icons.description_outlined),
                            ),
                          ],
                          selected: {session.mode},
                          onSelectionChanged: (selection) => ref
                              .read(captureSessionProvider.notifier)
                              .setMode(selection.single),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: session.isBusy
                                ? null
                                : _importFromGallery,
                            tooltip: context.l10n.gallery,
                            color: Colors.white,
                            icon: const Icon(Icons.photo_library_outlined),
                          ),
                          FilledButton.tonal(
                            onPressed: session.isBusy ? null : _capture,
                            style: FilledButton.styleFrom(
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(22),
                            ),
                            child: session.isBusy
                                ? const SizedBox.square(
                                    dimension: 28,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                    ),
                                  )
                                : const Icon(Icons.camera_alt, size: 32),
                          ),
                          if (session.mode == ScanMode.document &&
                              session.pagePaths.isNotEmpty)
                            FilledButton(
                              onPressed: () => context.push('/crop'),
                              child: Text(context.l10n.done),
                            )
                          else
                            _LanguagePicker(session: session),
                        ],
                      ),
                      if (session.pagePaths.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          context.l10n.pagesCount(session.pagePaths.length),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguagePicker extends ConsumerWidget {
  const _LanguagePicker({required this.session});

  final CaptureSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<CaptureLanguageHint>(
        dropdownColor: Colors.black87,
        value: session.languageHint,
        style: const TextStyle(color: Colors.white),
        iconEnabledColor: Colors.white,
        items: [
          DropdownMenuItem(
            value: CaptureLanguageHint.automatic,
            child: Text(context.l10n.automatic),
          ),
          DropdownMenuItem(
            value: CaptureLanguageHint.banglaEnglish,
            child: Text(context.l10n.mixedBanglaEnglish),
          ),
          const DropdownMenuItem(
            value: CaptureLanguageHint.english,
            child: Text('English'),
          ),
        ],
        onChanged: (value) {
          if (value != null) {
            ref.read(captureSessionProvider.notifier).setLanguageHint(value);
          }
        },
      ),
    );
  }
}

class _CameraFallback extends StatelessWidget {
  const _CameraFallback({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF1B211E),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            error == null
                ? context.l10n.processing
                : context.l10n.cameraUnavailable,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  }
}

class _DocumentGuide extends StatelessWidget {
  const _DocumentGuide();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.86,
          heightFactor: 0.58,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white70, width: 2),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
    );
  }
}
