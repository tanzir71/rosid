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
import 'package:rosid/core/widgets/rosid_inputs.dart';
import 'package:rosid/core/widgets/rosid_navigation.dart';
import 'package:rosid/core/widgets/rosid_paper_thumbnail.dart';
import 'package:rosid/data/repositories/dashboard_repository.dart';
import 'package:rosid/data/repositories/history_repository.dart';

/// Library screen shell (`/library`) showing real persisted papers from v1/v2.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({this.initialQuery = '', super.key});

  final String initialQuery;

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  late final TextEditingController _searchController;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final expenseEnabled = ref.watch(expenseTrackingEnabledProvider);
    final query = _searchController.text.trim();

    final listAsync = ref.watch(
      _libraryEntriesProvider((
        query: query,
        filter: _selectedFilter,
        includeReceipts: expenseEnabled,
      )),
    );

    final chips = <(String, String)>[
      ('all', l10n.all),
      ('document', l10n.documents),
      ('id', l10n.ids),
      if (expenseEnabled) ('receipt', l10n.receipts),
      ('land', l10n.land),
    ];

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: RosidTopBar(title: l10n.library),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 112),
        children: [
          RosidField(
            controller: _searchController,
            hint: l10n.search,
            leadingIcon: RosidIcons.search,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < chips.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  RosidChip(
                    label: chips[i].$2,
                    selected: _selectedFilter == chips[i].$1,
                    onTap: () => setState(() => _selectedFilter = chips[i].$1),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          listAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => Center(child: Text(l10n.loadFailed)),
            data: (entries) {
              if (entries.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: c.bgSheet,
                    borderRadius: BorderRadius.circular(
                      RosidSizeTokens.radiusControl,
                    ),
                    border: Border.all(color: c.lineSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        query.isEmpty ? l10n.noPapersYet : l10n.noResults,
                        style: RosidTextTokens.uiHeading.copyWith(
                          color: c.inkPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.scanFirstPaperPrompt,
                        style: RosidTextTokens.uiCaption.copyWith(
                          color: c.inkSecondary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      RosidButton(
                        label: l10n.scan,
                        kind: RosidButtonKind.tonal,
                        icon: RosidIcons.scan,
                        onPressed: () => context.push('/scan?mode=document'),
                      ),
                    ],
                  ),
                );
              }
              return Column(
                children: [
                  for (final entry in entries) ...[
                    RosidPaperRow(
                      title: entry.title,
                      subtitle: localizeDigits(
                        DateFormat.yMMMd(locale.toLanguageTag())
                            .format(entry.date),
                        locale,
                      ),
                      kind: entry.isReceipt
                          ? RosidPaperKind.receipt
                          : entry.scan.kind == 'land'
                          ? RosidPaperKind.land
                          : RosidPaperKind.letter,
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
}

final _libraryEntriesProvider = FutureProvider.autoDispose
    .family<
      List<HistoryEntry>,
      ({String query, String filter, bool includeReceipts})
    >((ref, args) {
      final repo = ref.watch(historyRepositoryProvider);
      final type = switch (args.filter) {
        'receipt' => HistoryTypeFilter.receipt,
        'document' || 'id' || 'land' => HistoryTypeFilter.document,
        _ =>
          args.includeReceipts
              ? HistoryTypeFilter.all
              : HistoryTypeFilter.document,
      };
      return repo.list(HistoryQuery(text: args.query, type: type));
    });

/// Bundles screen shell (`/bundles`), expanded in M7.
class BundlesScreen extends StatelessWidget {
  const BundlesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: RosidTopBar(title: l10n.bundles),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 112),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: c.bgSheet,
              borderRadius: BorderRadius.circular(
                RosidSizeTokens.radiusControl,
              ),
              border: Border.all(color: c.lineSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RosidIcon(RosidIcons.bundle, size: 28, color: c.accentBase),
                const SizedBox(height: 12),
                Text(
                  l10n.noBundlesYet,
                  style: RosidTextTokens.uiHeading.copyWith(
                    color: c.inkPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.startBundlePrompt,
                  style: RosidTextTokens.uiBody.copyWith(color: c.inkSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Expenses screen shell (`/expenses`), expanded in M8.
class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final summary = ref.watch(dashboardSummaryProvider);

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: RosidTopBar(
        title: l10n.expenses,
        trailing: [
          TextButton(
            onPressed: () => context.push('/export'),
            child: Text(l10n.exportCsv),
          ),
        ],
      ),
      body: summary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(l10n.loadFailed)),
        data: (value) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 112),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: c.bgSheet,
                borderRadius: BorderRadius.circular(
                  RosidSizeTokens.radiusControl,
                ),
                border: Border.all(color: c.lineSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.spentThisMonth,
                    style: RosidTextTokens.uiCaption.copyWith(
                      color: c.inkSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    localizeDigits(
                      formatMoney(value.total, value.currency),
                      locale,
                    ),
                    style: RosidTextTokens.uiDisplay.copyWith(
                      color: c.inkPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (value.recent.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: c.bgSheet,
                  borderRadius: BorderRadius.circular(
                    RosidSizeTokens.radiusControl,
                  ),
                  border: Border.all(color: c.lineSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.noReceipts,
                      style: RosidTextTokens.uiHeading.copyWith(
                        color: c.inkPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.noReceiptsThisMonth,
                      style: RosidTextTokens.uiCaption.copyWith(
                        color: c.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    RosidButton(
                      label: l10n.receipt,
                      kind: RosidButtonKind.tonal,
                      icon: RosidIcons.receipt,
                      onPressed: () => context.push('/scan?mode=receipt'),
                    ),
                  ],
                ),
              )
            else
              for (final entry in value.recent) ...[
                RosidPaperRow(
                  title: entry.title,
                  subtitle: localizeDigits(
                    DateFormat.yMMMd(locale.toLanguageTag())
                        .format(entry.receipt!.dateOfPurchase),
                    locale,
                  ),
                  kind: RosidPaperKind.receipt,
                  trailingTop: localizeDigits(
                    formatMoney(entry.receipt!.total, entry.receipt!.currency),
                    locale,
                  ),
                  onTap: () => context.push('/paper/${entry.scan.id}'),
                ),
                Divider(color: c.lineSubtle, height: 1),
              ],
          ],
        ),
      ),
    );
  }
}

/// Paper reader shell (`/paper/:id?tab=`), expanded in M4 and M5.
class PaperShellScreen extends ConsumerStatefulWidget {
  const PaperShellScreen({
    required this.scanId,
    this.initialTab = RosidReaderTab.text,
    super.key,
  });

  final String scanId;
  final RosidReaderTab initialTab;

  @override
  ConsumerState<PaperShellScreen> createState() => _PaperShellScreenState();
}

class _PaperShellScreenState extends ConsumerState<PaperShellScreen> {
  late RosidReaderTab _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    final l10n = context.l10n;
    final detailAsync = ref.watch(_paperDetailProvider(widget.scanId));

    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: RosidTopBar(
        title: detailAsync.asData?.value?.entry.title ?? l10n.document,
        showBack: true,
        trailing: [
          IconButton(
            onPressed: () => context.push('/detail/${widget.scanId}/edit'),
            icon: RosidIcon(RosidIcons.edit, size: 22, color: c.inkPrimary),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          children: [
            RosidReaderTabs(
              active: _tab,
              scanLabel: l10n.scanTab,
              textLabel: l10n.body,
              englishLabel: l10n.englishTab,
              onChanged: (tab) => setState(() => _tab = tab),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: detailAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Center(child: Text(l10n.loadFailed)),
                data: (detail) {
                  if (detail == null) {
                    return Center(child: Text(l10n.noResults));
                  }
                  final bodyText =
                      detail.entry.document?.body ??
                      detail.entry.scan.ocrRawText;
                  return SingleChildScrollView(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: c.paperSheet,
                        borderRadius: BorderRadius.circular(
                          RosidSizeTokens.radiusPaper,
                        ),
                        border: Border.all(color: c.paperLine),
                        boxShadow: RosidShadowTokens.elevPaper,
                      ),
                      child: Text(
                        _tab == RosidReaderTab.english
                            ? l10n.englishDraftPending
                            : (bodyText.isEmpty ? l10n.noResults : bodyText),
                        style: RosidTextTokens.docBody.copyWith(
                          color: c.paperInk,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final _paperDetailProvider = FutureProvider.autoDispose
    .family<ScanDetail?, String>(
      (ref, id) => ref.watch(historyRepositoryProvider).detail(id),
    );

/// Simple v2 route shell for screens implemented in later milestones (M2–M8).
class V2RouteShellScreen extends StatelessWidget {
  const V2RouteShellScreen({
    required this.title,
    required this.body,
    required this.icon,
    this.primaryLabel,
    this.onPrimary,
    super.key,
  });

  final String title;
  final String body;
  final RosidIcons icon;
  final String? primaryLabel;
  final VoidCallback? onPrimary;

  @override
  Widget build(BuildContext context) {
    final c = RosidColors.of(context);
    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: RosidTopBar(title: title, showBack: true),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: c.bgSheet,
            borderRadius: BorderRadius.circular(RosidSizeTokens.radiusControl),
            border: Border.all(color: c.lineSubtle),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RosidIcon(icon, size: 28, color: c.accentBase),
              const SizedBox(height: 12),
              Text(
                title,
                style: RosidTextTokens.uiHeading.copyWith(color: c.inkPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                style: RosidTextTokens.uiBody.copyWith(color: c.inkSecondary),
              ),
              if (primaryLabel != null && onPrimary != null) ...[
                const SizedBox(height: 16),
                RosidButton(
                  label: primaryLabel!,
                  kind: RosidButtonKind.tonal,
                  onPressed: onPrimary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
