import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rosid/core/extensions/l10n_extension.dart';
import 'package:rosid/core/theme/app_theme.dart';
import 'package:rosid/core/theme/rosid_icons.dart';
import 'package:rosid/core/theme/tokens.g.dart';
import 'package:rosid/core/utils/bangla_digits.dart';
import 'package:rosid/core/widgets/rosid_controls.dart';
import 'package:rosid/core/widgets/rosid_navigation.dart';
import 'package:rosid/data/database/database_provider.dart';
import 'package:rosid/data/repositories/record_repository.dart';
import 'package:rosid/features/capture/scan_controller.dart';
import 'package:rosid/ocr/pipeline/reading_interfaces.dart';
import 'package:rosid/ocr/pipeline/rosid_reading_pipeline.dart';

enum ReadingStepState { pending, active, done }

/// Snapshot of progress displayed on [ReadingProgressScreen].
class ReadingProgressSnapshot {
  const ReadingProgressSnapshot({
    this.cleanStep = ReadingStepState.active,
    this.scriptStep = ReadingStepState.pending,
    this.readStep = ReadingStepState.pending,
    this.detailsStep = ReadingStepState.pending,
    this.currentLine = 0,
    this.totalLines = 0,
    this.hasHandwriting = false,
    this.scanBarFraction = 0.45,
  });

  final ReadingStepState cleanStep;
  final ReadingStepState scriptStep;
  final ReadingStepState readStep;
  final ReadingStepState detailsStep;
  final int currentLine;
  final int totalLines;
  final bool hasHandwriting;
  final double scanBarFraction;
}

/// Reading progress screen (`design/screens/scan-reading.png`).
/// Drives M2 cleaning + M3 ONNX/Tesseract reading pipeline with live per-line
/// progress updates and clean cancellation via [ReadingCancelToken].
class ReadingProgressScreen extends ConsumerStatefulWidget {
  const ReadingProgressScreen({
    super.key,
    this.previewSnapshot,
    this.previewPage,
    this.autoStart = true,
    this.runOcr = true,
  });

  @visibleForTesting
  final ReadingProgressSnapshot? previewSnapshot;

  @visibleForTesting
  final Widget? previewPage;

  @visibleForTesting
  final bool autoStart;

  @visibleForTesting
  final bool runOcr;

  @override
  ConsumerState<ReadingProgressScreen> createState() =>
      _ReadingProgressScreenState();
}

class _ReadingProgressScreenState extends ConsumerState<ReadingProgressScreen> {
  ReadingProgressSnapshot _snapshot = const ReadingProgressSnapshot();
  final ReadingCancelToken _cancelToken = ReadingCancelToken();

  @override
  void initState() {
    super.initState();
    if (widget.previewSnapshot != null) {
      _snapshot = widget.previewSnapshot!;
      return;
    }
    if (widget.autoStart) {
      Future.microtask(_runReadingPipeline);
    }
  }

  @override
  void dispose() {
    _cancelToken.cancel();
    super.dispose();
  }

