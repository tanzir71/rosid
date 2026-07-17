import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rosid/core/extensions/l10n_extension.dart';
import 'package:rosid/core/profile/app_profile.dart';
import 'package:rosid/features/capture/capture_session.dart';
import 'package:rosid/features/crop/preprocess_controller.dart';
import 'package:rosid/features/review/review_cleanup.dart';
import 'package:rosid/ocr/preprocess/document_quad.dart';
import 'package:rosid/ocr/preprocess/image_preprocessor.dart';

DocumentQuad _detectQuadInBackground(Uint8List bytes) {
  return const ImagePreprocessor().detectDocumentQuad(bytes);
}

class CropEnhanceScreen extends ConsumerStatefulWidget {
  const CropEnhanceScreen({super.key});

  @override
  ConsumerState<CropEnhanceScreen> createState() => _CropEnhanceScreenState();
}

class _CropEnhanceScreenState extends ConsumerState<CropEnhanceScreen> {
  late List<DocumentQuad> _quads;
  late List<int> _quarterTurns;
  var _pageIndex = 0;
  var _showEnhanced = false;
  var _isDetectingEdges = true;

  @override
  void initState() {
    super.initState();
    final paths = ref.read(captureSessionProvider).pagePaths;
    final count = paths.length;
    _quads = List.filled(count, const DocumentQuad.inset());
    _quarterTurns = List.filled(count, 0);
    Future.microtask(() => _detectEdges(paths));
  }

  Future<void> _detectEdges(List<String> paths) async {
    final detected = <DocumentQuad>[];
    for (final path in paths) {
      try {
        final bytes = await File(path).readAsBytes();
        detected.add(await compute(_detectQuadInBackground, bytes));
      } on Object {
        detected.add(const DocumentQuad.inset());
      }
    }
    if (!mounted) return;
    setState(() {
      if (detected.length == _quads.length) _quads = detected;
      _isDetectingEdges = false;
    });
  }

  void _invalidatePreview() {
    clearProcessingAndReview(ref);
    _showEnhanced = false;
  }

  Future<bool> _processPreview() async {
    final session = ref.read(captureSessionProvider);
    final processed = await ref
        .read(preprocessProvider.notifier)
        .process(
          session: session,
          quads: _quads,
          pageRotationQuarterTurns: _quarterTurns,
        );
    if (!mounted || !processed) return false;
    setState(() => _showEnhanced = true);
    return true;
  }

