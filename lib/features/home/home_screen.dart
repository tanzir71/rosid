import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rosid/core/extensions/l10n_extension.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/core/theme/app_theme.dart';
import 'package:rosid/core/theme/rosid_icons.dart';
import 'package:rosid/core/theme/tokens.g.dart';
import 'package:rosid/core/utils/bangla_digits.dart';
import 'package:rosid/core/utils/money.dart';
import 'package:rosid/core/widgets/rosid_controls.dart';
import 'package:rosid/core/widgets/rosid_navigation.dart';
import 'package:rosid/core/widgets/rosid_paper_thumbnail.dart';
import 'package:rosid/data/database/app_database.dart';
import 'package:rosid/data/database/database_provider.dart';
import 'package:rosid/data/repositories/history_repository.dart';

/// Home screen (`design/screens/home.png`, `home-bn.png`, `home-dark.png`).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final settings = ref.watch(appSettingsProvider);
    final recentPapers = ref.watch(_homePapersProvider);
    final activeBundles = ref.watch(_homeBundlesProvider);

    final shortcuts = _orderedShortcuts(settings.purposes, l10n);

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: RosidTopBar(
        title: l10n.appWordmarkBn,
        isWordmark: true,
        trailing: [
          RosidPill(
            label: l10n.offline,
            tone: RosidTone.good,
            icon: RosidIcons.shield,
          ),
          IconButton(
            key: const ValueKey('home-settings-button'),
            tooltip: l10n.settings,
            onPressed: () => context.push('/settings'),
            icon: RosidIcon(RosidIcons.settings, size: 22, color: c.inkPrimary),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 112),
        children: [
          Text(
            l10n.whatAreYouScanning,
            style: RosidTextTokens.uiTitle.copyWith(color: c.inkPrimary),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < shortcuts.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: _ScanShortcutTile(shortcut: shortcuts[i])),
              ],
            ],
          ),
          const SizedBox(height: 24),
          recentPapers.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                l10n.loadFailed,
                style: RosidTextTokens.uiBody.copyWith(color: c.inkSecondary),
              ),
            ),
            data: (entries) {
              final resumeEntry = _pickResumeEntry(entries);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (resumeEntry != null) ...[
                    Text(
                      l10n.pickUpWhereYouLeftOff,
                      style: RosidTextTokens.uiHeading.copyWith(
                        color: c.inkPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ResumeCard(entry: resumeEntry, locale: locale),
                    const SizedBox(height: 24),
                  ],
                  _SectionHeader(
                    title: l10n.bundles,
                    actionLabel: l10n.seeAll,
                    onAction: () => context.go('/bundles'),
                  ),
                  const SizedBox(height: 10),
                  activeBundles.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (bundles) {
                      if (bundles.isEmpty) {
                        return _EmptyBundlesCard(
                          onTap: () => context.go('/bundles'),
                        );
                      }
                      final first = bundles.first;
                      return _BundleSummaryCard(
                        summary: first,
                        locale: locale,
                        onTap: () =>
                            context.push('/bundles/${first.bundle.id}'),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  _SectionHeader(
                    title: l10n.recent,
                    actionLabel: l10n.library,
                    onAction: () => context.go('/library'),
                  ),
                  const SizedBox(height: 6),
                  if (entries.isEmpty)
                    _EmptyPapersCard(
                      onScan: () => context.push('/scan?mode=document'),
                    )
                  else
                    for (final entry in entries.take(5)) ...[
                      RosidPaperRow(
                        title: entry.title,
                        subtitle: _paperSubtitle(context, entry, locale),
                        kind: _paperKindFor(entry),
                        trailingTop: entry.isReceipt && entry.receipt != null
                            ? localizeDigits(
                                formatMoney(
                                  entry.receipt!.total,
                                  entry.receipt!.currency,
                                ),
                                locale,
                              )
                            : localizeDigits(l10n.pagesCount(1), locale),
                        pillLabel: entry.scan.checkCount > 0
                            ? localizeDigits(
                                l10n.wordsToCheckCount(entry.scan.checkCount),
                                locale,
                              )
                            : null,
                        pillTone: RosidTone.warn,
                        onTap: () => context.push('/paper/${entry.scan.id}'),
                      ),
                      Divider(color: c.lineSubtle, height: 1),
                    ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  HistoryEntry? _pickResumeEntry(List<HistoryEntry> entries) {
    for (final entry in entries) {
      if (entry.scan.checkCount > 0) return entry;
    }
    return entries.isEmpty ? null : entries.first;
  }

  List<_ScanShortcut> _orderedShortcuts(
    Set<RosidPurpose> purposes,
    dynamic l10n,
  ) {
    final doc = _ScanShortcut(
      label: l10n.document as String,
      route: '/scan?mode=document',
      paperKind: RosidPaperKind.letter,
    );
    final idCard = _ScanShortcut(
      label: l10n.idCard as String,
      route: '/scan?mode=id',
      paperKind: RosidPaperKind.id,
    );
    final receipt = _ScanShortcut(
      label: l10n.receipt as String,
      route: '/scan?mode=receipt',
      paperKind: RosidPaperKind.receipt,
    );
    final translate = _ScanShortcut(
      label: l10n.translate as String,
      route: '/scan?mode=translate',
      isTranslate: true,
    );
    if (purposes.contains(RosidPurpose.receipts) &&
        !purposes.contains(RosidPurpose.visa) &&
        !purposes.contains(RosidPurpose.land)) {
      return [receipt, doc, idCard, translate];
    }
    return [doc, idCard, receipt, translate];
  }

  RosidPaperKind _paperKindFor(HistoryEntry entry) {
    if (entry.isReceipt) return RosidPaperKind.receipt;
    return switch (entry.scan.kind) {
      'land' => RosidPaperKind.land,
      'certificate' => RosidPaperKind.certificate,
      'id' => RosidPaperKind.id,
      'notes' => RosidPaperKind.notes,
      _ => RosidPaperKind.letter,
    };
  }

  String _paperSubtitle(
    BuildContext context,
    HistoryEntry entry,
    Locale locale,
  ) {
    final l10n = context.l10n;
    final kindLabel = entry.isReceipt
        ? l10n.receipt
        : switch (entry.scan.kind) {
            'land' => l10n.landRecord,
            'certificate' => l10n.certificate,
            'id' => l10n.idCard,
            _ => l10n.document,
          };
    final now = DateTime.now();
    final created = entry.date;
    final isToday =
        created.year == now.year &&
        created.month == now.month &&
        created.day == now.day;
    final dateText = isToday
        ? l10n.today
        : localizeDigits(
            DateFormat.MMMd(locale.toLanguageTag()).format(created),
            locale,
          );
    return '$kindLabel, $dateText';
  }
}

class _ScanShortcut {
  const _ScanShortcut({
    required this.label,
    required this.route,
    this.paperKind,
    this.isTranslate = false,
  });

  final String label;
  final String route;
  final RosidPaperKind? paperKind;
  final bool isTranslate;
}

class _ScanShortcutTile extends StatelessWidget {
  const _ScanShortcutTile({required this.shortcut});

  final _ScanShortcut shortcut;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    return InkWell(
      onTap: () => context.push(shortcut.route),
      borderRadius: BorderRadius.circular(RosidSizeTokens.radiusControl),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 76,
              child: Center(
                child: shortcut.isTranslate
                    ? const _TranslateTileVisual()
                    : RosidPaperThumbnail(
                        kind: shortcut.paperKind!,
                        width: 56,
                        height: 72,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              shortcut.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: RosidTextTokens.uiLabel.copyWith(color: c.inkPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _TranslateTileVisual extends StatelessWidget {
  const _TranslateTileVisual();

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.paperSheet,
            borderRadius: BorderRadius.circular(RosidSizeTokens.radiusPaper),
            border: Border.all(color: c.paperLine),
            boxShadow: RosidShadowTokens.elevPaper,
          ),
          child: Text(
            context.l10n.scriptGlyphBn,
            style: RosidTextTokens.docTitle.copyWith(color: c.paperInk),
          ),
        ),
        const SizedBox(width: 4),
        Container(
          width: 34,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.paperSheet,
            borderRadius: BorderRadius.circular(RosidSizeTokens.radiusPaper),
            border: Border.all(color: c.accentBase, width: 1.5),
            boxShadow: RosidShadowTokens.elevPaper,
          ),
          child: Text(
            context.l10n.scriptGlyphEn,
            style: RosidTextTokens.docTitle.copyWith(color: c.accentBase),
          ),
        ),
      ],
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.entry, required this.locale});

  final HistoryEntry entry;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    final kind = entry.isReceipt
        ? RosidPaperKind.receipt
        : entry.scan.kind == 'land'
        ? RosidPaperKind.land
        : RosidPaperKind.letter;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.bgSheet,
        borderRadius: BorderRadius.circular(RosidSizeTokens.radiusControl),
        border: Border.all(color: c.lineSubtle),
      ),
      child: Column(
        children: [
          Row(
            children: [
              RosidPaperThumbnail(kind: kind, width: 44, height: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RosidTextTokens.uiHeading.copyWith(
                        color: c.inkPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${entry.isReceipt ? l10n.receipt : l10n.document}, ${l10n.scannedToday}',
                      style: RosidTextTokens.uiCaption.copyWith(
                        color: c.inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (entry.scan.checkCount > 0)
                RosidPill(
                  label: localizeDigits(
                    l10n.wordsToCheckCount(entry.scan.checkCount),
                    locale,
                  ),
                  tone: RosidTone.warn,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: RosidButton(
                  label: l10n.checkWords,
                  kind: RosidButtonKind.tonal,
                  onPressed: () =>
                      context.push('/paper/${entry.scan.id}/check'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RosidButton(
                  label: l10n.translate,
                  kind: RosidButtonKind.outline,
                  icon: RosidIcons.translate,
                  onPressed: () =>
                      context.push('/paper/${entry.scan.id}?tab=english'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: RosidTextTokens.uiHeading.copyWith(color: c.inkPrimary),
          ),
        ),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(48, 40),
          ),
          child: Text(
            actionLabel,
            style: RosidTextTokens.uiLabel.copyWith(color: c.accentBase),
          ),
        ),
      ],
    );
  }
}

class _EmptyBundlesCard extends StatelessWidget {
  const _EmptyBundlesCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RosidSizeTokens.radiusControl),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.bgSheet,
          borderRadius: BorderRadius.circular(RosidSizeTokens.radiusControl),
          border: Border.all(color: c.lineSubtle),
        ),
        child: Row(
          children: [
            RosidIcon(RosidIcons.bundle, size: 22, color: c.accentBase),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.startFromChecklist,
                    style: RosidTextTokens.uiBodyStrong.copyWith(
                      color: c.inkPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.startBundlePrompt,
                    style: RosidTextTokens.uiCaption.copyWith(
                      color: c.inkSecondary,
                    ),
                  ),
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

class _BundleSummaryCard extends StatelessWidget {
  const _BundleSummaryCard({
    required this.summary,
    required this.locale,
    required this.onTap,
  });

  final _BundleSummary summary;
  final Locale locale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    final total = summary.totalCount;
    final ready = summary.readyCount;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RosidSizeTokens.radiusControl),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.bgSheet,
          borderRadius: BorderRadius.circular(RosidSizeTokens.radiusControl),
          border: Border.all(color: c.lineSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              summary.bundle.title,
              style: RosidTextTokens.uiHeading.copyWith(color: c.inkPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              localizeDigits(l10n.bundleProgress(ready, total), locale),
              style: RosidTextTokens.uiCaption.copyWith(color: c.inkSecondary),
            ),
            if (total > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  for (var i = 0; i < total.clamp(0, 12); i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: i < ready ? c.goodBase : c.bgSunken,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            if (summary.nextMissingTitle != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  RosidIcon(RosidIcons.alert, size: 16, color: c.warnBase),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      summary.nextMissingTitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RosidTextTokens.uiCaption.copyWith(
                        color: c.inkPrimary,
                      ),
                    ),
                  ),
                  RosidIcon(
                    RosidIcons.chevronRight,
                    size: 16,
                    color: c.inkTertiary,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyPapersCard extends StatelessWidget {
  const _EmptyPapersCard({required this.onScan});

  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.bgSheet,
        borderRadius: BorderRadius.circular(RosidSizeTokens.radiusControl),
        border: Border.all(color: c.lineSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.noPapersYet,
            style: RosidTextTokens.uiHeading.copyWith(color: c.inkPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.scanFirstPaperPrompt,
            style: RosidTextTokens.uiCaption.copyWith(color: c.inkSecondary),
          ),
          const SizedBox(height: 14),
          RosidButton(
            label: l10n.scan,
            kind: RosidButtonKind.tonal,
            icon: RosidIcons.scan,
            onPressed: onScan,
          ),
        ],
      ),
    );
  }
}

class _BundleSummary {
  const _BundleSummary({
    required this.bundle,
    required this.readyCount,
    required this.totalCount,
    this.nextMissingTitle,
  });

  final Bundle bundle;
  final int readyCount;
  final int totalCount;
  final String? nextMissingTitle;
}

final _homePapersProvider = FutureProvider<List<HistoryEntry>>((ref) async {
  final expenseEnabled = ref.watch(expenseTrackingEnabledProvider);
  final repo = ref.watch(historyRepositoryProvider);
  return repo.list(
    HistoryQuery(
      type: expenseEnabled ? HistoryTypeFilter.all : HistoryTypeFilter.document,
    ),
  );
});

final _homeBundlesProvider = FutureProvider<List<_BundleSummary>>((ref) async {
  final db = ref.watch(databaseProvider);
  final rows = await db.select(db.bundles).get();
  final result = <_BundleSummary>[];
  for (final bundle in rows) {
    final items = await (db.select(
      db.bundleItems,
    )..where((row) => row.bundleId.equals(bundle.id))).get();
    final ready = items.where((i) => i.linkedScanId != null).length;
    String? nextMissing;
    for (final item in items) {
      if (item.linkedScanId == null) {
        nextMissing = item.title;
        break;
      }
    }
    result.add(
      _BundleSummary(
        bundle: bundle,
        readyCount: ready,
        totalCount: items.length,
        nextMissingTitle: nextMissing,
      ),
    );
  }
  return result;
});
