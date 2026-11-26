import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rosid/core/extensions/l10n_extension.dart';
import 'package:rosid/core/theme/app_theme.dart';
import 'package:rosid/core/theme/rosid_icons.dart';
import 'package:rosid/core/theme/tokens.g.dart';
import 'package:rosid/core/utils/bangla_digits.dart';
import 'package:rosid/core/widgets/rosid_controls.dart';
import 'package:rosid/core/widgets/rosid_inputs.dart';
import 'package:rosid/core/widgets/rosid_navigation.dart';
import 'package:rosid/data/repositories/bundle_repository.dart';
import 'package:rosid/export/bundle_export_service.dart';
import 'package:rosid/export/paper_export_service.dart';
import 'package:rosid/features/export/export_controller.dart';

/// Bundle export screen (`/bundles/:id/export`) matching
/// `design/screens/bundle-export.png`.
class BundleExportScreen extends ConsumerStatefulWidget {
  const BundleExportScreen({
    required this.bundleId,
    this.previewDetail,
    this.previewFileName,
    this.previewSummary,
    this.previewReadyCountLabel,
    this.previewItemMeta,
    this.previewDraftWarningTitle,
    super.key,
  });

  final String bundleId;

  @visibleForTesting
  final BundleDetailView? previewDetail;

  @visibleForTesting
  final String? previewFileName;

  @visibleForTesting
  final String? previewSummary;

  @visibleForTesting
  final String? previewReadyCountLabel;

  @visibleForTesting
  final Map<String, String>? previewItemMeta;

  @visibleForTesting
  final String? previewDraftWarningTitle;

  @override
  ConsumerState<BundleExportScreen> createState() => _BundleExportScreenState();
}

class _BundleExportScreenState extends ConsumerState<BundleExportScreen> {
  BundlePackMode _mode = BundlePackMode.onePdf;
  int? _maxSizeBytes = 2 * 1024 * 1024;
  bool _watermark = false;
  bool _saving = false;
  bool _exceeded = false;

