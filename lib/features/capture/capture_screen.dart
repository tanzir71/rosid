import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rosid/core/extensions/l10n_extension.dart';
import 'package:rosid/core/profile/app_profile.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/features/capture/capture_session.dart';
import 'package:rosid/features/review/review_cleanup.dart';

abstract interface class CaptureNativeOperations {
  Future<List<CameraDescription>> availableCameraDescriptions();

  CameraController createCameraController(CameraDescription description);

  bool canTakePicture(CameraController? controller);

  Future<XFile> takePicture(CameraController? controller);

  Future<List<XFile>> pickImages({
    required ScanMode mode,
    required double maximumDimension,
  });

  Future<List<XFile>> retrieveLostGalleryFiles();

  Future<void> deleteTemporaryCameraFile(String path);

  Future<void> deleteTemporaryGalleryFile(String path);
}

class PlatformCaptureNativeOperations implements CaptureNativeOperations {
  const PlatformCaptureNativeOperations();

  @override
  Future<List<CameraDescription>> availableCameraDescriptions() =>
      availableCameras();

  @override
  CameraController createCameraController(CameraDescription description) =>
      CameraController(
        description,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

  @override
  bool canTakePicture(CameraController? controller) =>
      controller?.value.isInitialized ?? false;

  @override
  Future<XFile> takePicture(CameraController? controller) {
    if (!canTakePicture(controller)) {
      throw StateError('The camera is not ready.');
    }
    return controller!.takePicture();
  }

  @override
  Future<List<XFile>> pickImages({
    required ScanMode mode,
    required double maximumDimension,
  }) async {
    final picker = ImagePicker();
    if (mode == ScanMode.document) {
      return picker.pickMultiImage(
        imageQuality: 100,
        maxWidth: maximumDimension,
        maxHeight: maximumDimension,
      );
    }
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
      maxWidth: maximumDimension,
      maxHeight: maximumDimension,
    );
    return file == null ? const [] : [file];
  }

  @override
  Future<List<XFile>> retrieveLostGalleryFiles() async {
    if (!Platform.isAndroid) return const [];
    final response = await ImagePicker().retrieveLostData();
    if (response.isEmpty) return const [];
    return response.files ?? [if (response.file != null) response.file!];
  }

  @override
  Future<void> deleteTemporaryCameraFile(String path) => File(path).delete();

