import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rosid/core/extensions/l10n_extension.dart';
import 'package:rosid/core/theme/app_theme.dart';
import 'package:rosid/core/theme/rosid_icons.dart';
import 'package:rosid/core/theme/tokens.g.dart';
import 'package:rosid/core/utils/bangla_digits.dart';
import 'package:rosid/core/utils/share_origin.dart';
import 'package:rosid/core/widgets/rosid_controls.dart';
import 'package:rosid/core/widgets/rosid_navigation.dart';
import 'package:rosid/core/widgets/rosid_paper_thumbnail.dart';
import 'package:rosid/data/files/private_file_store.dart';
import 'package:rosid/data/repositories/bundle_repository.dart';
import 'package:rosid/export/paper_export_service.dart';
import 'package:rosid/features/export/export_controller.dart';
import 'package:rosid/features/paper/paper_repository.dart';
import 'package:share_plus/share_plus.dart';

/// Export saved confirmation screen (`/paper/:id/export/saved`) matching
/// `design/screens/export-saved.png`.
class ExportSavedScreen extends ConsumerWidget {
  const ExportSavedScreen({
    required this.scanId,
    this.previewLocation,
    this.previewSummary,
    this.previewBundleName,
    super.key,
  });

  final String scanId;

  @visibleForTesting
  final String? previewLocation;

  @visibleForTesting
  final String? previewSummary;

  @visibleForTesting
  final String? previewBundleName;

