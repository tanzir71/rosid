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
import 'package:rosid/data/repositories/bundle_repository.dart';
import 'package:rosid/features/bundles/bundles_screen.dart';
import 'package:rosid/features/library/library_screen.dart';

/// Bundle checklist screen (`/bundles/:id`) matching
/// `design/screens/bundle-checklist.png` and `bundle-checklist-bn.png`.
class BundleChecklistScreen extends ConsumerWidget {
  const BundleChecklistScreen({
    required this.bundleId,
    this.previewDetail,
    this.previewItemSubtitles,
    super.key,
  });

  final String bundleId;

  @visibleForTesting
  final BundleDetailView? previewDetail;

  @visibleForTesting
  final Map<String, String>? previewItemSubtitles;

  Future<void> _pickDueDate(
    BuildContext context,
    WidgetRef ref,
    BundleDetailView detail,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: detail.bundle.dueDate ?? now.add(const Duration(days: 30)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) {
      await ref
          .read(bundleRepositoryProvider)
          .updateDueDate(detail.bundle.id, picked);
      ref
        ..invalidate(bundleDetailProvider(bundleId))
        ..invalidate(allBundlesProvider);
    }
  }

  Future<void> _addChecklistItem(
    BuildContext context,
    WidgetRef ref,
    BundleDetailView detail,
  ) async {
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => const _AddItemDialog(),
    );
    if (title != null && title.trim().isNotEmpty) {
      await ref
          .read(bundleRepositoryProvider)
          .addItem(bundleId: detail.bundle.id, title: title.trim());
      ref
        ..invalidate(bundleDetailProvider(bundleId))
        ..invalidate(allBundlesProvider);
    }
  }

  Future<void> _linkPaperSheet(
    BuildContext context,
    WidgetRef ref,
    BundleDetailView detail,
    BundleItemView itemView,
  ) async {
    final papers = await ref.read(
      libraryPapersProvider((filter: 'all', includeReceipts: true)).future,
    );
    if (!context.mounted) return;

    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final c = RosidColors.of(ctx);
        final l10n = ctx.l10n;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  itemView.item.title,
                  style: RosidTextTokens.uiTitle.copyWith(color: c.inkPrimary),
                ),
                const SizedBox(height: 10),
                ListTile(
                  key: const ValueKey('bundle-item-scan-new'),
                  contentPadding: EdgeInsets.zero,
                  leading: RosidIcon(
                    RosidIcons.camera,
                    size: 20,
                    color: c.accentBase,
                  ),
                  title: Text(l10n.scanNewPaper),
                  onTap: () => Navigator.of(ctx).pop('__SCAN__'),
                ),
                Divider(color: c.lineSubtle, height: 1),
                if (papers.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 4),
                    child: Text(
                      l10n.linkExistingPaper,
                      style: RosidTextTokens.uiCaption.copyWith(
                        color: c.inkSecondary,
                      ),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: papers.length,
                      itemBuilder: (_, i) {
                        final p = papers[i];
                        return ListTile(
                          key: ValueKey('link-paper-${p.scanId}'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(p.title),
                          trailing: itemView.item.linkedScanId == p.scanId
                              ? RosidIcon(
                                  RosidIcons.check,
                                  size: 18,
                                  color: c.goodBase,
                                )
                              : null,
                          onTap: () => Navigator.of(ctx).pop(p.scanId),
                        );
                      },
                    ),
                  ),
                ],
                if (itemView.item.linkedScanId != null) ...[
                  Divider(color: c.lineSubtle, height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: RosidIcon(
                      RosidIcons.trash,
                      size: 18,
                      color: c.badBase,
                    ),
                    title: Text(
                      l10n.delete,
                      style: TextStyle(color: c.badBase),
                    ),
                    onTap: () => Navigator.of(ctx).pop('__REMOVE__'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );

    if (chosen == null || !context.mounted) return;
    if (chosen == '__SCAN__') {
      context.push('/scan?mode=document');
      return;
    }
    if (chosen == '__REMOVE__') {
      await ref
          .read(bundleRepositoryProvider)
          .removeItem(detail.bundle.id, itemView.item.id);
    } else {
      await ref
          .read(bundleRepositoryProvider)
          .linkScanToItem(
            bundleId: detail.bundle.id,
            itemId: itemView.item.id,
            scanId: chosen,
          );
    }
    ref
      ..invalidate(bundleDetailProvider(bundleId))
      ..invalidate(allBundlesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);

    Widget buildBody(BundleDetailView detail) {
      final dueDate = detail.bundle.dueDate;
      return Scaffold(
        backgroundColor: c.bgCanvas,
        appBar: RosidTopBar(
          title: detail.bundle.title,
          showBack: true,
          trailing: [
            PopupMenuButton<String>(
              icon: RosidIcon(RosidIcons.more, size: 22, color: c.inkPrimary),
              onSelected: (val) async {
                if (val == 'due') {
                  await _pickDueDate(context, ref, detail);
                } else if (val == 'delete') {
                  await ref
                      .read(bundleRepositoryProvider)
                      .deleteBundle(detail.bundle.id);
                  ref.invalidate(allBundlesProvider);
                  if (context.mounted) context.go('/bundles');
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'due', child: Text(l10n.setDueDate)),
                PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RosidSegmentedProgress(
                    readyCount: detail.readyCount,
                    needsWorkCount: detail.needsWorkCount,
                    missingCount: detail.missingCount,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          localizeDigits(
                            l10n.bundleChecklistSummary(
                              detail.readyCount,
                              detail.needsWorkCount,
                              detail.missingCount,
                            ),
                            locale,
                          ),
                          style: RosidTextTokens.uiCaption.copyWith(
                            color: c.inkSecondary,
                          ),
                        ),
                      ),
                      if (dueDate != null)
                        InkWell(
                          onTap: () => _pickDueDate(context, ref, detail),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              RosidIcon(
                                RosidIcons.calendar,
                                size: 15,
                                color: c.inkSecondary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                localizeDigits(
                                  l10n.byDueDate(
                                    DateFormat(
                                      'd MMM yyyy',
                                      locale.toLanguageTag(),
                                    ).format(dueDate),
                                  ),
                                  locale,
                                ),
                                style: RosidTextTokens.uiCaption.copyWith(
                                  color: c.inkSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
                children: [
                  for (var i = 0; i < detail.items.length; i++) ...[
                    if (i > 0) Divider(color: c.lineSubtle, height: 1),
                    _ChecklistItemRow(
                      itemView: detail.items[i],
                      locale: locale,
                      overrideSubtitle:
                          previewItemSubtitles?[detail.items[i].item.id],
                      onTapRow: () => _linkPaperSheet(
                        context,
                        ref,
                        detail,
                        detail.items[i],
                      ),
                      onAction: () {
                        final it = detail.items[i];
                        if (it.status == BundleItemStatus.missing) {
                          _linkPaperSheet(context, ref, detail, it);
                        } else if (it.wordsToCheck > 0 &&
                            it.linkedScan != null) {
                          context.push('/paper/${it.linkedScan!.id}/check');
                        } else if (it.linkedScan != null) {
                          context.push('/paper/${it.linkedScan!.id}');
                        }
                      },
                    ),
                  ],
                  Divider(color: c.lineSubtle, height: 1),
                  const SizedBox(height: 14),
                  Text(
                    l10n.checklistDisclaimer,
                    style: RosidTextTokens.uiCaption.copyWith(
                      color: c.inkSecondary,
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
                      key: const ValueKey('bundle-add-item'),
                      label: l10n.addAction,
                      icon: RosidIcons.plus,
                      kind: RosidButtonKind.outline,
                      onPressed: () => _addChecklistItem(context, ref, detail),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RosidButton(
                        key: const ValueKey('bundle-export-button'),
                        label: l10n.exportBundle,
                        icon: RosidIcons.share,
                        expand: true,
                        onPressed: detail.attachedItems.isEmpty
                            ? null
                            : () => context.push(
                                '/bundles/${detail.bundle.id}/export',
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (previewDetail != null) return buildBody(previewDetail!);

    final detailAsync = ref.watch(bundleDetailProvider(bundleId));
    return detailAsync.when(
      loading: () => Scaffold(
        backgroundColor: c.bgCanvas,
        appBar: RosidTopBar(title: l10n.bundles, showBack: true),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Scaffold(
        backgroundColor: c.bgCanvas,
        appBar: RosidTopBar(title: l10n.bundles, showBack: true),
        body: Center(child: Text(l10n.loadFailed)),
      ),
      data: (detail) {
        if (detail == null) {
          return Scaffold(
            backgroundColor: c.bgCanvas,
            appBar: RosidTopBar(title: l10n.bundles, showBack: true),
            body: Center(child: Text(l10n.noBundlesYet)),
          );
        }
        return buildBody(detail);
      },
    );
  }
}

class _ChecklistItemRow extends StatelessWidget {
  const _ChecklistItemRow({
    required this.itemView,
    required this.locale,
    required this.onTapRow,
    required this.onAction,
    this.overrideSubtitle,
  });

  final BundleItemView itemView;
  final Locale locale;
  final VoidCallback onTapRow;
  final VoidCallback onAction;
  final String? overrideSubtitle;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;

    final String subtitle;
    if (overrideSubtitle != null) {
      subtitle = overrideSubtitle!;
    } else if (itemView.status == BundleItemStatus.missing) {
      subtitle = l10n.notScannedYet;
    } else if (itemView.wordsToCheck > 0) {
      subtitle = localizeDigits(
        l10n.wordsToCheckBeforeTranslating(itemView.wordsToCheck),
        locale,
      );
    } else if (itemView.hasEnglishDraft) {
      subtitle = l10n.draftNeedsCertifying;
    } else {
      subtitle = localizeDigits(
        l10n.scannedPagesCount(itemView.pageCount),
        locale,
      );
    }

    final String? actionLabel = switch (itemView.status) {
      BundleItemStatus.ready => null,
      BundleItemStatus.needsWork =>
        itemView.wordsToCheck > 0 ? l10n.checkAction : l10n.openAction,
      BundleItemStatus.missing => l10n.scan,
    };

    final Widget leadingIcon = switch (itemView.status) {
      BundleItemStatus.ready => Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(color: c.goodSoft, shape: BoxShape.circle),
        child: Center(
          child: RosidIcon(RosidIcons.check, size: 18, color: c.goodBase),
        ),
      ),
      BundleItemStatus.needsWork => Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(color: c.warnSoft, shape: BoxShape.circle),
        child: Center(
          child: RosidIcon(RosidIcons.alert, size: 18, color: c.warnBase),
        ),
      ),
      BundleItemStatus.missing => Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(color: c.lineStrong, width: 1.4),
        ),
        child: Center(
          child: RosidIcon(RosidIcons.plus, size: 16, color: c.inkSecondary),
        ),
      ),
    };

    return InkWell(
      key: ValueKey('bundle-item-${itemView.item.id}'),
      onTap: onTapRow,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            leadingIcon,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    itemView.item.title,
                    style: RosidTextTokens.uiBodyStrong.copyWith(
                      color: c.inkPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: RosidTextTokens.uiCaption.copyWith(
                      color: c.inkSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (actionLabel != null)
              TextButton(
                key: ValueKey('bundle-item-action-${itemView.item.id}'),
                onPressed: onAction,
                child: Text(
                  actionLabel,
                  style: RosidTextTokens.uiLabel.copyWith(
                    color: c.accentBase,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddItemDialog extends StatefulWidget {
  const _AddItemDialog();

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.addChecklistItem),
      content: TextField(
        key: const ValueKey('add-bundle-item-field'),
        controller: _ctrl,
        autofocus: true,
        decoration: InputDecoration(labelText: l10n.itemNameHint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const ValueKey('add-bundle-item-save'),
          onPressed: () => Navigator.of(context).pop(_ctrl.text.trim()),
          child: Text(l10n.addAction),
        ),
      ],
    );
  }
}
