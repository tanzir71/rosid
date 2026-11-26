import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rosid/core/extensions/l10n_extension.dart';
import 'package:rosid/core/theme/app_theme.dart';
import 'package:rosid/core/theme/rosid_icons.dart';
import 'package:rosid/core/theme/tokens.g.dart';
import 'package:rosid/core/widgets/rosid_controls.dart';
import 'package:rosid/core/widgets/rosid_navigation.dart';
import 'package:rosid/export/export_models.dart';
import 'package:rosid/export/paper_export_service.dart';
import 'package:rosid/features/export/export_controller.dart';
import 'package:rosid/features/paper/paper_repository.dart';
import 'package:rosid/translation/translation_repository.dart';

/// Preview for certification screen (`/paper/:id/export/preview`) matching
/// `design/screens/export-preview-certification.png`.
class ExportPreviewScreen extends ConsumerStatefulWidget {
  const ExportPreviewScreen({
    required this.scanId,
    this.initialPage = 1,
    this.previewEnglishLines,
    this.previewWatermark,
    super.key,
  });

  final String scanId;
  final int initialPage;

  @visibleForTesting
  final List<String>? previewEnglishLines;

  @visibleForTesting
  final String? previewWatermark;

  @override
  ConsumerState<ExportPreviewScreen> createState() =>
      _ExportPreviewScreenState();
}

