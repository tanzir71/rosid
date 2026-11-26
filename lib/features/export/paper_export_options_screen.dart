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
import 'package:rosid/core/widgets/rosid_inputs.dart';
import 'package:rosid/core/widgets/rosid_navigation.dart';
import 'package:rosid/export/export_models.dart';
import 'package:rosid/export/paper_export_service.dart';
import 'package:rosid/features/export/export_controller.dart';
import 'package:rosid/features/paper/paper_repository.dart';
import 'package:rosid/parsing/paper_classifier.dart';
import 'package:rosid/translation/translation_repository.dart';

/// Export options screen (`/paper/:id/export`) matching `design/screens/export-options.png`.
class PaperExportOptionsScreen extends ConsumerStatefulWidget {
  const PaperExportOptionsScreen({
    required this.scanId,
    this.previewConfig,
    this.previewSizeSummary,
    this.previewFileName,
    super.key,
  });

  final String scanId;

  @visibleForTesting
  final PaperExportConfig? previewConfig;

  @visibleForTesting
  final String? previewSizeSummary;

  @visibleForTesting
  final String? previewFileName;

  @override
  ConsumerState<PaperExportOptionsScreen> createState() =>
      _PaperExportOptionsScreenState();
}

class _PaperExportOptionsScreenState
    extends ConsumerState<PaperExportOptionsScreen> {
  bool _saving = false;
  bool _exceededLimit = false;

  @override
  void initState() {
    super.initState();
    if (widget.previewConfig != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(paperExportControllerProvider.notifier)
              .updateConfig(widget.previewConfig!);
        }
      });
    }
  }

  Future<void> _saveToPhone(PaperViewData paper) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _exceededLimit = false;
    });
    try {
      final config = ref.read(paperExportControllerProvider).config;
      final draftLines = config.includeEnglish
          ? await ref
                .read(translationRepositoryProvider)
                .generateOrRefreshDraft(
                  paper.scan.id,
                  forceRefreshUnedited: false,
                )
          : const <DraftLineView>[];
      final res = await ref
          .read(paperExportServiceProvider)
          .createExport(paper: paper, englishLines: draftLines, config: config);
      if (res.exceededSizeLimit) {
        if (mounted) {
          setState(() {
            _exceededLimit = true;
            _saving = false;
          });
        }
        return;
      }

      final safRes = await ref
          .read(platformFileServiceProvider)
          .saveFileToPhone(
            sourcePath: res.tempFilePath,
            suggestedName: res.fileName,
            mimeType: res.mimeType,
          );

      final locationLabel = safRes.saved && safRes.displayName != null
          ? 'Downloads, Rosid, ${safRes.displayName}'
          : 'Downloads, Rosid, ${res.fileName}';

      ref
          .read(paperExportControllerProvider.notifier)
          .recordExport(
            result: res,
            savedUri: safRes.uri,
            savedLocationLabel: locationLabel,
          );

      if (!mounted) return;
      context.push('/paper/${paper.scan.id}/export/saved');
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.exportFailed)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickPageSize(PaperExportConfig config) async {
    final l10n = context.l10n;
    final chosen = await showModalBottomSheet<ExportPageSize>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in [
              (ExportPageSize.a4, l10n.pageSizeA4),
              (ExportPageSize.letter, l10n.pageSizeLetter),
              (ExportPageSize.asScanned, l10n.pageSizeAsScanned),
            ])
              ListTile(
                title: Text(item.$2),
                trailing: config.pageSize == item.$1
                    ? RosidIcon(
                        RosidIcons.check,
                        size: 20,
                        color: RosidColors.of(ctx).accentBase,
                      )
                    : null,
                onTap: () => Navigator.of(ctx).pop(item.$1),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) {
      ref
          .read(paperExportControllerProvider.notifier)
          .updateConfig(config.copyWith(pageSize: chosen));
    }
  }

  Future<void> _pickSizeLimit(PaperExportConfig config) async {
    final l10n = context.l10n;
    final chosen = await showModalBottomSheet<int?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(l10n.noSizeLimit),
              onTap: () => Navigator.of(ctx).pop(-1),
            ),
            for (final mb in [1, 2, 5])
              ListTile(
                title: Text(l10n.sizeLimitMb(mb)),
                onTap: () => Navigator.of(ctx).pop(mb * 1024 * 1024),
              ),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    final notifier = ref.read(paperExportControllerProvider.notifier);
    if (chosen == -1) {
      notifier.updateConfig(config.copyWith(clearMaxSize: true));
    } else {
      notifier.updateConfig(config.copyWith(maxSizeBytes: chosen));
    }
  }

  Future<void> _editWatermarkText(PaperExportConfig config) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _WatermarkTextDialog(initial: config.watermarkText),
    );
    if (result != null && result.trim().isNotEmpty) {
      ref
          .read(paperExportControllerProvider.notifier)
          .updateConfig(config.copyWith(watermarkText: result.trim()));
    }
  }

  String _estimateSummary(
    BuildContext context,
    PaperViewData paper,
    PaperExportConfig config,
    Locale locale,
  ) {
    if (widget.previewSizeSummary != null) return widget.previewSizeSummary!;
    final scanPages = paper.pages.isEmpty ? 1 : paper.pages.length;
    var pages = 0;
    if (config.includeScan && config.fileType == ExportFileType.pdf) {
      pages += scanPages;
    } else if (config.fileType == ExportFileType.jpg) {
      pages = scanPages;
    }
    if (config.includeEnglish && config.fileType != ExportFileType.jpg) {
      pages += 1;
    }
    if (config.includeBangla && config.fileType == ExportFileType.pdf) {
      pages += 1;
    }
    if (config.includeTranslatorPage &&
        (config.fileType == ExportFileType.pdf ||
            config.fileType == ExportFileType.docx)) {
      pages += 1;
    }
    if (pages == 0) pages = 1;

    var approxBytes = 0;
    if (config.fileType == ExportFileType.txt ||
        config.fileType == ExportFileType.csv) {
      approxBytes = 4 * 1024;
    } else if (config.fileType == ExportFileType.docx) {
      approxBytes = 18 * 1024;
    } else {
      for (final p in paper.pages) {
        final f = File(p.processedPath ?? p.imagePath);
        if (f.existsSync()) approxBytes += f.lengthSync();
      }
      if (approxBytes == 0) approxBytes = pages * 350 * 1024;
      if (config.maxSizeBytes != null && approxBytes > config.maxSizeBytes!) {
        approxBytes = (config.maxSizeBytes! * 0.72).round();
      }
    }

    final sizeLabel = approxBytes >= 1024 * 1024
        ? '${(approxBytes / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '${(approxBytes / 1024).ceil()} KB';
    return '${localizeDigits(context.l10n.pagesCount(pages), locale)}, $sizeLabel';
  }

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final paperAsync = ref.watch(paperViewProvider(widget.scanId));
    final config =
        widget.previewConfig ?? ref.watch(paperExportControllerProvider).config;
    final notifier = ref.read(paperExportControllerProvider.notifier);

    return paperAsync.when(
      loading: () => Scaffold(
        backgroundColor: c.bgCanvas,
        appBar: RosidTopBar(title: l10n.export, showBack: true),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Scaffold(
        backgroundColor: c.bgCanvas,
        appBar: RosidTopBar(title: l10n.export, showBack: true),
        body: Center(child: Text(l10n.loadFailed)),
      ),
      data: (paper) {
        if (paper == null) {
          return Scaffold(
            backgroundColor: c.bgCanvas,
            appBar: RosidTopBar(title: l10n.export, showBack: true),
            body: Center(child: Text(l10n.noPapersYet)),
          );
        }

        final isReceipt = paper.paperKind == PaperKind.receipt;
        final fileName =
            widget.previewFileName ??
            PaperExportService.buildFileName(paper, config);
        final pageSizeLabel = switch (config.pageSize) {
          ExportPageSize.a4 => l10n.pageSizeA4,
          ExportPageSize.letter => l10n.pageSizeLetter,
          ExportPageSize.asScanned => l10n.pageSizeAsScanned,
        };
        final limitLabel = config.maxSizeBytes == null
            ? l10n.noSizeLimit
            : l10n.sizeLimitMb((config.maxSizeBytes! / (1024 * 1024)).round());

        return Scaffold(
          backgroundColor: c.bgCanvas,
          appBar: RosidTopBar(title: l10n.export, showBack: true),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    Text(
                      l10n.whatGoesIn,
                      style: RosidTextTokens.uiHeading.copyWith(
                        color: c.inkPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        RosidChip(
                          key: const ValueKey('export-inc-scan'),
                          label: l10n.scanTab,
                          selected: config.includeScan,
                          icon: config.includeScan ? RosidIcons.check : null,
                          onTap: () => notifier.updateConfig(
                            config.copyWith(includeScan: !config.includeScan),
                          ),
                        ),
                        RosidChip(
                          key: const ValueKey('export-inc-english'),
                          label: l10n.englishDraftLabel,
                          selected: config.includeEnglish,
                          icon: config.includeEnglish ? RosidIcons.check : null,
                          onTap: () => notifier.updateConfig(
                            config.copyWith(
                              includeEnglish: !config.includeEnglish,
                            ),
                          ),
                        ),
                        RosidChip(
                          key: const ValueKey('export-inc-bangla'),
                          label: l10n.banglaTextLabel,
                          selected: config.includeBangla,
                          icon: config.includeBangla ? RosidIcons.check : null,
                          onTap: () => notifier.updateConfig(
                            config.copyWith(
                              includeBangla: !config.includeBangla,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text(
                      l10n.fileType,
                      style: RosidTextTokens.uiHeading.copyWith(
                        color: c.inkPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final entry in [
                      (
                        ExportFileType.pdf,
                        l10n.fileTypePdf,
                        l10n.fileTypePdfDesc,
                      ),
                      (
                        ExportFileType.docx,
                        l10n.fileTypeDocx,
                        l10n.fileTypeDocxDesc,
                      ),
                      (
                        ExportFileType.txt,
                        l10n.fileTypeTxt,
                        l10n.fileTypeTxtDesc,
                      ),
                      (
                        ExportFileType.jpg,
                        l10n.fileTypeJpg,
                        l10n.fileTypeJpgDesc,
                      ),
                      if (isReceipt)
                        (
                          ExportFileType.csv,
                          l10n.fileTypeCsv,
                          l10n.fileTypeCsvDesc,
                        ),
                    ]) ...[
                      InkWell(
                        key: ValueKey('export-type-${entry.$1.code}'),
                        onTap: () => notifier.updateConfig(
                          config.copyWith(fileType: entry.$1),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: RosidRadio(
                                  selected: config.fileType == entry.$1,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.$2,
                                      style: RosidTextTokens.uiBodyStrong
                                          .copyWith(color: c.inkPrimary),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      entry.$3,
                                      style: RosidTextTokens.uiCaption.copyWith(
                                        color: c.inkSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Divider(color: c.lineSubtle, height: 1),
                    ],
                    if (config.fileType == ExportFileType.docx) ...[
                      const SizedBox(height: 8),
                      Text(
                        l10n.fileTypeDocxFontNote,
                        style: RosidTextTokens.uiCaption.copyWith(
                          color: c.inkSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    Text(
                      l10n.options,
                      style: RosidTextTokens.uiHeading.copyWith(
                        color: c.inkPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (config.fileType == ExportFileType.pdf) ...[
                      InkWell(
                        key: const ValueKey('export-opt-pagesize'),
                        onTap: () => _pickPageSize(config),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  l10n.pageSize,
                                  style: RosidTextTokens.uiBody.copyWith(
                                    color: c.inkPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                pageSizeLabel,
                                style: RosidTextTokens.uiLabel.copyWith(
                                  color: c.inkSecondary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              RosidIcon(
                                RosidIcons.chevronDown,
                                size: 18,
                                color: c.inkSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Divider(color: c.lineSubtle, height: 1),
                      InkWell(
                        key: const ValueKey('export-opt-sizelimit'),
                        onTap: () => _pickSizeLimit(config),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.keepFileUnder,
                                      style: RosidTextTokens.uiBody.copyWith(
                                        color: c.inkPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      l10n.keepFileUnderSub,
                                      style: RosidTextTokens.uiCaption.copyWith(
                                        color: c.inkSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                limitLabel,
                                style: RosidTextTokens.uiLabel.copyWith(
                                  color: c.inkSecondary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              RosidIcon(
                                RosidIcons.chevronDown,
                                size: 18,
                                color: c.inkSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Divider(color: c.lineSubtle, height: 1),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _editWatermarkText(config),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.watermark,
                                    style: RosidTextTokens.uiBody.copyWith(
                                      color: c.inkPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    config.fullWatermarkLine,
                                    style: RosidTextTokens.uiCaption.copyWith(
                                      color: c.inkSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          RosidToggle(
                            key: const ValueKey('export-opt-watermark'),
                            value: config.watermarkEnabled,
                            semanticLabel: l10n.watermark,
                            onChanged: (v) => notifier.updateConfig(
                              config.copyWith(watermarkEnabled: v),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(color: c.lineSubtle, height: 1),
                    if (config.fileType == ExportFileType.pdf ||
                        config.fileType == ExportFileType.docx) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.translatorSignPage,
                                    style: RosidTextTokens.uiBody.copyWith(
                                      color: c.inkPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    l10n.translatorSignPageSub,
                                    style: RosidTextTokens.uiCaption.copyWith(
                                      color: c.inkSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            RosidToggle(
                              key: const ValueKey('export-opt-translator-page'),
                              value: config.includeTranslatorPage,
                              semanticLabel: l10n.translatorSignPage,
                              onChanged: (v) => notifier.updateConfig(
                                config.copyWith(includeTranslatorPage: v),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(color: c.lineSubtle, height: 1),
                    ],
                    if (_exceededLimit) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: c.warnSoft,
                          borderRadius: BorderRadius.circular(
                            RosidSizeTokens.radiusControl,
                          ),
                        ),
                        child: Text(
                          l10n.sizeLimitCannotFit,
                          style: RosidTextTokens.uiCaption.copyWith(
                            color: c.warnBase,
                          ),
                        ),
                      ),
                    ],
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: RosidTextTokens.uiLabel.copyWith(
                                color: c.inkPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _estimateSummary(context, paper, config, locale),
                            style: RosidTextTokens.uiCaption.copyWith(
                              color: c.inkSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          RosidButton(
                            key: const ValueKey('export-preview-button'),
                            label: l10n.preview,
                            kind: RosidButtonKind.outline,
                            onPressed: () => context.push(
                              '/paper/${paper.scan.id}/export/preview',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: RosidButton(
                              key: const ValueKey('export-save-button'),
                              label: l10n.saveToPhone,
                              icon: RosidIcons.save,
                              expand: true,
                              busy: _saving,
                              onPressed: () => _saveToPhone(paper),
                            ),
                          ),
                        ],
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
}

class _WatermarkTextDialog extends StatefulWidget {
  const _WatermarkTextDialog({required this.initial});
  final String initial;

  @override
  State<_WatermarkTextDialog> createState() => _WatermarkTextDialogState();
}

class _WatermarkTextDialogState extends State<_WatermarkTextDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.watermark),
      content: TextField(
        controller: _ctrl,
        decoration: InputDecoration(labelText: l10n.watermarkPurposeHint),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_ctrl.text),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
