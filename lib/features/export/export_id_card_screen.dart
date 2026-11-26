import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rosid/core/extensions/l10n_extension.dart';
import 'package:rosid/core/theme/app_theme.dart';
import 'package:rosid/core/theme/rosid_icons.dart';
import 'package:rosid/core/theme/tokens.g.dart';
import 'package:rosid/core/widgets/rosid_controls.dart';
import 'package:rosid/core/widgets/rosid_inputs.dart';
import 'package:rosid/core/widgets/rosid_navigation.dart';
import 'package:rosid/export/export_models.dart';
import 'package:rosid/export/paper_export_service.dart';
import 'package:rosid/features/export/export_controller.dart';
import 'package:rosid/features/paper/paper_repository.dart';

/// ID card on one A4 page screen (`/paper/:id/export/id`) matching
/// `design/screens/export-id-one-page.png`.
class ExportIdCardScreen extends ConsumerStatefulWidget {
  const ExportIdCardScreen({
    required this.scanId,
    this.previewDateText,
    this.previewWatermarkOn,
    super.key,
  });

  final String scanId;

  @visibleForTesting
  final String? previewDateText;

  @visibleForTesting
  final bool? previewWatermarkOn;

  @override
  ConsumerState<ExportIdCardScreen> createState() => _ExportIdCardScreenState();
}

class _ExportIdCardScreenState extends ConsumerState<ExportIdCardScreen> {
  bool _busy = false;
  late bool _watermarkOn;
  bool _blackAndWhite = false;

  @override
  void initState() {
    super.initState();
    _watermarkOn = widget.previewWatermarkOn ?? true;
  }

