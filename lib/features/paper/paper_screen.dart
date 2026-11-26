import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rosid/core/extensions/l10n_extension.dart';
import 'package:rosid/core/theme/app_theme.dart';
import 'package:rosid/core/theme/rosid_icons.dart';
import 'package:rosid/core/theme/tokens.g.dart';
import 'package:rosid/core/utils/bangla_digits.dart';
import 'package:rosid/core/widgets/rosid_controls.dart';
import 'package:rosid/core/widgets/rosid_navigation.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/features/paper/paper_repository.dart';
import 'package:rosid/features/translation/english_draft_view.dart';
import 'package:rosid/ocr/pipeline/reading_interfaces.dart';
import 'package:rosid/parsing/land_units.dart';
import 'package:rosid/parsing/paper_classifier.dart';
import 'package:rosid/translation/draft_rules.dart';
import 'package:rosid/translation/translation_repository.dart';

/// Paper reader screen matching `design/screens/read-text.png`,
/// `read-text-dark.png`, `read-scan-tap-line.png`,
/// `translate-english-draft.png`, and `translate-english-draft-dark.png`.
class PaperScreen extends ConsumerStatefulWidget {
  const PaperScreen({
    required this.scanId,
    this.initialTab = RosidReaderTab.text,
    this.previewScanWidget,
    this.previewSelectedLineId,
    this.previewShowListen,
    this.previewDraftLines,
    this.previewTerms,
    super.key,
  });

  final String scanId;
  final RosidReaderTab initialTab;

  @visibleForTesting
  final Widget? previewScanWidget;

  @visibleForTesting
  final String? previewSelectedLineId;

  @visibleForTesting
  final bool? previewShowListen;

  @visibleForTesting
  final List<DraftLineView>? previewDraftLines;

  @visibleForTesting
  final List<TermRule>? previewTerms;

  @override
  ConsumerState<PaperScreen> createState() => _PaperScreenState();
}

