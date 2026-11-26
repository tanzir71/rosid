import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rosid/core/extensions/l10n_extension.dart';
import 'package:rosid/core/theme/rosid_icons.dart';
import 'package:rosid/core/theme/tokens.g.dart';
import 'package:rosid/core/utils/bangla_digits.dart';
import 'package:rosid/core/widgets/rosid_paper_thumbnail.dart';
import 'package:rosid/features/capture/scan_controller.dart';
import 'package:rosid/ocr/preprocess/document_quad.dart';
import 'package:rosid/ocr/preprocess/image_cleaner.dart';

/// Adjust page screen (`design/screens/scan-adjust-page.png`).
/// Supports corner & edge handles, magnifier loupe while dragging, filters
/// (Auto, Original, Grey, Black and white), rotate, delete, drag-to-reorder
/// thumbnails, add page, and retake.
class AdjustPageScreen extends ConsumerStatefulWidget {
  const AdjustPageScreen({
    super.key,
    this.previewPageWidget,
    this.previewDraggingCorner,
  });

  /// Optional preview content for deterministic golden tests.
  @visibleForTesting
  final Widget? previewPageWidget;

  /// Optional active corner index (0..3) to render the magnifier loupe in
  /// deterministic golden tests.
  @visibleForTesting
  final int? previewDraggingCorner;

  @override
  ConsumerState<AdjustPageScreen> createState() => _AdjustPageScreenState();
}

enum _HandleKind { corner, edge }

class _ActiveHandle {
  const _ActiveHandle(this.kind, this.index);

  final _HandleKind kind;
  final int index; // 0..3
}

class _AdjustPageScreenState extends ConsumerState<AdjustPageScreen> {
  _ActiveHandle? _activeHandle;
  Offset? _loupeNormalizedPoint;