class _ExportPreviewScreenState extends ConsumerState<ExportPreviewScreen> {
  late int _selectedTab;
  bool _busy = false;
  List<DraftLineView> _draftLines = const [];

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialPage;
    if (widget.previewEnglishLines == null) {
      _loadDraft();
    }
  }

  Future<void> _loadDraft() async {
    final loaded = await ref
        .read(translationRepositoryProvider)
        .loadDraft(widget.scanId);
    if (mounted) setState(() => _draftLines = loaded);
  }

  Future<void> _exportAndAction(
    PaperViewData paper, {
    required bool printOnly,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final config = ref
          .read(paperExportControllerProvider)
          .config
          .copyWith(fileType: ExportFileType.pdf);
      final draft = _draftLines.isNotEmpty
          ? _draftLines
          : await ref
                .read(translationRepositoryProvider)
                .generateOrRefreshDraft(
                  paper.scan.id,
                  forceRefreshUnedited: false,
                );
      final res = await ref
          .read(paperExportServiceProvider)
          .createExport(paper: paper, englishLines: draft, config: config);

      if (printOnly) {
        await ref
            .read(platformFileServiceProvider)
            .printPdf(filePath: res.tempFilePath, jobName: res.fileName);
        return;
      }

      final saf = await ref
          .read(platformFileServiceProvider)
          .saveFileToPhone(
            sourcePath: res.tempFilePath,
            suggestedName: res.fileName,
            mimeType: res.mimeType,
          );
      ref
          .read(paperExportControllerProvider.notifier)
          .recordExport(
            result: res,
            savedUri: saf.uri,
            savedLocationLabel:
                'Downloads, Rosid, ${saf.displayName ?? res.fileName}',
          );
      if (!mounted) return;
      context.push('/paper/${paper.scan.id}/export/saved');
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.exportFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    final paperAsync = ref.watch(paperViewProvider(widget.scanId));
    final config = ref.watch(paperExportControllerProvider).config;
    final watermark =
        widget.previewWatermark ??
        (config.watermarkEnabled ? config.watermarkText : '');

    return paperAsync.when(
      loading: () => Scaffold(
        backgroundColor: c.bgCanvas,
        appBar: RosidTopBar(title: l10n.preview, showBack: true),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Scaffold(
        backgroundColor: c.bgCanvas,
        appBar: RosidTopBar(title: l10n.preview, showBack: true),
        body: Center(child: Text(l10n.loadFailed)),
      ),
      data: (paper) {
        if (paper == null) {
          return Scaffold(
            backgroundColor: c.bgCanvas,
            appBar: RosidTopBar(title: l10n.preview, showBack: true),
            body: Center(child: Text(l10n.noPapersYet)),
          );
        }

        final englishLines =
            widget.previewEnglishLines ??
            _draftLines.map((d) => d.englishText).toList();
        final tabs = <(int, String)>[
          (1, l10n.scanTab),
          (2, l10n.englishTab),
          (3, l10n.toSignTab),
        ];

        return Scaffold(
          backgroundColor: c.bgCanvas,
          appBar: RosidTopBar(title: l10n.preview, showBack: true),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: c.bgSunken,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: AspectRatio(
                        aspectRatio: 0.71,
                        child: Container(
                          decoration: BoxDecoration(
                            color: RosidColorTokens.paperSheetLight,
                            borderRadius: BorderRadius.circular(
                              RosidSizeTokens.radiusPaper,
                            ),
                            boxShadow: RosidShadowTokens.elevPaper,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _buildPreviewPage(
                            context,
                            paper: paper,
                            englishLines: englishLines,
                            watermark: watermark,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < tabs.length; i++) ...[
                          if (i > 0) const SizedBox(width: 12),
                          GestureDetector(
                            key: ValueKey('preview-page-tab-$i'),
                            onTap: () => setState(() => _selectedTab = i),
                            child: Column(
                              children: [
                                Container(
                                  width: 52,
                                  height: 64,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: c.bgSheet,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: _selectedTab == i
                                          ? c.accentBase
                                          : c.lineSubtle,
                                      width: _selectedTab == i ? 2 : 1,
                                    ),
                                  ),
                                  child: Text(
                                    '${tabs[i].$1}',
                                    style: RosidTextTokens.uiLabel.copyWith(
                                      color: _selectedTab == i
                                          ? c.inkPrimary
                                          : c.inkSecondary,
                                      fontWeight: _selectedTab == i
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  tabs[i].$2,
                                  style: RosidTextTokens.uiMicro.copyWith(
                                    color: _selectedTab == i
                                        ? c.accentBase
                                        : c.inkSecondary,
                                    fontWeight: _selectedTab == i
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: c.accentSoft,
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
                              RosidIcons.seal,
                              size: 20,
                              color: c.accentInk,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.nextGetCertified,
                                  style: RosidTextTokens.uiBodyStrong.copyWith(
                                    color: c.accentInk,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.nextGetCertifiedBody,
                                  style: RosidTextTokens.uiCaption.copyWith(
                                    color: c.accentInk,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: c.bgSheet,
                  border: Border(top: BorderSide(color: c.lineSubtle)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      RosidButton(
                        key: const ValueKey('preview-print-button'),
                        label: l10n.print,
                        icon: RosidIcons.print,
                        kind: RosidButtonKind.outline,
                        onPressed: _busy
                            ? null
                            : () => _exportAndAction(paper, printOnly: true),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RosidButton(
                          key: const ValueKey('preview-save-button'),
                          label: l10n.saveToPhone,
                          icon: RosidIcons.save,
                          expand: true,
                          busy: _busy,
                          onPressed: () =>
                              _exportAndAction(paper, printOnly: false),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPreviewPage(
    BuildContext context, {
    required PaperViewData paper,
    required List<String> englishLines,
    required String watermark,
  }) {
    final l10n = context.l10n;
    final paperInk = RosidColorTokens.paperInkLight;
    final muted = const Color(0xFF6A6D7C);

    Widget content;
    if (_selectedTab == 0) {
      final path = paper.pages.isNotEmpty
          ? (paper.pages.first.processedPath ?? paper.pages.first.imagePath)
          : paper.scan.imagePath;
      content = File(path).existsSync()
          ? Image.file(File(path), fit: BoxFit.contain)
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                paper.displayBody,
                style: RosidTextTokens.docSmall.copyWith(color: paperInk),
              ),
            );
    } else if (_selectedTab == 2) {
      content = Padding(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.translatorCertTitle,
              style: RosidTextTokens.docTitle.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: paperInk,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.translatorCertBody,
              style: RosidTextTokens.docSmall.copyWith(
                fontSize: 10.5,
                color: paperInk,
              ),
            ),
            const SizedBox(height: 18),
            for (final line in [
              l10n.ownerLabel,
              l10n.purchaseDate,
              l10n.translatorSignPageSub,
            ]) ...[
              Text(line, style: TextStyle(fontSize: 9, color: muted)),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFC5C8BE)),
              const SizedBox(height: 10),
            ],
          ],
        ),
      );
    } else {
      // Page 2: Laid-out English draft with DRAFT TRANSLATION stamp & footer
      final hasHeaderSub = englishLines.length > 2;
      final subHeader = hasHeaderSub ? englishLines.first : null;
      final header = hasHeaderSub
          ? englishLines[1]
          : (englishLines.isNotEmpty ? englishLines.first : paper.title);
      final bodyLines = hasHeaderSub
          ? englishLines.sublist(2)
          : (englishLines.length > 1 ? englishLines.sublist(1) : englishLines);
      content = Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (subHeader != null) ...[
              Text(
                subHeader,
                textAlign: TextAlign.center,
                style: RosidTextTokens.docSmall.copyWith(
                  fontSize: 10.5,
                  color: muted,
                ),
              ),
              const SizedBox(height: 2),
            ],
            Text(
              header,
              textAlign: TextAlign.center,
              style: RosidTextTokens.docTitle.copyWith(
                fontSize: 15.5,
                color: paperInk,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Divider(color: Color(0xFFDCE0D3), height: 14),
            for (final line in bodyLines.take(8)) ...[
              Text(
                line,
                style: RosidTextTokens.docSmall.copyWith(
                  fontSize: 11.2,
                  height: 1.55,
                  color: paperInk,
                ),
              ),
              const SizedBox(height: 3),
            ],
            const Spacer(),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12, right: 4),
                child: Theme(
                  data: AppTheme.light(),
                  child: RosidStamp(
                    label: l10n.draftTranslationStamp,
                    tone: RosidStampTone.accent,
                    angleRadians: 0.08,
                  ),
                ),
              ),
            ),
            Text(
              l10n.draftTranslationFooter,
              style: RosidTextTokens.uiMicro.copyWith(
                color: RosidColorTokens.accentBaseLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        if (watermark.isNotEmpty)
          IgnorePointer(
            child: Center(
              child: Transform.rotate(
                angle: -0.58,
                child: Text(
                  watermark,
                  textAlign: TextAlign.center,
                  style: RosidTextTokens.uiHeading.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: RosidColorTokens.accentBaseLight.withValues(
                      alpha: 0.16,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