  Future<void> _exportId(PaperViewData paper, {required bool printOnly}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final base = ref.read(paperExportControllerProvider).config;
      final dateStr =
          widget.previewDateText ??
          DateFormat('d MMM yyyy').format(DateTime.now());
      final config = base.copyWith(
        includeScan: true,
        includeEnglish: false,
        includeBangla: false,
        includeTranslatorPage: false,
        fileType: ExportFileType.pdf,
        pageSize: ExportPageSize.a4,
        watermarkEnabled: _watermarkOn,
        watermarkText: base.watermarkText.isEmpty
            ? 'For visa application only'
            : base.watermarkText,
        watermarkDateText: dateStr,
        blackAndWhite: _blackAndWhite,
      );
      final res = await ref
          .read(paperExportServiceProvider)
          .createExport(paper: paper, englishLines: const [], config: config);

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
    final exportState = ref.watch(paperExportControllerProvider);
    final dateStr =
        widget.previewDateText ??
        DateFormat('d MMM yyyy').format(DateTime.now());
    final watermarkLabel = exportState.config.watermarkText.isEmpty
        ? l10n.watermarkDefaultPurpose
        : exportState.config.watermarkText;

    return paperAsync.when(
      loading: () => Scaffold(
        backgroundColor: c.bgCanvas,
        appBar: RosidTopBar(title: l10n.idBothSidesTitle, showBack: true),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Scaffold(
        backgroundColor: c.bgCanvas,
        appBar: RosidTopBar(title: l10n.idBothSidesTitle, showBack: true),
        body: Center(child: Text(l10n.loadFailed)),
      ),
      data: (paper) {
        if (paper == null) {
          return Scaffold(
            backgroundColor: c.bgCanvas,
            appBar: RosidTopBar(title: l10n.idBothSidesTitle, showBack: true),
            body: Center(child: Text(l10n.noPapersYet)),
          );
        }

        final pagePath = paper.pages.isNotEmpty
            ? (paper.pages.first.processedPath ?? paper.pages.first.imagePath)
            : paper.scan.imagePath;
        final hasRealImage = File(pagePath).existsSync();

        return Scaffold(
          backgroundColor: c.bgCanvas,
          appBar: RosidTopBar(
            title: l10n.idBothSidesTitle,
            showBack: true,
            trailing: [
              IconButton(
                icon: RosidIcon(RosidIcons.more, size: 22, color: c.inkPrimary),
                onPressed: () => context.push('/paper/${paper.scan.id}/export'),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
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
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (hasRealImage)
                                ColorFiltered(
                                  colorFilter: _blackAndWhite
                                      ? const ColorFilter.matrix([
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
                                        ])
                                      : const ColorFilter.mode(
                                          Colors.transparent,
                                          BlendMode.dst,
                                        ),
                                  child: Image.file(
                                    File(pagePath),
                                    fit: BoxFit.contain,
                                  ),
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    26,
                                    32,
                                    26,
                                    16,
                                  ),
                                  child: Column(
                                    children: [
                                      const _IdCardWireframe(),
                                      const SizedBox(height: 18),
                                      const _IdCardWireframe(),
                                      const Spacer(),
                                      Text(
                                        l10n.copyMadeOn(dateStr),
                                        style: RosidTextTokens.uiMicro.copyWith(
                                          color: const Color(0xFF6A6D7C),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (_watermarkOn)
                                IgnorePointer(
                                  child: Center(
                                    child: Transform.rotate(
                                      angle: -0.55,
                                      child: Text(
                                        watermarkLabel,
                                        textAlign: TextAlign.center,
                                        style: RosidTextTokens.uiHeading
                                            .copyWith(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: RosidColorTokens
                                                  .accentBaseLight
                                                  .withValues(alpha: 0.22),
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
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
                                  watermarkLabel,
                                  style: RosidTextTokens.uiCaption.copyWith(
                                    color: c.inkSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          RosidToggle(
                            key: const ValueKey('id-export-watermark'),
                            value: _watermarkOn,
                            semanticLabel: l10n.watermark,
                            onChanged: (v) => setState(() => _watermarkOn = v),
                          ),
                        ],
                      ),
                    ),
                    Divider(color: c.lineSubtle, height: 1),
                    InkWell(
                      key: const ValueKey('id-export-cover'),
                      onTap: () =>
                          context.push('/paper/${paper.scan.id}/export/cover'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.coverDetailTitle,
                                    style: RosidTextTokens.uiBody.copyWith(
                                      color: c.inkPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    l10n.coverDetailSub,
                                    style: RosidTextTokens.uiCaption.copyWith(
                                      color: c.inkSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            RosidIcon(
                              RosidIcons.chevronRight,
                              size: 18,
                              color: c.inkTertiary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Divider(color: c.lineSubtle, height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.blackAndWhiteCopy,
                              style: RosidTextTokens.uiBody.copyWith(
                                color: c.inkPrimary,
                              ),
                            ),
                          ),
                          RosidToggle(
                            key: const ValueKey('id-export-bw'),
                            value: _blackAndWhite,
                            semanticLabel: l10n.blackAndWhiteCopy,
                            onChanged: (v) =>
                                setState(() => _blackAndWhite = v),
                          ),
                        ],
                      ),
                    ),
                    Divider(color: c.lineSubtle, height: 1),
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
                        key: const ValueKey('id-export-print'),
                        label: l10n.print,
                        icon: RosidIcons.print,
                        kind: RosidButtonKind.outline,
                        onPressed: _busy
                            ? null
                            : () => _exportId(paper, printOnly: true),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RosidButton(
                          key: const ValueKey('id-export-submit'),
                          label: l10n.export,
                          icon: RosidIcons.share,
                          expand: true,
                          busy: _busy,
                          onPressed: () => _exportId(paper, printOnly: false),
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
}

class _IdCardWireframe extends StatelessWidget {
  const _IdCardWireframe();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD0D4C8), width: 2.5),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFD2D5CA),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFF282A38),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 6,
                      width: 66,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD2D5CA),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 6,
                      width: 82,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD2D5CA),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD2D5CA),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