class _PaperScreenState extends ConsumerState<PaperScreen> {
  late RosidReaderTab _tab;
  String? _selectedLineId;
  int _selectedPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _selectedLineId = widget.previewSelectedLineId;
  }

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final paperAsync = ref.watch(paperViewProvider(widget.scanId));
    final voiceAvailable =
        widget.previewShowListen ??
        ref.watch(banglaVoiceAvailableProvider).value ??
        false;

    return paperAsync.when(
      loading: () => Scaffold(
        backgroundColor: c.bgCanvas,
        appBar: RosidTopBar(title: l10n.document, showBack: true),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Scaffold(
        backgroundColor: c.bgCanvas,
        appBar: RosidTopBar(title: l10n.document, showBack: true),
        body: Center(
          child: Text(
            l10n.loadFailed,
            style: RosidTextTokens.uiBody.copyWith(color: c.inkSecondary),
          ),
        ),
      ),
      data: (paper) {
        if (paper == null) {
          return Scaffold(
            backgroundColor: c.bgCanvas,
            appBar: RosidTopBar(title: l10n.document, showBack: true),
            body: Center(
              child: Text(
                l10n.noPapersYet,
                style: RosidTextTokens.uiBody.copyWith(color: c.inkSecondary),
              ),
            ),
          );
        }

        final selectedLine = _findSelectedLine(paper);

        return Scaffold(
          backgroundColor: c.bgCanvas,
          appBar: RosidTopBar(
            title: paper.title,
            showBack: true,
            onBack: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
            trailing: [
              PopupMenuButton<String>(
                key: const ValueKey('paper-more-menu'),
                icon: RosidIcon(RosidIcons.more, size: 22, color: c.inkPrimary),
                onSelected: (action) {
                  if (action == 'kind') _showKindPicker(context, paper);
                  if (action == 'edit') _showFullTextEditor(context, paper);
                  if (action == 'renew') _pickRenewByDate(context, paper);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'kind',
                    child: Text(l10n.changePaperKind),
                  ),
                  PopupMenuItem(value: 'edit', child: Text(l10n.editFullText)),
                  PopupMenuItem(
                    value: 'renew',
                    child: Text(l10n.setRenewByDate),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_tab == RosidReaderTab.text) ...[
                      Row(
                        children: [
                          InkWell(
                            key: const ValueKey('paper-kind-pill'),
                            onTap: () => _showKindPicker(context, paper),
                            borderRadius: BorderRadius.circular(
                              RosidSizeTokens.radiusPill,
                            ),
                            child: RosidPill(
                              label: _kindLabel(context, paper.paperKind),
                              tone: RosidTone.accent,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _metaCaption(context, paper, locale),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: RosidTextTokens.uiCaption.copyWith(
                                color: c.inkSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    RosidReaderTabs(
                      active: _tab,
                      scanLabel: l10n.scanTab,
                      textLabel: l10n.body,
                      englishLabel: l10n.englishTab,
                      onChanged: (next) => setState(() => _tab = next),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: switch (_tab) {
                  RosidReaderTab.text => _buildTextTab(context, paper, locale),
                  RosidReaderTab.scan => _buildScanTab(
                    context,
                    paper,
                    selectedLine,
                    locale,
                  ),
                  RosidReaderTab.english => EnglishDraftView(
                    scanId: paper.scan.id,
                    previewLines: widget.previewDraftLines,
                    previewTerms: widget.previewTerms,
                    onExport: () =>
                        context.push('/paper/${paper.scan.id}/export'),
                  ),
                },
              ),
              if (_tab == RosidReaderTab.text)
                _PaperActionBar(
                  showListen: voiceAvailable,
                  onCopy: () => _copyText(context, paper.displayBody),
                  onListen: () => ref
                      .read(offlineSpeechServiceProvider)
                      .speak(paper.displayBody),
                  onEdit: () => _showFullTextEditor(context, paper),
                  onExport: () => context.push(
                    paper.paperKind == PaperKind.idCard
                        ? '/paper/${paper.scan.id}/export/id'
                        : '/paper/${paper.scan.id}/export',
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  TextLine? _findSelectedLine(PaperViewData paper) {
    if (_selectedLineId == null) return null;
    for (final l in paper.lines) {
      if (l.id == _selectedLineId) return l;
    }
    return null;
  }

  Widget _buildTextTab(
    BuildContext context,
    PaperViewData paper,
    Locale locale,
  ) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    final checkCount = paper.wordsToCheckCount;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
      children: [
        if (checkCount > 0) ...[
          InkWell(
            key: const ValueKey('paper-check-banner'),
            onTap: () async {
              await context.push('/paper/${paper.scan.id}/check');
              ref.invalidate(paperViewProvider(widget.scanId));
            },
            borderRadius: BorderRadius.circular(RosidSizeTokens.radiusControl),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: c.warnSoft,
                borderRadius: BorderRadius.circular(
                  RosidSizeTokens.radiusControl,
                ),
              ),
              child: Row(
                children: [
                  RosidIcon(RosidIcons.alert, size: 18, color: c.warnBase),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      localizeDigits(l10n.wordsNeedALook(checkCount), locale),
                      style: RosidTextTokens.uiLabel.copyWith(
                        color: c.inkPrimary,
                      ),
                    ),
                  ),
                  Text(
                    l10n.checkThem,
                    style: RosidTextTokens.uiLabel.copyWith(
                      color: c.accentBase,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (paper.details.isNotEmpty) ...[
          _KeyDetailsCard(
            details: paper.details,
            onTapDetail: (detail) {
              setState(() {
                _tab = RosidReaderTab.scan;
                _selectedLineId = detail.sourceLineId;
              });
            },
          ),
          const SizedBox(height: 16),
        ],
        _PaperTextSurface(
          paper: paper,
          onTapUncertainWord: () async {
            await context.push('/paper/${paper.scan.id}/check');
            ref.invalidate(paperViewProvider(widget.scanId));
          },
        ),
      ],
    );
  }

  Widget _buildScanTab(
    BuildContext context,
    PaperViewData paper,
    TextLine? selectedLine,
    Locale locale,
  ) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    final pageLines = paper.lines
        .where((l) => l.pageIndex == _selectedPageIndex)
        .toList();
    final pagePath = _selectedPageIndex < paper.pages.length
        ? (paper.pages[_selectedPageIndex].processedPath ??
              paper.pages[_selectedPageIndex].imagePath)
        : paper.scan.imagePath;

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: c.bgSunken,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(14),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 0.72,
                  child: Container(
                    decoration: BoxDecoration(
                      color: RosidColorTokens.paperSheetLight,
                      borderRadius: BorderRadius.circular(
                        RosidSizeTokens.radiusPaper,
                      ),
                      boxShadow: RosidShadowTokens.elevPaper,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            if (widget.previewScanWidget != null)
                              widget.previewScanWidget!
                            else if (File(pagePath).existsSync())
                              Image.file(File(pagePath), fit: BoxFit.contain)
                            else
                              const ColoredBox(
                                color: RosidColorTokens.paperSheetLight,
                              ),
                            for (final line in pageLines)
                              _buildLineHitOverlay(
                                context,
                                line,
                                constraints.biggest,
                                selected: line.id == _selectedLineId,
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (paper.pages.length > 1 && selectedLine == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < paper.pages.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: RosidChip(
                      label: localizeDigits('${i + 1}', locale),
                      selected: i == _selectedPageIndex,
                      onTap: () => setState(() {
                        _selectedPageIndex = i;
                        _selectedLineId = null;
                      }),
                    ),
                  ),
              ],
            ),
          ),
        if (selectedLine != null)
          _TappedLineSheet(
            line: selectedLine,
            pageLabel: localizeDigits(
              l10n.pageOfTotal(
                _selectedPageIndex + 1,
                paper.pages.isEmpty ? 1 : paper.pages.length,
              ),
              locale,
            ),
            onCopy: () => _copyText(context, selectedLine.textContent),
            onFix: () => _showLineEditor(context, paper, selectedLine),
            onClose: () => setState(() => _selectedLineId = null),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(
              l10n.tapALineHint,
              textAlign: TextAlign.center,
              style: RosidTextTokens.uiCaption.copyWith(color: c.inkSecondary),
            ),
          ),
      ],
    );
  }

  Widget _buildLineHitOverlay(
    BuildContext context,
    TextLine line,
    Size canvasSize, {
    required bool selected,
  }) {
    final c = RosidColors.of(context);
    final box = DetectedLineBox.fromBoxJson(line.boxJson);
    if (box == null) return const SizedBox.shrink();
    final rect = box.boundingRect;
    // Boxes may be stored in normalized [0..1] or pixel coordinates (assume <=1.5 normalized).
    final isNormalized = rect.right <= 1.5 && rect.bottom <= 1.5;
    final left = isNormalized
        ? rect.left * canvasSize.width
        : (rect.left / 820.0) * canvasSize.width;
    final top = isNormalized
        ? rect.top * canvasSize.height
        : (rect.top / 680.0) * canvasSize.height;
    final width =
        (isNormalized
                ? rect.width * canvasSize.width
                : (rect.width / 820.0) * canvasSize.width)
            .clamp(24.0, canvasSize.width);
    final height =
        (isNormalized
                ? rect.height * canvasSize.height
                : (rect.height / 680.0) * canvasSize.height)
            .clamp(20.0, canvasSize.height);

    return Positioned(
      left: left.clamp(0.0, canvasSize.width - 24),
      top: top.clamp(0.0, canvasSize.height - 20),
      width: width,
      height: height,
      child: GestureDetector(
        key: ValueKey('scan-line-${line.id}'),
        onTap: () => setState(() => _selectedLineId = line.id),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected
                ? c.accentBase.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: selected
                ? Border.all(color: c.accentBase, width: 2.0)
                : null,
          ),
        ),
      ),
    );
  }

  Future<void> _copyText(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.copied)));
  }

  Future<void> _showKindPicker(
    BuildContext context,
    PaperViewData paper,
  ) async {
    final chosen = await showModalBottomSheet<PaperKind>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              for (final k in PaperKind.values)
                ListTile(
                  title: Text(_kindLabel(ctx, k)),
                  trailing: k == paper.paperKind
                      ? RosidIcon(
                          RosidIcons.check,
                          size: 20,
                          color: RosidColors.of(ctx).accentBase,
                        )
                      : null,
                  onTap: () => Navigator.of(ctx).pop(k),
                ),
            ],
          ),
        );
      },
    );
    if (chosen != null && chosen != paper.paperKind) {
      await ref
          .read(paperRepositoryProvider)
          .updatePaperKind(paper.scan.id, chosen);
      ref.invalidate(paperViewProvider(widget.scanId));
    }
  }

  Future<void> _pickRenewByDate(
    BuildContext context,
    PaperViewData paper,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: paper.scan.renewBy ?? now.add(const Duration(days: 30)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) {
      await ref
          .read(paperRepositoryProvider)
          .updateRenewBy(paper.scan.id, picked);
      ref.invalidate(paperViewProvider(widget.scanId));
    }
  }

  Future<void> _showFullTextEditor(
    BuildContext context,
    PaperViewData paper,
  ) async {
    final titleCtrl = TextEditingController(text: paper.title);
    final bodyCtrl = TextEditingController(text: paper.displayBody);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final c = RosidColors.of(ctx);
        final l10n = ctx.l10n;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.editFullText,
                style: RosidTextTokens.uiTitle.copyWith(color: c.inkPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.originalTextKept,
                style: RosidTextTokens.uiCaption.copyWith(
                  color: c.inkSecondary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('edit-paper-title'),
                controller: titleCtrl,
                decoration: InputDecoration(labelText: l10n.title),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('edit-paper-body'),
                controller: bodyCtrl,
                maxLines: 8,
                style: RosidTextTokens.docBody.copyWith(color: c.inkPrimary),
                decoration: InputDecoration(labelText: l10n.body),
              ),
              const SizedBox(height: 16),
              RosidButton(
                key: const ValueKey('edit-paper-save'),
                label: l10n.save,
                expand: true,
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
        );
      },
    );
    if (saved ?? false) {
      await ref
          .read(paperRepositoryProvider)
          .updateFullText(
            paper.scan.id,
            title: titleCtrl.text.trim(),
            body: bodyCtrl.text,
          );
      ref.invalidate(paperViewProvider(widget.scanId));
    }
    titleCtrl.dispose();
    bodyCtrl.dispose();
  }

  Future<void> _showLineEditor(
    BuildContext context,
    PaperViewData paper,
    TextLine line,
  ) async {
    final ctrl = TextEditingController(text: line.textContent);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.fixText),
        content: TextField(
          key: const ValueKey('fix-line-field'),
          controller: ctrl,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            key: const ValueKey('fix-line-save'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.l10n.save),
          ),
        ],
      ),
    );
    if (saved ?? false) {
      await ref
          .read(paperRepositoryProvider)
          .fixLineText(scanId: paper.scan.id, line: line, newText: ctrl.text);
      ref.invalidate(paperViewProvider(widget.scanId));
    }
    ctrl.dispose();
  }

  String _kindLabel(BuildContext context, PaperKind kind) {
    final l10n = context.l10n;
    return switch (kind) {
      PaperKind.land => l10n.landRecord,
      PaperKind.deed => l10n.paperKindDeed,
      PaperKind.certificate => l10n.certificate,
      PaperKind.idCard => l10n.idCard,
      PaperKind.licence => l10n.paperKindLicence,
      PaperKind.bill => l10n.paperKindBill,
      PaperKind.receipt => l10n.receipt,
      PaperKind.letter => l10n.paperKindLetter,
      PaperKind.notes => l10n.paperKindNotes,
      PaperKind.document => l10n.document,
    };
  }

  String _metaCaption(
    BuildContext context,
    PaperViewData paper,
    Locale locale,
  ) {
    final l10n = context.l10n;
    final pageCount = paper.pages.isEmpty ? 1 : paper.pages.length;
    final now = DateTime.now();
    final created = paper.scan.createdAt;
    final isToday =
        created.year == now.year &&
        created.month == now.month &&
        created.day == now.day;
    final datePart = isToday
        ? l10n.scannedToday
        : localizeDigits(
            DateFormat.MMMd(locale.toLanguageTag()).format(created),
            locale,
          );
    return '${localizeDigits(l10n.pagesCount(pageCount), locale)}, $datePart';
  }
}