  Future<void> _continue() async {
    final session = ref.read(captureSessionProvider);
    final preprocessing = ref.read(preprocessProvider);
    if (!preprocessing.matches(session)) {
      await _processPreview();
      return;
    }
    final route = session.mode == ScanMode.receipt
        ? '/review/receipt'
        : '/review/document';
    await context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(captureSessionProvider);
    final preprocessing = ref.watch(preprocessProvider);
    final hasCurrentAssets = preprocessing.matches(session);
    if (session.pagePaths.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.cropEnhance)),
        body: Center(child: Text(context.l10n.noDocuments)),
      );
    }
    final enhancedPath =
        hasCurrentAssets && preprocessing.assets.length > _pageIndex
        ? preprocessing.assets[_pageIndex].colorPath
        : null;
    return PopScope<void>(
      canPop: !preprocessing.isProcessing,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.cropEnhance),
          actions: [
            IconButton(
              onPressed: _showEnhanced || preprocessing.isProcessing
                  ? null
                  : () => setState(() {
                      _invalidatePreview();
                      _quarterTurns[_pageIndex] =
                          (_quarterTurns[_pageIndex] + 1) % 4;
                    }),
              tooltip: context.l10n.rotate,
              icon: const Icon(Icons.rotate_right),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: PageView.builder(
                physics: preprocessing.isProcessing
                    ? const NeverScrollableScrollPhysics()
                    : null,
                itemCount: session.pagePaths.length,
                onPageChanged: (index) => setState(() => _pageIndex = index),
                itemBuilder: (context, index) {
                  final itemEnhanced =
                      hasCurrentAssets && preprocessing.assets.length > index
                      ? preprocessing.assets[index].colorPath
                      : null;
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: _QuadEditor(
                      imagePath: _showEnhanced && itemEnhanced != null
                          ? itemEnhanced
                          : session.pagePaths[index],
                      quad: _quads[index],
                      quarterTurns: _showEnhanced && itemEnhanced != null
                          ? 0
                          : _quarterTurns[index],
                      editable: !_showEnhanced && !preprocessing.isProcessing,
                      onChanged: (quad) => setState(() {
                        _invalidatePreview();
                        _quads[index] = quad;
                      }),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Column(
                children: [
                  if (session.pagePaths.length > 1)
                    Text(context.l10n.pagesCount(session.pagePaths.length)),
                  if (_isDetectingEdges) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(),
                  ],
                  const SizedBox(height: 8),
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: false,
                        label: Text(context.l10n.original),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text(context.l10n.enhanced),
                        enabled: enhancedPath != null,
                      ),
                    ],
                    selected: {_showEnhanced},
                    onSelectionChanged: (value) =>
                        setState(() => _showEnhanced = value.single),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed:
                          preprocessing.isProcessing ||
                              _isDetectingEdges ||
                              _quads.any((quad) => !quad.isValid)
                          ? null
                          : _continue,
                      icon: preprocessing.isProcessing
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_fix_high),
                      label: Text(
                        preprocessing.isProcessing
                            ? context.l10n.processing
                            : hasCurrentAssets
                            ? context.l10n.continueLabel
                            : context.l10n.enhanced,
                      ),
                    ),
                  ),
                  if (preprocessing.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        preprocessing.errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuadEditor extends StatefulWidget {
  const _QuadEditor({
    required this.imagePath,
    required this.quad,
    required this.quarterTurns,
    required this.editable,
    required this.onChanged,
  });

  final String imagePath;
  final DocumentQuad quad;
  final int quarterTurns;
  final bool editable;
  final ValueChanged<DocumentQuad> onChanged;

  @override
  State<_QuadEditor> createState() => _QuadEditorState();
}

class _QuadEditorState extends State<_QuadEditor> {
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;
  Size? _imageSize;
  String? _resolvedPath;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant _QuadEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) _resolveImage();
  }

  void _resolveImage() {
    if (_resolvedPath == widget.imagePath) return;
    _removeListener();
    _resolvedPath = widget.imagePath;
    _imageSize = null;
    final stream = FileImage(
      File(widget.imagePath),
    ).resolve(createLocalImageConfiguration(context));
    late final ImageStreamListener listener;
    listener = ImageStreamListener((info, synchronousCall) {
      if (!mounted || _resolvedPath != widget.imagePath) return;
      setState(() {
        _imageSize = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );
      });
    });
    _imageStream = stream;
    _imageListener = listener;
    stream.addListener(listener);
  }

  void _removeListener() {
    final stream = _imageStream;
    final listener = _imageListener;
    if (stream != null && listener != null) stream.removeListener(listener);
    _imageStream = null;
    _imageListener = null;
  }

  @override
  void dispose() {
    _removeListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = Size(constraints.maxWidth, constraints.maxHeight);
        final imageSize = _imageSize;
        final turns = widget.quarterTurns % 4;
        final rotatedSize = imageSize == null
            ? available
            : turns.isOdd
            ? Size(imageSize.height, imageSize.width)
            : imageSize;
        final scale = math.min(
          available.width / rotatedSize.width,
          available.height / rotatedSize.height,
        );
        final fittedSize = Size(
          rotatedSize.width * scale,
          rotatedSize.height * scale,
        );
        final imageRect = Rect.fromLTWH(
          (available.width - fittedSize.width) / 2,
          (available.height - fittedSize.height) / 2,
          fittedSize.width,
          fittedSize.height,
        );
        final displayPoints = widget.quad.points
            .map((point) => _rotatePoint(point, turns))
            .map(
              (point) => Offset(
                imageRect.left + point.x * imageRect.width,
                imageRect.top + point.y * imageRect.height,
              ),
            )
            .toList();
        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              RotatedBox(
                quarterTurns: turns,
                child: Image.file(File(widget.imagePath), fit: BoxFit.contain),
              ),
              if (widget.editable && imageSize != null)
                CustomPaint(painter: _QuadPainter(displayPoints)),
              if (widget.editable && imageSize != null)
                for (var index = 0; index < widget.quad.points.length; index++)
                  Positioned(
                    left: displayPoints[index].dx - 18,
                    top: displayPoints[index].dy - 18,
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        final current = _rotatePoint(
                          widget.quad.points[index],
                          turns,
                        );
                        final moved = NormalizedPoint(
                          current.x + details.delta.dx / imageRect.width,
                          current.y + details.delta.dy / imageRect.height,
                        ).clamp();
                        widget.onChanged(
                          widget.quad.update(
                            index,
                            _unrotatePoint(moved, turns),
                          ),
                        );
                      },
                      child: const _DragHandle(),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  NormalizedPoint _rotatePoint(NormalizedPoint point, int turns) {
    return switch (turns) {
      1 => NormalizedPoint(1 - point.y, point.x),
      2 => NormalizedPoint(1 - point.x, 1 - point.y),
      3 => NormalizedPoint(point.y, 1 - point.x),
      _ => point,
    };
  }

  NormalizedPoint _unrotatePoint(NormalizedPoint point, int turns) {
    return switch (turns) {
      1 => NormalizedPoint(point.y, 1 - point.x),
      2 => NormalizedPoint(1 - point.x, 1 - point.y),
      3 => NormalizedPoint(1 - point.y, point.x),
      _ => point,
    };
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: const SizedBox.square(dimension: 36),
    );
  }
}

class _QuadPainter extends CustomPainter {
  const _QuadPainter(this.points);

  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.greenAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_QuadPainter oldDelegate) =>
      !listEquals(oldDelegate.points, points);
}