  @override
  void initState() {
    super.initState();
    final previewCorner = widget.previewDraggingCorner;
    if (previewCorner != null) {
      _activeHandle = _ActiveHandle(_HandleKind.corner, previewCorner);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final scanState = ref.watch(v2ScanProvider);
    final page = scanState.currentPage;

    if (page == null) {
      return Scaffold(
        backgroundColor: RosidColorTokens.bgCanvasDark,
        appBar: AppBar(
          backgroundColor: RosidColorTokens.bgCanvasDark,
          foregroundColor: RosidColorTokens.inkPrimaryDark,
          leading: IconButton(
            icon: const RosidIcon(
              RosidIcons.back,
              color: RosidColorTokens.inkPrimaryDark,
            ),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Text(
            l10n.noPapersYet,
            style: RosidTextTokens.uiBody.copyWith(
              color: RosidColorTokens.inkSecondaryDark,
            ),
          ),
        ),
      );
    }

    final currentNumber = scanState.selectedIndex + 1;
    final totalPages = scanState.pages.length;

    return Scaffold(
      backgroundColor: RosidColorTokens.cameraSceneDark,
      appBar: AppBar(
        backgroundColor: RosidColorTokens.bgCanvasDark,
        foregroundColor: RosidColorTokens.inkPrimaryDark,
        elevation: 0,
        leading: IconButton(
          key: const ValueKey('adjust-back'),
          tooltip: l10n.cancel,
          onPressed: () => context.pop(),
          icon: const RosidIcon(
            RosidIcons.back,
            size: 22,
            color: RosidColorTokens.inkPrimaryDark,
          ),
        ),
        title: Text(
          localizeDigits(l10n.pageOfTotal(currentNumber, totalPages), locale),
          style: RosidTextTokens.uiTitle.copyWith(
            color: RosidColorTokens.inkPrimaryDark,
          ),
        ),
        actions: [
          IconButton(
            key: const ValueKey('adjust-rotate'),
            tooltip: l10n.rotate,
            onPressed: () =>
                ref.read(v2ScanProvider.notifier).rotateCurrentPage(),
            icon: const RosidIcon(
              RosidIcons.rotate,
              size: 22,
              color: RosidColorTokens.inkPrimaryDark,
            ),
          ),
          IconButton(
            key: const ValueKey('adjust-delete'),
            tooltip: l10n.delete,
            onPressed: () async {
              await ref.read(v2ScanProvider.notifier).deleteCurrentPage();
              if (context.mounted && ref.read(v2ScanProvider).pages.isEmpty) {
                context.pop();
              }
            },
            icon: const RosidIcon(
              RosidIcons.trash,
              size: 22,
              color: RosidColorTokens.inkPrimaryDark,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final canvasSize = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  final pageVisual = _buildPageImage(page);
                  final quad = page.quad;
                  final activePoint = _loupePointFor(quad);

                  return GestureDetector(
                    key: const ValueKey('adjust-quad-canvas'),
                    onPanStart: (d) =>
                        _onPanStart(d.localPosition, canvasSize, quad),
                    onPanUpdate: (d) =>
                        _onPanUpdate(d.localPosition, canvasSize, quad),
                    onPanEnd: (_) => setState(() {
                      _activeHandle = null;
                      _loupeNormalizedPoint = null;
                    }),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Positioned.fill(child: pageVisual),
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _AdjustQuadPainter(
                              quad: quad,
                              activeHandle: _activeHandle,
                            ),
                          ),
                        ),
                        if (activePoint != null)
                          _PositionedMagnifierLoupe(
                            normalizedPoint: activePoint,
                            canvasSize: canvasSize,
                            content: pageVisual,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          _AdjustBottomPanel(
            scanState: scanState,
            currentPage: page,
            locale: locale,
            onFilterSelected: (f) =>
                ref.read(v2ScanProvider.notifier).setCurrentFilter(f),
            onPageSelected: (i) =>
                ref.read(v2ScanProvider.notifier).selectPage(i),
            onReorder: (oldIndex, newIndex) => ref
                .read(v2ScanProvider.notifier)
                .reorderPages(
                  oldIndex,
                  newIndex > oldIndex ? newIndex + 1 : newIndex,
                ),
            onAddPage: () => context.pop(),
            onRetake: () async {
              await ref.read(v2ScanProvider.notifier).deleteCurrentPage();
              if (context.mounted) context.pop();
            },
            onReadText: () => context.push('/scan/reading'),
          ),
        ],
      ),
    );
  }

  Widget _buildPageImage(CapturedPageDraft page) {
    final child =
        widget.previewPageWidget ??
        Image.file(
          File(page.originalPath),
          fit: BoxFit.contain,
          gaplessPlayback: true,
        );
    final filtered = switch (page.filter) {
      PageFilterMode.grey => ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: child,
      ),
      PageFilterMode.blackAndWhite => ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.38,
          1.25,
          0.13,
          0,
          -90,
          0.38,
          1.25,
          0.13,
          0,
          -90,
          0.38,
          1.25,
          0.13,
          0,
          -90,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: child,
      ),
      PageFilterMode.auto || PageFilterMode.original => child,
    };
    return RotatedBox(quarterTurns: page.rotationQuarterTurns, child: filtered);
  }

  Offset? _loupePointFor(DocumentQuad quad) {
    if (_loupeNormalizedPoint != null) return _loupeNormalizedPoint;
    final previewIdx = widget.previewDraggingCorner;
    if (previewIdx != null && previewIdx >= 0 && previewIdx < 4) {
      final p = quad.points[previewIdx];
      return Offset(p.x, p.y);
    }
    return null;
  }

  void _onPanStart(Offset local, Size size, DocumentQuad quad) {
    const hitRadius = 38.0;
    final pts = quad.points
        .map((p) => Offset(p.x * size.width, p.y * size.height))
        .toList(growable: false);

    // Prefer corners first.
    var bestDist = hitRadius;
    _ActiveHandle? best;
    for (var i = 0; i < 4; i++) {
      final d = (pts[i] - local).distance;
      if (d < bestDist) {
        bestDist = d;
        best = _ActiveHandle(_HandleKind.corner, i);
      }
    }

    // Check edge midpoints next.
    if (best == null) {
      for (var i = 0; i < 4; i++) {
        final mid = Offset(
          (pts[i].dx + pts[(i + 1) % 4].dx) / 2,
          (pts[i].dy + pts[(i + 1) % 4].dy) / 2,
        );
        final d = (mid - local).distance;
        if (d < bestDist) {
          bestDist = d;
          best = _ActiveHandle(_HandleKind.edge, i);
        }
      }
    }

    if (best != null) {
      setState(() {
        _activeHandle = best;
        _loupeNormalizedPoint = Offset(
          (local.dx / size.width).clamp(0.0, 1.0),
          (local.dy / size.height).clamp(0.0, 1.0),
        );
      });
    }
  }

  void _onPanUpdate(Offset local, Size size, DocumentQuad quad) {
    final handle = _activeHandle;
    if (handle == null) return;
    final nx = (local.dx / size.width).clamp(0.02, 0.98);
    final ny = (local.dy / size.height).clamp(0.02, 0.98);
    final pts = List<NormalizedPoint>.from(quad.points);

    if (handle.kind == _HandleKind.corner) {
      pts[handle.index] = NormalizedPoint(nx, ny);
    } else {
      final i = handle.index;
      final j = (i + 1) % 4;
      final midX = (pts[i].x + pts[j].x) / 2;
      final midY = (pts[i].y + pts[j].y) / 2;
      final dx = nx - midX;
      final dy = ny - midY;
      pts[i] = NormalizedPoint(
        (pts[i].x + dx).clamp(0.02, 0.98),
        (pts[i].y + dy).clamp(0.02, 0.98),
      );
      pts[j] = NormalizedPoint(
        (pts[j].x + dx).clamp(0.02, 0.98),
        (pts[j].y + dy).clamp(0.02, 0.98),
      );
    }

    final candidate = DocumentQuad(
      topLeft: pts[0],
      topRight: pts[1],
      bottomRight: pts[2],
      bottomLeft: pts[3],
    );
    setState(() => _loupeNormalizedPoint = Offset(nx, ny));
    if (candidate.isValid) {
      ref.read(v2ScanProvider.notifier).updateCurrentQuad(candidate);
    }
  }
}

/// Circular magnifier loupe shown above/beside the active corner handle while
/// dragging (`design/screens/scan-adjust-page.png`).
class MagnifierLoupe extends StatelessWidget {
  const MagnifierLoupe({
    required this.normalizedPoint,
    required this.canvasSize,
    required this.content,
    this.diameter = 108,
    this.zoom = 2.2,
    super.key,
  });

  final Offset normalizedPoint;
  final Size canvasSize;
  final Widget content;
  final double diameter;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    final px = normalizedPoint.dx * canvasSize.width;
    final py = normalizedPoint.dy * canvasSize.height;
    final radius = diameter / 2;

    return Container(
      key: const ValueKey('adjust-magnifier'),
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: RosidColorTokens.cameraSceneDark,
        border: Border.all(color: RosidColorTokens.accentBaseDark, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: canvasSize.width,
              maxWidth: canvasSize.width,
              minHeight: canvasSize.height,
              maxHeight: canvasSize.height,
              child: Transform(
                transform: Matrix4.identity()
                  ..translateByDouble(
                    radius - px * zoom,
                    radius - py * zoom,
                    0,
                    1,
                  )
                  ..scaleByDouble(zoom, zoom, 1, 1),
                child: SizedBox(
                  width: canvasSize.width,
                  height: canvasSize.height,
                  child: content,
                ),
              ),
            ),
            IgnorePointer(child: CustomPaint(painter: _CrosshairPainter())),
          ],
        ),
      ),
    );
  }
}