class _KeyDetailsCard extends StatelessWidget {
  const _KeyDetailsCard({required this.details, required this.onTapDetail});

  final List<Detail> details;
  final ValueChanged<Detail> onTapDetail;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    // Show top 4 key details cleanly as in `read-text.png` (Khatian, Plot, Owner, Area).
    final visible = details.take(4).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: c.bgSheet,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.lineSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.keyDetails,
            style: RosidTextTokens.uiHeading.copyWith(color: c.inkPrimary),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) Divider(color: c.lineSubtle, height: 1),
            InkWell(
              onTap: () => onTapDetail(visible[i]),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 112,
                      child: Text(
                        _detailLabel(context, visible[i].detailKey),
                        style: RosidTextTokens.uiCaption.copyWith(
                          color: c.inkSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            visible[i].value,
                            style: RosidTextTokens.docBody.copyWith(
                              color: c.inkPrimary,
                            ),
                          ),
                          if (visible[i].detailKey == 'area') ...[
                            Builder(
                              builder: (_) {
                                final conv = LandUnits.parseFromText(
                                  visible[i].value,
                                );
                                if (conv == null) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    conv.detailSubtitle,
                                    style: RosidTextTokens.uiCaption.copyWith(
                                      color: c.inkSecondary,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _detailLabel(BuildContext context, String key) {
    final l10n = context.l10n;
    return switch (key) {
      'khatian_no' => l10n.khatianNo,
      'plot_no' => l10n.plotDagNo,
      'owner' => l10n.ownerLabel,
      'father' => l10n.fatherLabel,
      'mouza' => l10n.mouzaLabel,
      'jl_no' => l10n.jlNoLabel,
      'area' => l10n.areaLabel,
      'shop' => l10n.merchant,
      'total' => l10n.total,
      'vat' => l10n.tax,
      'payment_method' => l10n.paymentMethod,
      'date' => l10n.purchaseDate,
      _ => key,
    };
  }
}

/// Paper reading surface (`read-text.png` & `read-text-dark.png`):
/// ALWAYS light paper (`paperSheetLight` + `paperInkLight`) in Tiro Bangla,
/// with uncertain words highlighted in warm yellow chips.
class _PaperTextSurface extends StatelessWidget {
  const _PaperTextSurface({
    required this.paper,
    required this.onTapUncertainWord,
  });

  final PaperViewData paper;
  final VoidCallback onTapUncertainWord;

  @override
  Widget build(BuildContext context) {
    final uncertainTokens = <String>{for (final w in paper.checkWords) w.word};
    final lines = paper.displayBody
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
      decoration: BoxDecoration(
        color: RosidColorTokens.paperSheetLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RosidColorTokens.paperLineLight),
        boxShadow: RosidShadowTokens.elevPaper,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0) SizedBox(height: i == 1 ? 10 : 8),
            _HighlightedDocumentLine(
              text: lines[i],
              isHeading: i == 0,
              uncertainTokens: uncertainTokens,
              onTapUncertain: onTapUncertainWord,
            ),
          ],
        ],
      ),
    );
  }
}

