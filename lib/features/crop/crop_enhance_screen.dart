import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rosid/core/extensions/l10n_extension.dart';
import 'package:rosid/core/profile/app_profile.dart';
import 'package:rosid/features/capture/capture_session.dart';
import 'package:rosid/features/crop/preprocess_controller.dart';
import 'package:rosid/ocr/preprocess/document_quad.dart';

class CropEnhanceScreen extends ConsumerStatefulWidget {
  const CropEnhanceScreen({super.key});

  @override
  ConsumerState<CropEnhanceScreen> createState() => _CropEnhanceScreenState();
}

class _CropEnhanceScreenState extends ConsumerState<CropEnhanceScreen> {
  late List<DocumentQuad> _quads;
  var _pageIndex = 0;
  var _quarterTurns = 0;
  var _showEnhanced = false;

  @override
  void initState() {
    super.initState();
    final count = ref.read(captureSessionProvider).pagePaths.length;
    _quads = List.filled(count, const DocumentQuad.inset());
  }

  Future<void> _continue() async {
    final session = ref.read(captureSessionProvider);
    final processed = await ref
        .read(preprocessProvider.notifier)
        .process(
          session: session,
          quads: _quads,
          rotationQuarterTurns: _quarterTurns,
        );
    if (!mounted || !processed) return;
    final route = session.mode == ScanMode.receipt
        ? '/review/receipt'
        : '/review/document';
    await context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(captureSessionProvider);
    final preprocessing = ref.watch(preprocessProvider);
    if (session.pagePaths.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.cropEnhance)),
        body: Center(child: Text(context.l10n.noDocuments)),
      );
    }
    final enhancedPath = preprocessing.assets.length > _pageIndex
        ? preprocessing.assets[_pageIndex].colorPath
        : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.cropEnhance),
        actions: [
          IconButton(
            onPressed: () =>
                setState(() => _quarterTurns = (_quarterTurns + 1) % 4),
            tooltip: context.l10n.rotate,
            icon: const Icon(Icons.rotate_right),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              itemCount: session.pagePaths.length,
              onPageChanged: (index) => setState(() => _pageIndex = index),
              itemBuilder: (context, index) {
                final itemEnhanced = preprocessing.assets.length > index
                    ? preprocessing.assets[index].colorPath
                    : null;
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: _QuadEditor(
                    imagePath: _showEnhanced && itemEnhanced != null
                        ? itemEnhanced
                        : session.pagePaths[index],
                    quad: _quads[index],
                    quarterTurns: _quarterTurns,
                    editable: !_showEnhanced,
                    onChanged: (quad) => setState(() => _quads[index] = quad),
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
                          : context.l10n.continueLabel,
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
    );
  }
}

class _QuadEditor extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              RotatedBox(
                quarterTurns: quarterTurns,
                child: Image.file(File(imagePath), fit: BoxFit.contain),
              ),
              CustomPaint(painter: _QuadPainter(quad)),
              if (editable)
                for (var index = 0; index < quad.points.length; index++)
                  Positioned(
                    left: quad.points[index].x * size.width - 18,
                    top: quad.points[index].y * size.height - 18,
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        final current = quad.points[index];
                        onChanged(
                          quad.update(
                            index,
                            NormalizedPoint(
                              current.x + details.delta.dx / size.width,
                              current.y + details.delta.dy / size.height,
                            ),
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
  const _QuadPainter(this.quad);

  final DocumentQuad quad;

  @override
  void paint(Canvas canvas, Size size) {
    final points = quad.points
        .map((point) => Offset(point.x * size.width, point.y * size.height))
        .toList();
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
  bool shouldRepaint(_QuadPainter oldDelegate) => oldDelegate.quad != quad;
}