  Future<void> _pickLimit() async {
    final l10n = context.l10n;
    final chosen = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(l10n.noSizeLimit),
              onTap: () => Navigator.of(ctx).pop(-1),
            ),
            for (final mb in [2, 5, 10])
              ListTile(
                title: Text(l10n.sizeLimitMb(mb)),
                onTap: () => Navigator.of(ctx).pop(mb * 1024 * 1024),
              ),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    setState(() {
      _maxSizeBytes = chosen == -1 ? null : chosen;
    });
  }

  Future<void> _saveBundle(BundleDetailView detail) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _exceeded = false;
    });
    try {
      final res = await ref
          .read(bundleExportServiceProvider)
          .exportBundle(
            detail: detail,
            mode: _mode,
            maxSizeBytes: _maxSizeBytes,
            watermarkEnabled: _watermark,
            watermarkText: context.l10n.watermarkDefaultPurpose,
          );
      if (res.exceededSizeLimit) {
        if (mounted) {
          setState(() {
            _exceeded = true;
            _saving = false;
          });
        }
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.savedToYourPhone)));
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.exportFailed)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);

    Widget buildBody(BundleDetailView detail) {
      final attached = detail.attachedItems;
      String? draftTitle = widget.previewDraftWarningTitle;
      if (draftTitle == null) {
        for (final it in attached) {
          if (it.hasEnglishDraft) {
            draftTitle = it.item.title.toLowerCase();
            break;
          }
        }
      }

      final fileName =
          widget.previewFileName ??
          BundleExportService.fileNameForBundle(detail.bundle.title, _mode);
      final totalPages =
          1 +
          attached.fold<int>(
            0,
            (s, it) => s + it.pageCount + (it.hasEnglishDraft ? 1 : 0),
          );
      final summaryText =
          widget.previewSummary ??
          '${localizeDigits(l10n.pagesCount(totalPages), locale)}, ${(attached.length * 0.45).toStringAsFixed(1)} MB';
      final limitLabel = _maxSizeBytes == null
          ? l10n.noSizeLimit
          : l10n.sizeLimitMb((_maxSizeBytes! / (1024 * 1024)).round());

      return Scaffold(
        backgroundColor: c.bgCanvas,
        appBar: RosidTopBar(title: l10n.exportBundle, showBack: true),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Text(
                    l10n.howToPackIt,
                    style: RosidTextTokens.uiHeading.copyWith(
                      color: c.inkPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final opt in [
                    (
                      BundlePackMode.onePdf,
                      l10n.onePdfWithContents,
                      l10n.onePdfWithContentsSub,
                    ),
                    (
                      BundlePackMode.separateFiles,
                      l10n.separateFiles,
                      l10n.separateFilesSub,
                    ),
                  ]) ...[
                    InkWell(
                      key: ValueKey('bundle-pack-${opt.$1.name}'),
                      onTap: () => setState(() => _mode = opt.$1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: RosidRadio(selected: _mode == opt.$1),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    opt.$2,
                                    style: RosidTextTokens.uiBodyStrong
                                        .copyWith(color: c.inkPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    opt.$3,
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
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.orderHeading,
                          style: RosidTextTokens.uiHeading.copyWith(
                            color: c.inkPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        widget.previewReadyCountLabel ??
                            localizeDigits(
                              l10n.readyPapersCount(attached.length),
                              locale,
                            ),
                        style: RosidTextTokens.uiLabel.copyWith(
                          color: c.accentBase,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  for (var i = 0; i < attached.length; i++) ...[
                    if (i > 0) Divider(color: c.lineSubtle, height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 28,
                            child: Text(
                              (i + 1).toString().padLeft(2, '0'),
                              style: RosidTextTokens.uiLabel.copyWith(
                                color: c.inkSecondary,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  attached[i].item.title,
                                  style: RosidTextTokens.uiBody.copyWith(
                                    color: c.inkPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.previewItemMeta?[attached[i]
                                          .item
                                          .id] ??
                                      localizeDigits(
                                        l10n.pagesCount(attached[i].pageCount),
                                        locale,
                                      ),
                                  style: RosidTextTokens.uiCaption.copyWith(
                                    color: c.inkSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          RosidIcon(
                            RosidIcons.drag,
                            size: 18,
                            color: c.inkTertiary,
                          ),
                        ],
                      ),
                    ),
                  ],
                  Divider(color: c.lineSubtle, height: 1),
                  if (draftTitle != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      key: const ValueKey('bundle-draft-warning'),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: c.warnSoft,
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
                              RosidIcons.alert,
                              size: 18,
                              color: c.warnBase,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.bundleDraftWarning(draftTitle),
                              style: RosidTextTokens.uiCaption.copyWith(
                                color: c.inkPrimary,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  InkWell(
                    key: const ValueKey('bundle-export-limit'),
                    onTap: _pickLimit,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.keepEachFileUnder,
                              style: RosidTextTokens.uiBody.copyWith(
                                color: c.inkPrimary,
                              ),
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
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.watermarkEveryPage,
                            style: RosidTextTokens.uiBody.copyWith(
                              color: c.inkPrimary,
                            ),
                          ),
                        ),
                        RosidToggle(
                          key: const ValueKey('bundle-export-watermark'),
                          value: _watermark,
                          semanticLabel: l10n.watermarkEveryPage,
                          onChanged: (v) => setState(() => _watermark = v),
                        ),
                      ],
                    ),
                  ),
                  if (_exceeded) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.sizeLimitCannotFit,
                      style: RosidTextTokens.uiCaption.copyWith(
                        color: c.warnBase,
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
                          summaryText,
                          style: RosidTextTokens.uiCaption.copyWith(
                            color: c.inkSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    RosidButton(
                      key: const ValueKey('bundle-export-save'),
                      label: l10n.saveToPhone,
                      icon: RosidIcons.save,
                      expand: true,
                      busy: _saving,
                      onPressed: attached.isEmpty
                          ? null
                          : () => _saveBundle(detail),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (widget.previewDetail != null) return buildBody(widget.previewDetail!);

    final detailAsync = ref.watch(bundleDetailProvider(widget.bundleId));
    return detailAsync.when(
      loading: () => Scaffold(
        backgroundColor: c.bgCanvas,
        appBar: RosidTopBar(title: l10n.exportBundle, showBack: true),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Scaffold(
        backgroundColor: c.bgCanvas,
        appBar: RosidTopBar(title: l10n.exportBundle, showBack: true),
        body: Center(child: Text(l10n.loadFailed)),
      ),
      data: (detail) {
        if (detail == null) {
          return Scaffold(
            backgroundColor: c.bgCanvas,
            appBar: RosidTopBar(title: l10n.exportBundle, showBack: true),
            body: Center(child: Text(l10n.noBundlesYet)),
          );
        }
        return buildBody(detail);
      },
    );
  }
}