  @override
  Future<void> deleteTemporaryGalleryFile(String path) async {
    // Mobile image_picker returns an app-owned cache copy. Desktop file
    // selectors return the user's original path, which must never be deleted.
    if (!Platform.isAndroid && !Platform.isIOS) return;
    await File(path).delete();
  }
}

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({
    super.key,
    this.nativeOperations = const PlatformCaptureNativeOperations(),
    this.initializeCamera = true,
  });

  final CaptureNativeOperations nativeOperations;

  @visibleForTesting
  final bool initializeCamera;

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen>
    with WidgetsBindingObserver {
  static const _maximumImportDimension = 3200.0;

  CameraController? _camera;
  Object? _cameraError;
  bool _flashEnabled = false;
  bool _allowPop = false;
  bool _isClosing = false;
  bool _nativeOperationBusy = false;
  int _nativeOperationGeneration = 0;
  late AppLifecycleState _appLifecycleState;
  int _cameraInitializationGeneration = 0;
  final Set<CameraController> _initializingCameras = {};
  final Set<CameraController> _disposedCameras = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appLifecycleState =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    Future.microtask(
      () => ref.read(captureSessionProvider.notifier).startNew(),
    );
    if (widget.initializeCamera &&
        _appLifecycleState == AppLifecycleState.resumed) {
      unawaited(_initializeCamera());
    }
    unawaited(_discardLostGalleryFiles());
  }

  Future<void> _discardLostGalleryFiles() async {
    try {
      final files = await widget.nativeOperations.retrieveLostGalleryFiles();
      for (final file in files) {
        await _deleteTemporaryGalleryFile(file.path);
      }
    } on Object {
      // Lost picker errors contain no usable path; a later capture retries the
      // platform drain without blocking the current screen.
    }
  }

  Future<void> _initializeCamera() async {
    if (!mounted || _appLifecycleState != AppLifecycleState.resumed) return;
    final token = ++_cameraInitializationGeneration;
    CameraController? controller;
    var published = false;
    try {
      final cameras = await widget.nativeOperations
          .availableCameraDescriptions();
      if (!_isCurrentCameraInitialization(token)) return;
      if (cameras.isEmpty) throw CameraException('none', 'No camera');
      controller = widget.nativeOperations.createCameraController(
        cameras.first,
      );
      _initializingCameras.add(controller);
      await controller.initialize();
      if (!_isCurrentCameraInitialization(token)) return;
      final previous = _camera;
      _initializingCameras.remove(controller);
      setState(() {
        _camera = controller;
        _cameraError = null;
        _flashEnabled = false;
      });
      published = true;
      if (previous != null && !identical(previous, controller)) {
        await _disposeCameraOnce(previous);
      }
    } on Object catch (error) {
      if (_isCurrentCameraInitialization(token)) {
        setState(() => _cameraError = error);
      }
    } finally {
      if (controller != null) {
        _initializingCameras.remove(controller);
        if (!published) await _disposeCameraOnce(controller);
      }
    }
  }

  bool _isCurrentCameraInitialization(int token) =>
      mounted &&
      _appLifecycleState == AppLifecycleState.resumed &&
      token == _cameraInitializationGeneration;

  Future<void> _disposeCameraOnce(CameraController controller) async {
    if (!_disposedCameras.add(controller)) return;
    try {
      await controller.dispose();
    } on Object {
      // Camera teardown is best effort; the generation token prevents reuse.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
    if (!widget.initializeCamera) return;
    if (state == AppLifecycleState.resumed) {
      if (_camera == null || !_camera!.value.isInitialized) {
        unawaited(_initializeCamera());
      }
      return;
    }

    _cameraInitializationGeneration++;
    final controllers = <CameraController>{..._initializingCameras, ?_camera};
    _initializingCameras.clear();
    setState(() {
      _camera = null;
      _flashEnabled = false;
    });
    for (final controller in controllers) {
      unawaited(_disposeCameraOnce(controller));
    }
  }

  @override
  void dispose() {
    _cameraInitializationGeneration++;
    _appLifecycleState = AppLifecycleState.detached;
    _nativeOperationGeneration++;
    _nativeOperationBusy = false;
    WidgetsBinding.instance.removeObserver(this);
    final controllers = <CameraController>{..._initializingCameras, ?_camera};
    _initializingCameras.clear();
    _camera = null;
    for (final controller in controllers) {
      unawaited(_disposeCameraOnce(controller));
    }
    super.dispose();
  }

  Future<void> _capture() async {
    final camera = _camera;
    if (!widget.nativeOperations.canTakePicture(camera)) return;
    final token = _beginNativeOperation();
    if (token == null) return;

    XFile? temporaryFile;
    var shouldOpenCrop = false;
    try {
      temporaryFile = await widget.nativeOperations.takePicture(camera);
      if (!_isCurrentNativeOperation(token)) return;
      final added = await ref
          .read(captureSessionProvider.notifier)
          .addSourcePath(temporaryFile.path);
      if (!_isCurrentNativeOperation(token) || !added) return;
      shouldOpenCrop =
          ref.read(captureSessionProvider).mode == ScanMode.receipt;
    } on Object catch (error) {
      _showNativeOperationError(error, token);
    } finally {
      if (temporaryFile != null) {
        await _deleteTemporaryCameraFile(temporaryFile.path);
      }
      _finishNativeOperation(token);
    }

    if (shouldOpenCrop && mounted && !_isClosing) {
      await context.push('/crop');
    }
  }

  Future<void> _importFromGallery() async {
    final token = _beginNativeOperation();
    if (token == null) return;

    final mode = ref.read(captureSessionProvider).mode;
    List<XFile> temporaryFiles = const [];
    var shouldOpenCrop = false;
    try {
      temporaryFiles = await widget.nativeOperations.pickImages(
        mode: mode,
        maximumDimension: _maximumImportDimension,
      );
      if (!_isCurrentNativeOperation(token) || temporaryFiles.isEmpty) return;
      for (final file in temporaryFiles) {
        if (!_isCurrentNativeOperation(token) ||
            !await ref
                .read(captureSessionProvider.notifier)
                .addSourcePath(file.path)) {
          break;
        }
      }
      shouldOpenCrop =
          _isCurrentNativeOperation(token) &&
          ref.read(captureSessionProvider).pagePaths.isNotEmpty;
    } on Object catch (error) {
      _showNativeOperationError(error, token);
    } finally {
      for (final file in temporaryFiles) {
        await _deleteTemporaryGalleryFile(file.path);
      }
      _finishNativeOperation(token);
    }

    if (shouldOpenCrop && mounted && !_isClosing) {
      await context.push('/crop');
    }
  }

  int? _beginNativeOperation() {
    if (!mounted ||
        _nativeOperationBusy ||
        _isClosing ||
        ref.read(captureSessionProvider).isBusy) {
      return null;
    }
    final token = ++_nativeOperationGeneration;
    setState(() => _nativeOperationBusy = true);
    return token;
  }

  bool _isCurrentNativeOperation(int token) =>
      mounted &&
      !_isClosing &&
      _nativeOperationBusy &&
      token == _nativeOperationGeneration;

  void _finishNativeOperation(int token) {
    if (!_isCurrentNativeOperation(token)) return;
    setState(() => _nativeOperationBusy = false);
  }

  Future<void> _deleteTemporaryCameraFile(String path) async {
    try {
      await widget.nativeOperations.deleteTemporaryCameraFile(path);
    } on Object {
      // The persisted private copy is authoritative; camera cache cleanup is
      // best effort and must also run for stale or failed operations.
    }
  }

  Future<void> _deleteTemporaryGalleryFile(String path) async {
    try {
      await widget.nativeOperations.deleteTemporaryGalleryFile(path);
    } on Object {
      // The persisted private copy is authoritative; picker/cache cleanup is
      // best effort and must also run for stale or failed operations.
    }
  }

  void _showNativeOperationError(Object error, int token) {
    if (!_isCurrentNativeOperation(token)) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error.toString())));
  }

  Future<void> _toggleFlash() async {
    final camera = _camera;
    if (camera == null) return;
    final enabled = !_flashEnabled;
    await camera.setFlashMode(enabled ? FlashMode.torch : FlashMode.off);
    if (mounted) setState(() => _flashEnabled = enabled);
  }

  Future<void> _discardAndClose() async {
    if (_isClosing ||
        _nativeOperationBusy ||
        ref.read(captureSessionProvider).isBusy) {
      return;
    }
    setState(() => _isClosing = true);
    try {
      await ref.read(captureSessionProvider.notifier).discard();
      clearProcessingAndReview(ref);
      if (!mounted) return;
      setState(() => _allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      Navigator.of(context).pop();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _isClosing = false);
      if (ref.read(captureSessionProvider).errorMessage == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(captureSessionProvider);
    final expenseEnabled = ref.watch(expenseTrackingEnabledProvider);
    final interactionBlocked =
        session.isBusy || _nativeOperationBusy || _isClosing;
    ref.listen(captureSessionProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
    });

    return PopScope<void>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !interactionBlocked) _discardAndClose();
      },
      child: Scaffold(
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
                      key: const ValueKey('capture-close'),
                      onPressed: interactionBlocked ? null : _discardAndClose,
                      icon: const Icon(Icons.close),
                    ),
                    const Spacer(),
                    IconButton.filledTonal(
                      onPressed: interactionBlocked || _camera == null
                          ? null
                          : _toggleFlash,
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
                            onSelectionChanged: interactionBlocked
                                ? null
                                : (selection) => ref
                                      .read(captureSessionProvider.notifier)
                                      .setMode(selection.single),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              key: const ValueKey('capture-gallery'),
                              onPressed: interactionBlocked
                                  ? null
                                  : _importFromGallery,
                              tooltip: context.l10n.gallery,
                              color: Colors.white,
                              icon: const Icon(Icons.photo_library_outlined),
                            ),
                            FilledButton.tonal(
                              key: const ValueKey('capture-shutter'),
                              onPressed:
                                  interactionBlocked ||
                                      !widget.nativeOperations.canTakePicture(
                                        _camera,
                                      )
                                  ? null
                                  : _capture,
                              style: FilledButton.styleFrom(
                                shape: const CircleBorder(),
                                padding: const EdgeInsets.all(22),
                              ),
                              child: session.isBusy || _nativeOperationBusy
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
                                onPressed: interactionBlocked
                                    ? null
                                    : () => context.push('/crop'),
                                child: Text(context.l10n.done),
                              )
                            else
                              _LanguagePicker(
                                session: session,
                                enabled: !interactionBlocked,
                              ),
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
      ),
    );
  }
}

class _LanguagePicker extends ConsumerWidget {
  const _LanguagePicker({required this.session, required this.enabled});

  final CaptureSession session;
  final bool enabled;

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
        onChanged: enabled
            ? (value) {
                if (value != null) {
                  ref
                      .read(captureSessionProvider.notifier)
                      .setLanguageHint(value);
                }
              }
            : null,
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