class _HighlightedDocumentLine extends StatelessWidget {
  const _HighlightedDocumentLine({
    required this.text,
    required this.isHeading,
    required this.uncertainTokens,
    required this.onTapUncertain,
  });

  final String text;
  final bool isHeading;
  final Set<String> uncertainTokens;
  final VoidCallback onTapUncertain;

  @override
  Widget build(BuildContext context) {
    final baseStyle =
        (isHeading ? RosidTextTokens.docTitle : RosidTextTokens.docBody)
            .copyWith(color: RosidColorTokens.paperInkLight);

    if (uncertainTokens.isEmpty) {
      return Text(text, style: baseStyle);
    }

    final words = text.split(' ');
    final spans = <InlineSpan>[];
    for (var i = 0; i < words.length; i++) {
      if (i > 0) spans.add(TextSpan(text: ' ', style: baseStyle));
      final w = words[i];
      final clean = w.replaceAll(RegExp(r'^[,.:;()।]+|[,.:;()।]+$'), '');
      if (uncertainTokens.contains(clean)) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: onTapUncertain,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: RosidColorTokens.warnSoftLight,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(w, style: baseStyle),
              ),
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: w, style: baseStyle));
      }
    }
    return Text.rich(TextSpan(children: spans));
  }
}

class _PaperActionBar extends StatelessWidget {
  const _PaperActionBar({
    required this.showListen,
    required this.onCopy,
    required this.onListen,
    required this.onEdit,
    required this.onExport,
  });