class _PositionedMagnifierLoupe extends StatelessWidget {
  const _PositionedMagnifierLoupe({
    required this.normalizedPoint,
    required this.canvasSize,
    required this.content,
  });

  final Offset normalizedPoint;
  final Size canvasSize;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    const diameter = 108.0;
    final px = normalizedPoint.dx * canvasSize.width;
    final py = normalizedPoint.dy * canvasSize.height;
    final left = (px + 18 + diameter <= canvasSize.width)
        ? px + 18
        : math.max(8.0, px - diameter - 18);
    final top = (py + 18 + diameter <= canvasSize.height)
        ? py + 18
        : math.max(8.0, py - diameter - 18);

    return Positioned(
      left: left,
      top: top,
      child: MagnifierLoupe(
        normalizedPoint: normalizedPoint,
        canvasSize: canvasSize,
        content: content,
        diameter: diameter,
      ),
    );
  }
}

class _CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 1.2;
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), p);
    canvas.drawLine(Offset(0, cy), Offset(size.width, cy), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AdjustQuadPainter extends CustomPainter {
  const _AdjustQuadPainter({required this.quad, required this.activeHandle});

  final DocumentQuad quad;
  final _ActiveHandle? activeHandle;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = quad.points
        .map((p) => Offset(p.x * size.width, p.y * size.height))
        .toList(growable: false);

    final path = Path()
      ..moveTo(pts[0].dx, pts[0].dy)
      ..lineTo(pts[1].dx, pts[1].dy)
      ..lineTo(pts[2].dx, pts[2].dy)
      ..lineTo(pts[3].dx, pts[3].dy)
      ..close();

    final stroke = Paint()
      ..color = RosidColorTokens.accentBaseDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawPath(path, stroke);

    // Draw 4 edge midpoint pills.
    final pillPaint = Paint()
      ..color = RosidColorTokens.accentBaseDark
      ..style = PaintingStyle.fill;
    for (var i = 0; i < 4; i++) {
      final a = pts[i];
      final b = pts[(i + 1) % 4];
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      final angle = math.atan2(b.dy - a.dy, b.dx - a.dx);
      canvas.save();
      canvas.translate(mid.dx, mid.dy);
      canvas.rotate(angle);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-12, -3.5, 24, 7),
          const Radius.circular(4),
        ),
        pillPaint,
      );
      canvas.restore();
    }

    // Draw 4 corner circles.
    for (var i = 0; i < 4; i++) {
      final isSelected =
          activeHandle?.kind == _HandleKind.corner && activeHandle?.index == i;
      final fill = Paint()
        ..color = isSelected
            ? RosidColorTokens.accentBaseDark
            : RosidColorTokens.bgCanvasDark
        ..style = PaintingStyle.fill;
      final border = Paint()
        ..color = RosidColorTokens.accentBaseDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      canvas.drawCircle(pts[i], 9.5, fill);
      canvas.drawCircle(pts[i], 9.5, border);
    }
  }

  @override
  bool shouldRepaint(covariant _AdjustQuadPainter oldDelegate) =>
      oldDelegate.quad != quad || oldDelegate.activeHandle != activeHandle;
}

