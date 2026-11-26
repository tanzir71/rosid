import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rosid/core/extensions/l10n_extension.dart';
import 'package:rosid/core/theme/app_theme.dart';
import 'package:rosid/core/theme/rosid_icons.dart';
import 'package:rosid/core/theme/tokens.g.dart';
import 'package:rosid/core/widgets/rosid_controls.dart';
import 'package:rosid/core/widgets/rosid_navigation.dart';
import 'package:rosid/export/export_models.dart';
import 'package:rosid/features/export/export_controller.dart';
import 'package:rosid/features/paper/paper_repository.dart';

/// Cover a detail screen (`/paper/:id/export/cover`) matching
/// `design/screens/safety-cover-detail.png`.
class CoverDetailScreen extends ConsumerStatefulWidget {
  const CoverDetailScreen({
    required this.scanId,
    this.previewRegions,
    super.key,
  });

  final String scanId;

  @visibleForTesting
  final List<CoverRegion>? previewRegions;

  @override
  ConsumerState<CoverDetailScreen> createState() => _CoverDetailScreenState();
}

class _CoverDetailScreenState extends ConsumerState<CoverDetailScreen> {
  CoverStyle _tool = CoverStyle.blackBar;
  late List<CoverRegion> _regions;
  Offset? _dragStart;
  Offset? _dragCurrent;

  @override
  void initState() {
    super.initState();
    _regions = List<CoverRegion>.from(
      widget.previewRegions ??
          ref.read(paperExportControllerProvider).config.coverRegions,
    );
  }

  void _commitDrag(Size canvas) {
    if (_dragStart == null || _dragCurrent == null) return;
    final x1 = (math.min(_dragStart!.dx, _dragCurrent!.dx) / canvas.width)
        .clamp(0.0, 1.0);
    final y1 = (math.min(_dragStart!.dy, _dragCurrent!.dy) / canvas.height)
        .clamp(0.0, 1.0);
    final x2 = (math.max(_dragStart!.dx, _dragCurrent!.dx) / canvas.width)
        .clamp(0.0, 1.0);
    final y2 = (math.max(_dragStart!.dy, _dragCurrent!.dy) / canvas.height)
        .clamp(0.0, 1.0);
    if ((x2 - x1) > 0.03 && (y2 - y1) > 0.02) {
      setState(() {
        _regions.add(
          CoverRegion(
            pageIndex: 0,
            left: x1,
            top: y1,
            right: x2,
            bottom: y2,
            style: _tool,
          ),
        );
      });
    }
    setState(() {
      _dragStart = null;
      _dragCurrent = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    final paperAsync = ref.watch(paperViewProvider(widget.scanId));

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: RosidTopBar(
        title: l10n.coverDetailTitle,
        leading: IconButton(
          key: const ValueKey('cover-close'),
          icon: RosidIcon(RosidIcons.close, size: 22, color: c.inkPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: c.bgSunken,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: AspectRatio(
                    aspectRatio: 1.32,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final size = constraints.biggest;
                        final pagePath = paperAsync.whenOrNull(
                          data: (p) => p == null
                              ? null
                              : (p.pages.isNotEmpty
                                    ? (p.pages.first.processedPath ??
                                          p.pages.first.imagePath)
                                    : p.scan.imagePath),
                        );
                        final hasImage =
                            pagePath != null && File(pagePath).existsSync();

                        final allBoxes = <CoverRegion>[
                          ..._regions,
                          if (_dragStart != null && _dragCurrent != null)
                            CoverRegion(
                              pageIndex: 0,
                              left:
                                  (math.min(_dragStart!.dx, _dragCurrent!.dx) /
                                          size.width)
                                      .clamp(0.0, 1.0),
                              top:
                                  (math.min(_dragStart!.dy, _dragCurrent!.dy) /
                                          size.height)
                                      .clamp(0.0, 1.0),
                              right:
                                  (math.max(_dragStart!.dx, _dragCurrent!.dx) /
                                          size.width)
                                      .clamp(0.0, 1.0),
                              bottom:
                                  (math.max(_dragStart!.dy, _dragCurrent!.dy) /
                                          size.height)
                                      .clamp(0.0, 1.0),
                              style: _tool,
                            ),
                        ];

                        return GestureDetector(
                          key: const ValueKey('cover-canvas'),
                          onPanStart: (d) => setState(() {
                            _dragStart = d.localPosition;
                            _dragCurrent = d.localPosition;
                          }),
                          onPanUpdate: (d) =>
                              setState(() => _dragCurrent = d.localPosition),
                          onPanEnd: (_) => _commitDrag(size),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFD2D5CA),
                                width: 3,
                              ),
                              boxShadow: RosidShadowTokens.elevPaper,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (hasImage)
                                  Image.file(File(pagePath), fit: BoxFit.cover)
                                else
                                  const _CoverCardPlaceholder(),
                                for (final box in allBoxes)
                                  _CoverBoxOverlay(box: box, canvasSize: size),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  l10n.coverDetailHint,
                  style: RosidTextTokens.uiBody.copyWith(color: c.inkPrimary),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    RosidChip(
                      key: const ValueKey('cover-tool-black'),
                      label: l10n.coverToolBlackBar,
                      selected: _tool == CoverStyle.blackBar,
                      onTap: () => setState(() => _tool = CoverStyle.blackBar),
                    ),
                    RosidChip(
                      key: const ValueKey('cover-tool-blur'),
                      label: l10n.coverToolBlur,
                      selected: _tool == CoverStyle.blur,
                      onTap: () => setState(() => _tool = CoverStyle.blur),
                    ),
                    RosidChip(
                      key: const ValueKey('cover-tool-undo'),
                      label: l10n.undo,
                      icon: RosidIcons.rotate,
                      selected: false,
                      onTap: _regions.isEmpty
                          ? null
                          : () => setState(() => _regions.removeLast()),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: RosidIcon(
                        RosidIcons.info,
                        size: 16,
                        color: c.inkSecondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.coverDetailSafeNote,
                        style: RosidTextTokens.uiCaption.copyWith(
                          color: c.inkSecondary,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: SafeArea(
              top: false,
              child: RosidButton(
                key: const ValueKey('cover-done'),
                label: l10n.done,
                expand: true,
                onPressed: () {
                  ref
                      .read(paperExportControllerProvider.notifier)
                      .setCoverRegions(_regions);
                  Navigator.of(context).maybePop();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverBoxOverlay extends StatelessWidget {
  const _CoverBoxOverlay({required this.box, required this.canvasSize});

  final CoverRegion box;
  final Size canvasSize;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final left = box.left * canvasSize.width;
    final top = box.top * canvasSize.height;
    final width = (box.width * canvasSize.width).clamp(16.0, canvasSize.width);
    final height = (box.height * canvasSize.height).clamp(
      14.0,
      canvasSize.height,
    );

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: box.style == CoverStyle.blackBar
                    ? const Color(0xFF21222E)
                    : const Color(0xFF9EA2AF).withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          for (final (dx, dy) in const [
            (-5.0, -5.0),
            (null, -5.0),
            (-5.0, null),
            (null, null),
          ])
            Positioned(
              left: dx,
              right: dx == null ? -5.0 : null,
              top: dy,
              bottom: dy == null ? -5.0 : null,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: c.accentBase,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CoverCardPlaceholder extends StatelessWidget {
  const _CoverCardPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 70,
                height: 88,
                decoration: BoxDecoration(
                  color: const Color(0xFFD2D5CA),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Container(
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF282A38),
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      height: 10,
                      width: 104,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD2D5CA),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      height: 10,
                      width: 132,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD2D5CA),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