  final bool showListen;
  final VoidCallback onCopy;
  final VoidCallback onListen;
  final VoidCallback onEdit;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;

    return Container(
      decoration: BoxDecoration(
        color: c.bgSheet,
        border: Border(top: BorderSide(color: c.lineSubtle)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _BarIconAction(
              key: const ValueKey('paper-action-copy'),
              icon: RosidIcons.copy,
              label: l10n.copy,
              onTap: onCopy,
            ),
            if (showListen)
              _BarIconAction(
                key: const ValueKey('paper-action-listen'),
                icon: RosidIcons.listen,
                label: l10n.listen,
                onTap: onListen,
              ),
            _BarIconAction(
              key: const ValueKey('paper-action-edit'),
              icon: RosidIcons.edit,
              label: l10n.edit,
              onTap: onEdit,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RosidButton(
                key: const ValueKey('paper-action-export'),
                label: l10n.export,
                icon: RosidIcons.share,
                expand: true,
                onPressed: onExport,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarIconAction extends StatelessWidget {
  const _BarIconAction({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final RosidIcons icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 56,
        height: 48,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RosidIcon(icon, size: 20, color: c.inkPrimary),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RosidTextTokens.uiMicro.copyWith(color: c.inkSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Anchored bottom sheet when tapping a line on Scan tab (`read-scan-tap-line.png`).
class _TappedLineSheet extends StatelessWidget {
  const _TappedLineSheet({
    required this.line,
    required this.pageLabel,
    required this.onCopy,
    required this.onFix,
    required this.onClose,
  });

  final TextLine line;
  final String pageLabel;
  final VoidCallback onCopy;
  final VoidCallback onFix;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    final area = LandUnits.parseFromText(line.textContent);

    return Container(
      key: const ValueKey('scan-line-sheet'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.bgSheet,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(RosidSizeTokens.radiusSheet),
        ),
        boxShadow: RosidShadowTokens.elevDock,
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                onTap: onClose,
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: c.lineStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Text(
              area != null ? l10n.areaOfLand : pageLabel,
              style: RosidTextTokens.uiCaption.copyWith(color: c.inkSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              line.textContent,
              style: RosidTextTokens.docTitle.copyWith(
                color: c.inkPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (area != null) ...[
              const SizedBox(height: 12),
              Text(
                l10n.sameAreaOtherUnits,
                style: RosidTextTokens.uiCaption.copyWith(
                  color: c.inkSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final chip in area.chipLabels)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: c.bgCanvas,
                        borderRadius: BorderRadius.circular(
                          RosidSizeTokens.radiusPill,
                        ),
                        border: Border.all(color: c.lineSubtle),
                      ),
                      child: Text(
                        chip,
                        style: RosidTextTokens.uiLabel.copyWith(
                          color: c.inkPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: RosidButton(
                    key: const ValueKey('sheet-copy-line'),
                    label: l10n.copy,
                    icon: RosidIcons.copy,
                    kind: RosidButtonKind.tonal,
                    expand: true,
                    onPressed: onCopy,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: RosidButton(
                    key: const ValueKey('sheet-fix-line'),
                    label: l10n.fixText,
                    icon: RosidIcons.edit,
                    kind: RosidButtonKind.outline,
                    expand: true,
                    onPressed: onFix,
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