class _AdjustBottomPanel extends StatelessWidget {
  const _AdjustBottomPanel({
    required this.scanState,
    required this.currentPage,
    required this.locale,
    required this.onFilterSelected,
    required this.onPageSelected,
    required this.onReorder,
    required this.onAddPage,
    required this.onRetake,
    required this.onReadText,
  });

  final V2ScanState scanState;
  final CapturedPageDraft currentPage;
  final Locale locale;
  final ValueChanged<PageFilterMode> onFilterSelected;
  final ValueChanged<int> onPageSelected;
  final void Function(int oldIndex, int newIndex) onReorder;
  final VoidCallback onAddPage;
  final VoidCallback onRetake;
  final VoidCallback onReadText;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filters = <(PageFilterMode, String, Color)>[
      (PageFilterMode.auto, l10n.enhanced, const Color(0xFFF3F1E8)),
      (PageFilterMode.original, l10n.original, const Color(0xFFDAD7CC)),
      (PageFilterMode.grey, l10n.grey, const Color(0xFF474961)),
      (
        PageFilterMode.blackAndWhite,
        l10n.blackAndWhite,
        const Color(0xFFFFFFFF),
      ),
    ];

    return Container(
      color: RosidColorTokens.bgCanvasDark,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final (mode, label, bg) in filters)
                  _FilterPreviewTile(
                    key: ValueKey('adjust-filter-${mode.id}'),
                    label: label,
                    selected: currentPage.filter == mode,
                    frameColor: bg,
                    onTap: () => onFilterSelected(mode),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  Expanded(
                    child: ReorderableListView.builder(
                      scrollDirection: Axis.horizontal,
                      buildDefaultDragHandles: false,
                      onReorderItem: onReorder,
                      proxyDecorator: (child, index, animation) =>
                          Material(color: Colors.transparent, child: child),
                      itemCount: scanState.pages.length,
                      itemBuilder: (context, i) {
                        final selected = i == scanState.selectedIndex;
                        return ReorderableDelayedDragStartListener(
                          key: ValueKey(
                            'page-thumb-${scanState.pages[i].pageId}',
                          ),
                          index: i,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () => onPageSelected(i),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 38,
                                height: 48,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: RosidColorTokens.paperSheetDark,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: selected
                                        ? RosidColorTokens.accentBaseDark
                                        : Colors.transparent,
                                    width: 2.2,
                                  ),
                                ),
                                child: Text(
                                  localizeDigits('${i + 1}', locale),
                                  style: RosidTextTokens.uiLabel.copyWith(
                                    color: RosidColorTokens.paperInkDark,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  InkWell(
                    key: const ValueKey('adjust-add-page'),
                    onTap: onAddPage,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 38,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: RosidColorTokens.lineStrongDark,
                        ),
                      ),
                      child: const Center(
                        child: RosidIcon(
                          RosidIcons.plus,
                          size: 18,
                          color: RosidColorTokens.inkSecondaryDark,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.holdAndDragReorder,
                    style: RosidTextTokens.uiMicro.copyWith(
                      color: RosidColorTokens.inkTertiaryDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton(
                  key: const ValueKey('adjust-retake'),
                  onPressed: onRetake,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: RosidColorTokens.inkPrimaryDark,
                    side: const BorderSide(
                      color: RosidColorTokens.lineStrongDark,
                    ),
                    minimumSize: const Size(92, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        RosidSizeTokens.radiusControl,
                      ),
                    ),
                  ),
                  child: Text(
                    l10n.retake,
                    style: RosidTextTokens.uiBodyStrong.copyWith(
                      color: RosidColorTokens.inkPrimaryDark,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('adjust-read-text'),
                    onPressed: onReadText,
                    style: FilledButton.styleFrom(
                      backgroundColor: RosidColorTokens.accentBaseDark,
                      foregroundColor: RosidColorTokens.inkOnAccentDark,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          RosidSizeTokens.radiusControl,
                        ),
                      ),
                    ),
                    child: Text(
                      l10n.readText,
                      style: RosidTextTokens.uiBodyStrong.copyWith(
                        color: RosidColorTokens.inkOnAccentDark,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterPreviewTile extends StatelessWidget {
  const _FilterPreviewTile({
    required this.label,
    required this.selected,
    required this.frameColor,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final Color frameColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 66,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: frameColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? RosidColorTokens.accentBaseDark
                    : Colors.transparent,
                width: 2.5,
              ),
            ),
            child: const Center(
              child: RosidPaperThumbnail(
                kind: RosidPaperKind.letter,
                width: 34,
                height: 46,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: RosidTextTokens.uiMicro.copyWith(
              color: selected
                  ? RosidColorTokens.inkPrimaryDark
                  : RosidColorTokens.inkSecondaryDark,
            ),
          ),
        ],
      ),
    );
  }
}