  Future<void> _runReadingPipeline() async {
    if (!mounted || _cancelToken.isCancelled) return;
    try {
      // Step 1: Clean and straighten every captured page.
      final scanId = await ref
          .read(v2ScanProvider.notifier)
          .cleanAllPages(
            onProgress: (completed, total) {
              if (!mounted || _cancelToken.isCancelled) return;
              setState(() {
                _snapshot = ReadingProgressSnapshot(
                  cleanStep: completed >= total
                      ? ReadingStepState.done
                      : ReadingStepState.active,
                  scriptStep: completed >= total
                      ? ReadingStepState.active
                      : ReadingStepState.pending,
                  scanBarFraction: total == 0
                      ? 0.25
                      : (completed / total) * 0.30,
                );
              });
            },
          );
      if (!mounted || _cancelToken.isCancelled) return;
      if (scanId == null) {
        context.go('/');
        return;
      }

      // Steps 2–4: Run ONNX line detector + script router + Latin/Bangla recognisers.
      if (widget.runOcr) {
        final pages = ref.read(v2ScanProvider).pages;
        final pipeline = ref.read(readingPipelineProvider);
        final pageResults = <ReadingPageResult>[];
        var anyHandwriting = false;

        for (var i = 0; i < pages.length; i++) {
          if (!mounted || _cancelToken.isCancelled) return;
          final page = pages[i];
          final greyPath = page.cleanedGreyPath ?? page.originalPath;
          final greyBytes = await File(greyPath).readAsBytes();
          if (!mounted || _cancelToken.isCancelled) return;

          final pageRes = await pipeline.readPage(
            greyImageBytes: greyBytes,
            pageIndex: i,
            cancelToken: _cancelToken,
            onProgress: (event) {
              if (!mounted || _cancelToken.isCancelled) return;
              anyHandwriting = anyHandwriting || event.hasHandwriting;
              setState(() {
                _snapshot = _snapshotForEvent(event, anyHandwriting);
              });
            },
          );
          if (!mounted || _cancelToken.isCancelled) return;
          anyHandwriting = anyHandwriting || pageRes.hasHandwriting;
          pageResults.add(pageRes);
        }

        if (!mounted || _cancelToken.isCancelled) return;
        final fallbackTitle = context.l10n.document;
        final db = ref.read(databaseProvider);
        await persistReadingResults(
          db: db,
          scanId: scanId,
          pageResults: pageResults,
        );

        final combinedText = pageResults
            .map((r) => r.fullText)
            .where((t) => t.isNotEmpty)
            .join('\n\n');
        final firstLine = combinedText
            .split('\n')
            .map((l) => l.trim())
            .firstWhere((l) => l.isNotEmpty, orElse: () => '');
        await ref
            .read(recordRepositoryProvider)
            .saveDocument(
              scanId: scanId,
              title: firstLine.isEmpty
                  ? fallbackTitle
                  : (firstLine.length > 60
                        ? firstLine.substring(0, 60)
                        : firstLine),
              body: combinedText,
              tags: const [],
            );
      }

      if (!mounted || _cancelToken.isCancelled) return;
      setState(() {
        _snapshot = ReadingProgressSnapshot(
          cleanStep: ReadingStepState.done,
          scriptStep: ReadingStepState.done,
          readStep: ReadingStepState.done,
          detailsStep: ReadingStepState.done,
          currentLine: _snapshot.totalLines,
          totalLines: _snapshot.totalLines,
          hasHandwriting: _snapshot.hasHandwriting,
          scanBarFraction: 0.92,
        );
      });
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!mounted || _cancelToken.isCancelled) return;
      context.go('/paper/$scanId');
    } on Object {
      if (!mounted || _cancelToken.isCancelled) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.processingFailed)));
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
    }
  }

  ReadingProgressSnapshot _snapshotForEvent(
    ReadingProgressEvent event,
    bool hasHandwriting,
  ) {
    return switch (event.stage) {
      ReadingStage.cleaning => ReadingProgressSnapshot(
        cleanStep: ReadingStepState.active,
        hasHandwriting: hasHandwriting,
        scanBarFraction: 0.20,
      ),
      ReadingStage.detectingLines => ReadingProgressSnapshot(
        cleanStep: ReadingStepState.done,
        scriptStep: ReadingStepState.active,
        hasHandwriting: hasHandwriting,
        scanBarFraction: 0.35,
      ),
      ReadingStage.readingLines => ReadingProgressSnapshot(
        cleanStep: ReadingStepState.done,
        scriptStep: ReadingStepState.done,
        readStep: ReadingStepState.active,
        currentLine: event.currentLine,
        totalLines: event.totalLines,
        hasHandwriting: hasHandwriting,
        scanBarFraction: event.totalLines <= 0
            ? 0.50
            : 0.35 + (event.currentLine / event.totalLines) * 0.50,
      ),
      ReadingStage.findingDetails => ReadingProgressSnapshot(
        cleanStep: ReadingStepState.done,
        scriptStep: ReadingStepState.done,
        readStep: ReadingStepState.done,
        detailsStep: ReadingStepState.active,
        currentLine: event.totalLines,
        totalLines: event.totalLines,
        hasHandwriting: hasHandwriting,
        scanBarFraction: 0.88,
      ),
      ReadingStage.done => ReadingProgressSnapshot(
        cleanStep: ReadingStepState.done,
        scriptStep: ReadingStepState.done,
        readStep: ReadingStepState.done,
        detailsStep: ReadingStepState.done,
        currentLine: event.totalLines,
        totalLines: event.totalLines,
        hasHandwriting: hasHandwriting,
        scanBarFraction: 0.94,
      ),
    };
  }

  void _cancel() {
    _cancelToken.cancel();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final scanState = ref.watch(v2ScanProvider);
    final page = scanState.currentPage;

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: RosidTopBar(
        title: l10n.readingOnPhone,
        leading: IconButton(
          key: const ValueKey('reading-close'),
          tooltip: l10n.cancel,
          onPressed: _cancel,
          icon: RosidIcon(RosidIcons.close, size: 22, color: c.inkPrimary),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  children: [
                    _ScanPreviewCard(
                      page: page,
                      previewWidget: widget.previewPage,
                      scanBarFraction: _snapshot.scanBarFraction,
                    ),
                    const SizedBox(height: 24),
                    _StepRow(
                      state: _snapshot.cleanStep,
                      label: l10n.stepPageCleaned,
                    ),
                    const SizedBox(height: 16),
                    _StepRow(
                      state: _snapshot.scriptStep,
                      label: l10n.stepTextFound,
                    ),
                    const SizedBox(height: 16),
                    _StepRow(
                      state: _snapshot.readStep,
                      label: l10n.stepReadingText,
                      detail: _snapshot.totalLines > 0
                          ? localizeDigits(
                              l10n.stepLineProgress(
                                _snapshot.currentLine,
                                _snapshot.totalLines,
                              ),
                              locale,
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _StepRow(
                      state: _snapshot.detailsStep,
                      label: l10n.stepFindingDetails,
                    ),
                    if (_snapshot.hasHandwriting) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: c.bgSunken,
                          borderRadius: BorderRadius.circular(
                            RosidSizeTokens.radiusControl,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: RosidIcon(
                                RosidIcons.info,
                                size: 18,
                                color: c.inkSecondary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                l10n.handwritingNote,
                                style: RosidTextTokens.uiCaption.copyWith(
                                  color: c.inkPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  RosidIcon(RosidIcons.shield, size: 16, color: c.goodBase),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.happensOnPhone,
                      style: RosidTextTokens.uiCaption.copyWith(
                        color: c.inkSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              RosidButton(
                key: const ValueKey('reading-cancel'),
                label: l10n.cancel,
                kind: RosidButtonKind.outline,
                expand: true,
                onPressed: _cancel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanPreviewCard extends StatelessWidget {
  const _ScanPreviewCard({
    required this.page,
    required this.previewWidget,
    required this.scanBarFraction,
  });

  final CapturedPageDraft? page;
  final Widget? previewWidget;
  final double scanBarFraction;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final imagePath = page?.cleanedColorPath ?? page?.originalPath;

    return Container(
      height: 292,
      padding: const EdgeInsets.fromLTRB(56, 20, 56, 0),
      decoration: BoxDecoration(
        color: c.bgSunken,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final barY = (constraints.maxHeight * scanBarFraction).clamp(
              18.0,
              constraints.maxHeight - 8,
            );
            return Stack(
              fit: StackFit.expand,
              children: [
                if (previewWidget != null)
                  previewWidget!
                else if (imagePath != null && File(imagePath).existsSync())
                  Image.file(File(imagePath), fit: BoxFit.cover)
                else
                  ColoredBox(color: c.paperSheet),
                Positioned(
                  left: 0,
                  right: 0,
                  top: (barY - 24).clamp(0.0, constraints.maxHeight),
                  height: 24,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.inkPrimary.withValues(alpha: 0.16),
                      border: Border(
                        bottom: BorderSide(color: c.accentBase, width: 2.2),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.state, required this.label, this.detail});

  final ReadingStepState state;
  final String label;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final Widget leading;
    final Color textColor;
    final TextStyle style;

    switch (state) {
      case ReadingStepState.done:
        leading = RosidIcon(
          RosidIcons.checkCircle,
          size: 20,
          color: c.goodBase,
        );
        textColor = c.inkPrimary;
        style = RosidTextTokens.uiBody;
      case ReadingStepState.active:
        leading = SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: c.accentBase,
          ),
        );
        textColor = c.inkPrimary;
        style = RosidTextTokens.uiBodyStrong;
      case ReadingStepState.pending:
        leading = Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: c.lineStrong, width: 1.5),
          ),
        );
        textColor = c.inkTertiary;
        style = RosidTextTokens.uiBody;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 2), child: leading),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: style.copyWith(color: textColor)),
              if (detail != null) ...[
                const SizedBox(height: 2),
                Text(
                  detail!,
                  style: RosidTextTokens.uiCaption.copyWith(
                    color: c.inkSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