  Future<void> _addToBundle(BuildContext context, WidgetRef ref) async {
    final bundles = await ref.read(allBundlesProvider.future);
    if (!context.mounted) return;
    if (bundles.isEmpty) {
      context.go('/bundles');
      return;
    }
    final picked = await showModalBottomSheet<BundleDetailView>(
      context: context,
      builder: (ctx) {
        final c = RosidColors.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ctx.l10n.addToABundle,
                  style: RosidTextTokens.uiTitle.copyWith(color: c.inkPrimary),
                ),
                const SizedBox(height: 12),
                for (final b in bundles) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: RosidIcon(
                      RosidIcons.bundle,
                      size: 22,
                      color: c.accentBase,
                    ),
                    title: Text(
                      b.bundle.title,
                      style: RosidTextTokens.uiBodyStrong.copyWith(
                        color: c.inkPrimary,
                      ),
                    ),
                    trailing: RosidIcon(
                      RosidIcons.chevronRight,
                      size: 18,
                      color: c.inkTertiary,
                    ),
                    onTap: () => Navigator.of(ctx).pop(b),
                  ),
                  Divider(color: c.lineSubtle, height: 1),
                ],
              ],
            ),
          ),
        );
      },
    );
    if (picked == null || !context.mounted) return;
    final repo = ref.read(bundleRepositoryProvider);
    final fallbackTitle = context.l10n.document;
    final firstMissing = picked.items
        .where((i) => i.item.linkedScanId == null)
        .firstOrNull;
    if (firstMissing != null) {
      await repo.linkScanToItem(
        bundleId: picked.bundle.id,
        itemId: firstMissing.item.id,
        scanId: scanId,
      );
    } else {
      final paper = await ref.read(paperRepositoryProvider).loadPaper(scanId);
      await repo.addItem(
        bundleId: picked.bundle.id,
        title: paper?.title ?? fallbackTitle,
        expectedKind: paper?.scan.kind ?? 'document',
        linkedScanId: scanId,
      );
    }
    ref.invalidate(allBundlesProvider);
    ref.invalidate(bundleDetailProvider(picked.bundle.id));
    if (!context.mounted) return;
    context.go('/bundles/${picked.bundle.id}');
  }

  Future<void> _cleanupAndExit(BuildContext context, WidgetRef ref) async {
    final res = ref.read(paperExportControllerProvider).lastResult;
    if (res != null) {
      final store = ref.read(privateFileStoreProvider);
      await store.deleteExportIfPresent(res.tempFilePath);
      for (final extra in res.extraFilePaths) {
        await store.deleteExportIfPresent(extra);
      }
    }
    if (!context.mounted) return;
    context.go('/paper/$scanId');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final session = ref.watch(paperExportControllerProvider);
    final res = session.lastResult;

    final locationText =
        previewLocation ??
        session.savedLocationLabel ??
        res?.fileName ??
        'Downloads, Rosid';

    final sizeSummary =
        previewSummary ??
        (res == null
            ? ''
            : '${localizeDigits(l10n.pagesCount(res.pageCount), locale)}, '
                  '${res.sizeBytes >= 1024 * 1024 ? "${(res.sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB" : "${(res.sizeBytes / 1024).ceil()} KB"}');

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: RosidTopBar(
        title: '',
        leading: IconButton(
          key: const ValueKey('saved-close'),
          icon: RosidIcon(RosidIcons.close, size: 22, color: c.inkPrimary),
          onPressed: () => _cleanupAndExit(context, ref),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
              children: [
                SizedBox(
                  height: 150,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 16),
                          child: RosidPaperThumbnail(
                            kind: RosidPaperKind.land,
                            width: 96,
                            height: 124,
                          ),
                        ),
                        Positioned(
                          left: 84,
                          bottom: 12,
                          child: RosidStamp(
                            key: const ValueKey('export-saved-stamp'),
                            label: l10n.savedStamp,
                            tone: RosidStampTone.good,
                            angleRadians: 0.14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.savedToYourPhone,
                  style: RosidTextTokens.uiTitleLg.copyWith(
                    color: c.inkPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  locationText,
                  style: RosidTextTokens.uiBody.copyWith(color: c.inkSecondary),
                ),
                if (sizeSummary.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    sizeSummary,
                    style: RosidTextTokens.uiCaption.copyWith(
                      color: c.inkSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                _SavedActionRow(
                  key: const ValueKey('saved-action-share'),
                  icon: RosidIcons.share,
                  title: l10n.share,
                  subtitle: l10n.shareSub,
                  onTap: () async {
                    if (res == null) return;
                    final origin = shareOriginFor(context);
                    final files = [
                      XFile(res.tempFilePath, mimeType: res.mimeType),
                      for (final p in res.extraFilePaths)
                        XFile(p, mimeType: res.mimeType),
                    ];
                    await SharePlus.instance.share(
                      ShareParams(
                        files: files,
                        subject: res.fileName,
                        sharePositionOrigin: origin,
                      ),
                    );
                  },
                ),
                Divider(color: c.lineSubtle, height: 1),
                _SavedActionRow(
                  key: const ValueKey('saved-action-print'),
                  icon: RosidIcons.print,
                  title: l10n.print,
                  onTap: () async {
                    if (res == null) return;
                    await ref
                        .read(platformFileServiceProvider)
                        .printPdf(
                          filePath: res.tempFilePath,
                          jobName: res.fileName,
                        );
                  },
                ),
                Divider(color: c.lineSubtle, height: 1),
                _SavedActionRow(
                  key: const ValueKey('saved-action-bundle'),
                  icon: RosidIcons.bundle,
                  title: l10n.addToABundle,
                  subtitle: previewBundleName,
                  onTap: () => _addToBundle(context, ref),
                ),
                Divider(color: c.lineSubtle, height: 1),
                _SavedActionRow(
                  key: const ValueKey('saved-action-folder'),
                  icon: RosidIcons.file,
                  title: l10n.openTheFolder,
                  onTap: () => ref
                      .read(platformFileServiceProvider)
                      .openFolder(session.savedUri),
                ),
                Divider(color: c.lineSubtle, height: 1),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: SafeArea(
              top: false,
              child: RosidButton(
                key: const ValueKey('saved-done'),
                label: l10n.done,
                expand: true,
                onPressed: () => _cleanupAndExit(context, ref),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedActionRow extends StatelessWidget {
  const _SavedActionRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    super.key,
  });

  final RosidIcons icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            RosidIcon(icon, size: 22, color: c.inkPrimary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: RosidTextTokens.uiBody.copyWith(color: c.inkPrimary),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: RosidTextTokens.uiCaption.copyWith(
                        color: c.inkSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            RosidIcon(RosidIcons.chevronRight, size: 18, color: c.inkTertiary),
          ],
        ),
      ),
    );
  }
}
